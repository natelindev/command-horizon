extends "res://tests/headless/PointOfInterestRegression.gd"

var _surrender_module


func _run():
	_surrender_module = load("res://source/match/players/skirmish-ai/SkirmishSurrender.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open_sites(faction)
		await _test_surrender_conditions()
		await _clear()
		paused = false
		_game.queue_free()
		await _frames(5)
		print("SURRENDER faction=", faction, " cumulative_failures=", _errors.size())
	for message in _errors:
		push_error(message)
	print("Skirmish surrender AI: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _test_surrender_conditions():
	var units = _enemy._units()

	# 1. Opening match time guard (< 150s)
	_game.simulation_time = 60.0
	_check(
		not _surrender_module.evaluates_as_hopeless(_game, _enemy, units),
		"Early game evaluated as hopeless before min match time"
	)

	# 2. Beyond min match time, but healthy initial state
	_game.simulation_time = 180.0
	_check(
		not _surrender_module.evaluates_as_hopeless(_game, _enemy, units),
		"Healthy base evaluated as hopeless"
	)

	# 3. Simulate home base destruction and secret corner base:
	# Destroy all structures near start position
	var home_origin = _game.map.find_child("SpawnPoints").get_child(_enemy.start_index()).position
	for unit in _enemy._units():
		if (
			unit.has_method("is_constructed")
			and unit.global_position.distance_to(home_origin) <= 35.0
		):
			unit.queue_free()
	await _frames(2)

	# Remove enemy army, leaving only 1 isolated worker at a remote location
	for unit in _enemy._units():
		if unit.type != "Worker":
			unit.queue_free()
	await _frames(2)

	# Move lone worker to remote corner (e.g. 10, 0, 10)
	var surviving_workers = _enemy._units().filter(func(u): return u.type == "Worker")
	if not surviving_workers.is_empty():
		surviving_workers[0].position = Vector3(10, 0, 10)
		for idx in range(1, surviving_workers.size()):
			surviving_workers[idx].queue_free()
	await _frames(2)

	# Give human player a strong army (10 infantry)
	while _human._units().filter(func(u): return u.attack_range != null).size() < 10:
		_spawn("Infantry", _human, Vector3(50, 0, 50))
	await _frames(2)

	_check(
		_surrender_module.evaluates_as_hopeless(_game, _enemy, _enemy._units()),
		"Stranded lone worker in corner failed to evaluate as hopeless"
	)

	# 4. Verify surrender execution and timer
	_enemy._hopeless_seconds = 0.0
	var surrendered = _enemy._check_surrender(_enemy._units(), 5.0)
	_check(not surrendered, "Surrendered before persistence delay expired")
	_check(_enemy._hopeless_seconds == 5.0, "Hopeless timer did not accumulate")

	# Advance beyond persistence threshold
	surrendered = _enemy._check_surrender(_enemy._units(), 15.0)
	_check(surrendered, "Did not surrender after persistence threshold passed")
	_check(_enemy.get_meta("surrendered", false), "Player meta was not tagged as surrendered")
