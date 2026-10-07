extends "res://tests/headless/SaveRestoreEdges.gd"

var air_move


func _run():
	air_move = load("res://source/match/units/actions/Moving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for map_name in ["DesertFrontier", "AlpineRelay", "IndustrialCrossroads"]:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		for player in get_nodes_in_group("players"):
			if player != game._get_human_player():
				player.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		for role in ["Drone", "Helicopter"]:
			await _arrival(role, map_name)
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Air arrival: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _arrival(role, map_name):
	var actor = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(
		actor, Transform3D(Basis(), Vector3(90, 2, 65)), game._get_human_player(), false
	)
	await _frames(10)
	var goal = Vector3(110, 0, 70)
	actor.issue_manual_order(air_move.new(goal))
	await _frames(900)
	_check(
		(
			actor.global_position_yless.distance_to(goal) < 0.5
			and not actor.get_node("Movement")._has_destination
			and not _moving(actor)
		),
		"%s %s direct ground-click flight did not finish" % [map_name, role]
	)
	goal = Vector3(90, 0, 65)
	actor.issue_manual_order(air_move.new(goal))
	await _frames(120)
	paused = true
	var before = actor.position
	var clock_before = game.simulation_time
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Air arrival snapshot failed: " + capture.error)
	if data == null:
		paused = false
		return
	var identifier = capture._reference(actor)
	var store = FileStore.new()
	var filename = "user://air-arrival-%d.json" % OS.get_process_id()
	_check(store.write_file(filename, data), "Air arrival archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(filename))
	DirAccess.remove_absolute(filename)
	_check(loaded.ok, "Air arrival restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		paused = false
		return
	game = loaded.game
	actor = restore.entities[identifier]
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT if unit == actor else Node.PROCESS_MODE_DISABLED
		)
	await _frames(10)
	_check(
		paused and actor.position == before and game.simulation_time == clock_before,
		"Paused aircraft moved during restore"
	)
	paused = false
	await _frames(900)
	_check(actor.global_position_yless.distance_to(goal) < 0.5, "Aircraft missed arrival goal")
	_check(not _moving(actor), "%s %s retained arrived Moving action" % [map_name, role])
	_check(
		not actor.get_node("Movement")._has_destination,
		"%s %s retained arrived movement destination" % [map_name, role]
	)
	# A subsequent queued ground-click order must run after the first arrival.
	actor.manual_orders.submit({"kind": "move", "point": Vector3(98, 0, 60)})
	actor.manual_orders.submit({"kind": "move", "point": Vector3(105, 0, 55)}, true)
	await _frames(1200)
	_check(
		actor.global_position_yless.distance_to(Vector3(105, 0, 55)) < 0.5 and not _moving(actor),
		"%s %s queued flight did not finish" % [map_name, role]
	)
	actor.queue_free()
	await _frames(5)
	print("AIR ARRIVAL ", map_name, " ", role)


func _moving(actor):
	return actor.action != null and actor.action.get_script() == air_move
