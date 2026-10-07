extends "res://tests/headless/SplitSignalRegression.gd"


func _run():
	path = "user://split-followthrough-%d.json" % OS.get_process_id()
	await _make_match()
	game.waves_sent = 6
	game.waves_warned = 6
	var human = game._get_human_player()
	var relay = game.map.relays[0]
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = Vector3(5, 0, 5)
	var actor = _units(human, "Infantry")[0]
	actor.position = Vector3(27, 0, 23)
	var screen = _units(human, "Tank")[0]
	screen.position = relay.position + Vector3(0, 0, -2)
	var target = _units(game._enemy, "Infantry")[0]
	target.position = relay.position + Vector3(2, 0, 0)
	relay.captured_by = game._enemy
	game.battlefield.invalidate()
	await _frames(3)
	_check(
		relay.contested and game.battlefield.is_observed(human, target),
		"Follow-through contact missing"
	)
	var helper = load("res://tests/playtest/reference/SplitClearance.gd").new()
	helper.step(game)
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(60)
	_check(
		actor.position.distance_to(relay.position) > 8,
		"Fixture did not isolate target loss en route"
	)
	target.queue_free()
	await _frames(3)
	game.battlefield.invalidate()
	var start = game.simulation_time
	while relay.captured_by != human and game.simulation_time - start < 40:
		await _frames(30)
	_check(
		relay.captured_by == human, "Infantry stranded when its attack target disappeared en route"
	)
	print(
		"FOLLOWTHROUGH capture=",
		relay.captured_by == human,
		" elapsed=",
		game.simulation_time - start
	)
	await _cleanup()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Split follow-through: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
