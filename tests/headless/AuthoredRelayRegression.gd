extends "res://tests/headless/SaveRestoreEdges.gd"

# Capture relays on authored battlefields: placement on the col, infantry
# capture, local vision, recapture, save validation and restore, and the AI's
# capture team. A battlefield without relays carries no relay state and saves
# and restores cleanly.
const RELAY_MAP = "res://source/match/maps/battlefields/AlpineRelayMap.tscn"
const PLAIN_MAP = "res://source/match/maps/battlefields/GlacierNarrowsMap.tscn"


func _run():
	await _skirmish("bastion", RELAY_MAP)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.set_process(false)
	await _frames(30)
	_check(await _relay_and_restore(human, enemy) == true, "Relay suite did not finish")
	paused = false
	game.queue_free()
	await _frames(5)
	await _plain_map()
	print("Authored relay regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _spawn(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, true)
	return unit


func _relay_and_restore(human, enemy):
	var relays = game.map.relays
	_check(relays.size() == 2, "Alpine Relay should carry two relays")
	if relays.size() != 2:
		return true
	_check(
		relays[0].name == "NorthRelay" and relays[1].name == "SouthRelay",
		"Relays lost their per-start names"
	)
	# Relays snap to the navigation surface, which rides just above the ground.
	for relay in relays:
		var ground = Vector2(relay.global_position.x, relay.global_position.z)
		_check(
			absf(relay.global_position.y - game.map.height_at(ground)) < 0.75,
			"Relay %s does not stand on the col" % relay.name
		)
		_check(game.map.tier_at(ground) == 1, "Relay %s is not on the 3 m col" % relay.name)
	var relay = relays[0]
	var infantry = _spawn("Infantry", human, relay.global_position + Vector3(-2, 0, 0))
	await _frames(5)
	infantry.issue_manual_order(null)
	await _frames(610)
	_check(relay.captured_by == human, "Infantry failed to capture the authored relay")
	var hidden = _spawn("Tank", enemy, relay.global_position + Vector3(-7, 0, 0))
	await _frames(5)
	infantry.global_position = game.map.ground_point(Vector2(20, 30)) + Vector3(0, 0.6, 0)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, hidden), "Owned relay does not provide local vision")
	var attacker = _spawn("Infantry", enemy, relay.global_position + Vector3(2, 0, 0))
	await _frames(250)
	_check(
		relay.candidate == enemy and relay.progress > 2 and relay.progress < 10,
		"Recapture did not begin"
	)
	attacker.process_mode = Node.PROCESS_MODE_DISABLED
	hidden.process_mode = Node.PROCESS_MODE_DISABLED
	var builder = Snapshot.new()
	paused = true
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Authored relay capture failed: " + builder.error)
	if snapshot == null:
		return true
	var owned = snapshot.mission.relays[0]
	var broken = snapshot.duplicate(true)
	broken.mission.relays[0].owner = "unit-1"
	_check(not Restore.new().prepare(broken), "Invalid relay ownership accepted")
	var missing = snapshot.duplicate(true)
	missing.mission.relays.pop_back()
	_check(not Restore.new().prepare(missing), "A relay record count mismatch was accepted")
	var restore = Restore.new()
	var file = FileStore.new()
	var archive = "user://authored-relay-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Authored relay archive write failed")
	var loaded = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Authored relay restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return true
	game = loaded.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.set_process(false)
	relay = game.map.relays[0]
	_check(
		(
			relay.captured_by == human
			and relay.candidate == enemy
			and relay.progress == owned.progress
		),
		"Restore lost relay owner or recapture duration"
	)
	_check(game.map.relays[1].captured_by == null, "Restore duplicated relay ownership")
	game.hud._toggle_pause()
	await _frames(450)
	_check(relay.captured_by == enemy, "Loaded recapture could not finish")
	enemy._command_army(enemy._units())
	var captures = enemy._army_groups.filter(func(group): return group.kind == "capture")
	_check(captures.size() == 1, "AI did not assign a team to the neutral relay")
	if captures.size() == 1:
		_check(
			(
				captures[0].point.distance_to(game.map.relays[1].global_position * Vector3(1, 0, 1))
				< 1
			),
			"Capture team chose an owned relay"
		)
	return true


func _plain_map():
	await _skirmish("helix", PLAIN_MAP)
	_check(game.map.relays.is_empty(), "A map without relays created some")
	# Capture presence is measured on the ground plane: infantry near the edge
	# of the radius count beside a facility standing on the 3 m moraine.
	var camp = game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")
	_check(camp.size() == 1, "Glacier Narrows lost its moraine camp")
	if camp.size() == 1:
		var site = camp[0]
		var ground = Vector2(site.global_position.x, site.global_position.z)
		_check(game.map.tier_at(ground) == 1, "Moraine camp is not on the moraine")
		var human = game._get_human_player()
		var scout = _spawn("Infantry", human, game.map.ground_point(ground + Vector2(0, 4.5)))
		await _frames(5)
		scout.global_position = game.map.ground_point(ground + Vector2(0, 4.5))
		game.battlefield.invalidate()
		_check(
			human in site._capture_presence().infantry,
			"Infantry beside an elevated facility do not count toward capture"
		)
		scout.queue_free()
		await _frames(2)
	_check(game.map.capture_state(func(_node): return "").is_empty(), "Relay-free map has state")
	var builder = Snapshot.new()
	paused = true
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Relay-free capture failed: " + builder.error)
	if snapshot != null:
		_check(not snapshot.mission.has("relays"), "Relay-free map saved relay state")
		_check(Restore.new().prepare(snapshot), "Relay-free map snapshot was rejected")
	paused = false
	game.queue_free()
	await _frames(5)


func _check(value, message):
	if not value:
		errors.append(message)
		push_error(message)
