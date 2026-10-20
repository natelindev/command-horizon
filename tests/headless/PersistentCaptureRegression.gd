extends "res://tests/headless/NeutralWorldRegression.gd"

const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")


func _run():
	Manual = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://persistent-capture-%d.json" % OS.get_process_id()
	await _create("ExpandedDesertFrontier")
	game.settings.visibility = game.settings.Visibility.FULL
	var building = _building()
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var soldier = await _enter_building(building, human)
	var rival = _spawn_infantry(enemy, Vector3(170, 0, 120))
	rival.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not building.can_garrison(rival), "Enemy can capture a defended building")
	await _leave_building(building, soldier)
	_check(building.player == human, "Last infantry leaving erased building ownership")
	await _frames(120)
	_check(building.player == human, "Vacant building lost ownership over time")
	await _archive_owned_building(building)
	building = _building()
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	_check(
		building.player == human and building.occupants.is_empty(), "Empty ownership lost on load"
	)
	soldier = await _enter_building(building, human)
	await _leave_building(building, soldier)
	var invader = await _enter_building(building, enemy)
	_check(building.player == enemy, "Enemy infantry did not recapture empty building")
	_check(not building.can_garrison(soldier), "Former owner entered enemy garrison")
	await _archive_owned_building(building)
	building = _building()
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	invader = building.occupants[0]
	invader.hp = 0
	building._physics_process(.1)
	_check(building.player == enemy, "Last occupant dying erased ownership")
	invader.queue_free()
	await _frames(5)
	_check(
		building.player == enemy and building.occupants.is_empty(), "Death cleanup erased ownership"
	)
	await _archive_owned_building(building)
	await _legacy_ownership()
	await _close()
	for message in errors:
		push_error(message)
	print("Persistent neutral ownership: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _enter_building(building, side):
	var soldier = _spawn_infantry(
		side, building.global_position + Vector3(building.radius + .7, 0, 0)
	)
	game.battlefield.invalidate()
	# Use the same contextual command as right-clicking an empty enemy building.
	var controller = game._get_human_player().get_node("UnitActionsController")
	_check(controller._navigate_unit_towards_unit(soldier, building), "Capture command rejected")
	await _frames(30)
	_check(
		soldier.has_meta("garrison_host") and building.player == side, "Infantry failed to enter"
	)
	return soldier


func _leave_building(building, soldier):
	soldier.manual_orders.submit(
		Manual.point_order("move", building.global_position + Vector3(20, 0, 0))
	)
	await _frames(30)
	_check(
		not soldier.has_meta("garrison_host") and building.occupants.is_empty(),
		"Infantry failed to leave"
	)
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	soldier.position = Vector3(4, 0, 4)
	game.battlefield.invalidate()


func _archive_owned_building(building):
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Ownership snapshot failed: " + snapshot.error)
	if data == null:
		paused = false
		return
	var record = data.neutral_buildings.filter(func(item): return item.id == building.neutral_id)[0]
	_check(record.get("owner", "") == snapshot._reference(building.player), "Save omitted owner")
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Ownership save rejected: " + schema.error)
	var bad = data.duplicate(true)
	bad.neutral_buildings[0]["owner"] = "missing-player"
	_check(not schema.validate(bad), "Invalid building owner accepted")
	if not record.occupants.is_empty():
		for owner in ["", data.players.filter(func(side): return side.id != record.owner)[0].id]:
			bad = data.duplicate(true)
			bad.neutral_buildings.filter(func(item): return item.id == record.id)[0].owner = owner
			_check(not schema.validate(bad), "Garrison owner disagrees with its occupants")
	var loader = Restore.new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Ownership restore failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		_check(
			snapshot.capture(game).neutral_buildings == data.neutral_buildings,
			"Ownership changed on restore"
		)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			if not unit.has_meta("garrison_host"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false


func _legacy_ownership():
	# Older saves had no independent owner: occupied buildings inherit their
	# infantry's side; empty buildings remain neutral because no owner was stored.
	for version in [12, 11]:
		var building = _building()
		if version == 11:
			await _enter_building(building, game._get_human_player())
		paused = true
		var data = Snapshot.new().capture(game)
		data.snapshot_version = version
		data.erase("rounds")
		for legacy_unit in data.units:
			legacy_unit.projectiles = []
			legacy_unit.erase("air")
		for stance_unit in data.units:
			stance_unit.erase("stance")
		for record in data.neutral_buildings:
			record.erase("owner")
		if version == 11:
			for unit in data.units:
				for job in unit.production.get("jobs", []):
					job.erase("departure_endpoint")
		var result = await Restore.new().restore(self, data)
		_check(result.ok, "Legacy garrison restore failed: " + result.get("error", ""))
		if result.ok:
			game = result.game
			building = _building()
			_check(
				building.player == (game._get_human_player() if version == 11 else null),
				"Legacy ownership migration failed"
			)
			for side in get_nodes_in_group("players"):
				side.set_process(false)
		paused = false


func _building():
	return game.get_node("NeutralWorld").buildings.filter(func(item): return item.habitable)[0]
