extends "res://tests/headless/SaveRestoreEdges.gd"

var guard
var raider
var observer
var anchor = Vector3(40, 0, 10)


func _run():
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
		enemy.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		guard = _actor("Tank", human, anchor)
		raider = _actor("Tank", enemy, anchor + Vector3(11, 0, 0))
		observer = _actor("Worker", human, anchor + Vector3(11, 0, 3))
		raider.process_mode = Node.PROCESS_MODE_DISABLED
		observer.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(20)
		game.battlefield.invalidate()
		_check(game.battlefield.is_observed(human, raider), "Area fixture target is hidden")
		_check(game.battlefield.has_line_of_fire(guard, raider), "Area fixture line is blocked")
		_check(guard.attack_range < 11, "Area fixture is already inside weapon range")
		guard.program.installed = true
		var config = load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
		config.radius = 12.0
		_check(guard.program.configure(config), "Guard configuration rejected")
		guard.program.anchor = anchor
		guard.program.safe_point = anchor - Vector3(3, 0, 0)
		_check(guard.program.run(), "Guard refused to run")
		await _review("assigned")
		await _frames(40)
		await _archive_approach()
		var hp = raider.hp
		await _frames(240)
		_check(guard.position.distance_to(anchor) > 2, "Guard ignored outer assigned area")
		_check(raider.hp < hp, "Guard never engaged visible outer-area raider")
		print(
			"GUARD ",
			faction,
			" travelled=",
			guard.position.distance_to(anchor),
			" damage=",
			hp - raider.hp
		)
		await _review("engaging")
		await _boundaries()
		await _opposite_edge()
		await _authority_and_recovery()
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Guard area: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _archive_approach():
	_check(guard.get_node("Movement")._has_destination, "Guard archive has no approach")
	game.hud._toggle_pause()
	var point = guard.position
	var clock = game.simulation_time
	var hp = raider.hp
	await _frames(30)
	_check(guard.position == point and raider.hp == hp, "Paused guard moved or fired")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Guard snapshot failed")
	if snapshot == null:
		return
	var ids = [builder._reference(guard), builder._reference(raider), builder._reference(observer)]
	var store = FileStore.new()
	var archive_path = "user://guard-area-%d.json" % OS.get_process_id()
	_check(store.write_file(archive_path, snapshot), "Guard archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(archive_path))
	DirAccess.remove_absolute(archive_path)
	_check(loaded.ok, "Guard archive restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	guard = restore.entities[ids[0]]
	raider = restore.entities[ids[1]]
	observer = restore.entities[ids[2]]
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != guard:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(paused and game.simulation_time == clock, "Guard restore lost paused clock")
	_check(guard.position == point, "Guard restore moved the defender")
	_check(
		guard.program.anchor == anchor and guard.program.config.radius == 12,
		"Guard restore lost area"
	)
	_check(guard.program.mode == "Running", "Guard restore lost running assignment")
	game.hud._toggle_pause()
	print("PASS: moving Guard disk archive and paused continuity")


func _reset_guard(point):
	guard.issue_manual_order(null)
	await _frames(20)
	guard.global_position = point
	raider.hp = raider.hp_max
	game.battlefield.invalidate()
	await _frames(20)
	_check(guard.program.run(), "Guard restart failed")


func _boundaries():
	# A visible raider leaving the assigned area stops pursuit and causes return.
	raider.position = anchor + Vector3(15, 0, 0)
	observer.position = raider.position + Vector3(0, 0, 3)
	game.battlefield.invalidate()
	await _frames(30)
	var hp = raider.hp
	await _frames(240)
	_check(raider.hp == hp, "Guard shot a target outside the assigned area")
	_check(guard.position.distance_to(anchor) < 1.2, "Guard failed to return after target left")
	# A scout/engineer can provide observation, but losing it must stop acquisition.
	raider.position = anchor + Vector3(11, 0, 0)
	observer.position = anchor + Vector3(-20, 0, 0)
	# The current tank can itself observe this point. Isolate shared-spotter
	# loss with a bounded temporary sensor range, then restore its real stats.
	var sight = guard.sight_range
	guard.sight_range = minf(sight, 8.0)
	await _reset_guard(anchor)
	_check(
		not game.battlefield.is_observed(guard.player, raider), "Hidden guard fixture is visible"
	)
	hp = raider.hp
	await _frames(90)
	_check(
		guard.position.distance_to(anchor) < 0.5 and raider.hp == hp, "Guard acquired hidden target"
	)
	guard.sight_range = sight
	observer.position = raider.position + Vector3(0, 0, 3)
	var blocker = _actor("Barracks", guard.player, anchor + Vector3(5.5, 0, 0))
	blocker.process_mode = Node.PROCESS_MODE_DISABLED
	await _reset_guard(anchor)
	_check(game.battlefield.is_observed(guard.player, raider), "Blocked fixture target is hidden")
	_check(
		not game.battlefield.has_line_of_fire(guard, raider), "Blocked fixture has clear fire line"
	)
	hp = raider.hp
	await _frames(90)
	_check(
		guard.position.distance_to(anchor) < 0.5 and raider.hp == hp,
		"Guard ignored firing obstruction"
	)
	blocker.queue_free()
	await _frames(120)
	# An observed unsupported domain cannot attract the ground-only guard.
	raider.position = anchor + Vector3(30, 0, 0)
	var aircraft = _actor("Helicopter", raider.player, anchor + Vector3(11, 0, 0))
	aircraft.process_mode = Node.PROCESS_MODE_DISABLED
	await _reset_guard(anchor)
	_check(game.battlefield.is_observed(guard.player, aircraft), "Air fixture target is hidden")
	await _frames(90)
	_check(guard.position.distance_to(anchor) < 0.5, "Ground Guard pursued aircraft")
	aircraft.queue_free()
	await _frames(5)
	print("PASS: sector exit/return, hidden target, obstruction and ground/air bounds")


func _opposite_edge():
	raider.position = anchor + Vector3(11, 0, 0)
	observer.position = raider.position + Vector3(0, 0, 3)
	await _reset_guard(anchor - Vector3(10, 0, 0))
	var hp = raider.hp
	await _frames(600)
	_check(raider.hp < hp, "Guard on opposite edge missed observed target inside sector")
	_check(guard.position.distance_to(anchor) <= 14, "Guard escaped assignment during pursuit")
	print("PASS: acquisition across full sector from opposite edge")


func _authority_and_recovery():
	await _reset_guard(anchor)
	guard.issue_manual_order(null)
	var hp = raider.hp
	await _frames(120)
	_check(guard.program.mode == "Manual", "Guard overrode manual hold")
	_check(
		guard.position.distance_to(anchor) < 0.5 and raider.hp == hp,
		"Manual hold became area pursuit"
	)
	guard.hp = guard.hp_max * .2
	_check(guard.program.run(), "Injured Guard refused resume")
	await _frames(180)
	_check(
		guard.position.distance_to(guard.program.safe_point) < 1.2, "Outer target prevented retreat"
	)
	guard.hp = guard.hp_max
	await _frames(360)
	_check(raider.hp < hp, "Recovered Guard did not return and re-engage")
	print("PASS: manual hold, low-health retreat, recovery and renewed area defense")


func _review(_label):
	pass
