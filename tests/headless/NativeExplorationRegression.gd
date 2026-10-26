extends "res://tests/headless/NativeVisibilityRegression.gd"


## Compare complete ordered exploration ledgers against the script scan and
## script visibility, including repeated visits and live alliance changes.
func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create_match()
	model = game.map.terrain
	var field = game.battlefield
	_native = field._native_visibility
	_check(_native != null and field.native_exploration, "Native exploration flags are required")
	if _native != null and field.native_exploration:
		await _compare_exploration()
	await _close()
	for message in _errors:
		push_error(message)
	print("Native exploration: %d failures across %d ledgers" % [_errors.size(), _comparisons])
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare_exploration():
	var field = game.battlefield
	var support = game.commander_support
	support.set_physics_process(false)
	var players = game.get_cached_group("players")
	var units := []
	for role in ["Tank", "Infantry", "Fighter", "Helicopter", "RepairDepot"]:
		units.append(_spawn_unit(role, players[units.size() % 2], Vector3(80, 0, 80)))
	var generic = Observer.new()
	generic.player = players[0]
	game.add_child(generic)
	generic.add_to_group("vision_sources")
	game.invalidate_vision_registry()
	units.append(generic)
	await _frames(10)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var random := RandomNumberGenerator.new()
	random.seed = 120026
	var sites = [
		Vector2(54, 20),
		Vector2(65, 110),
		Vector2(110, 65),
		Vector2(48, 44),
		Vector2(-2, -2),
		game.map.size - Vector2.ONE,
		Vector2(96, 80)
	]
	for iteration in 240:
		if iteration % 8 == 0:
			support.explored.clear()
		players[0].team = 0
		players[1].team = 0 if iteration % 3 == 0 else 1
		for index in units.size():
			var unit = units[index]
			var flat: Vector2 = sites[(iteration + index) % sites.size()]
			flat += Vector2(random.randf_range(-2, 2), random.randf_range(-2, 2))
			unit.global_position = game.map.ground_point(flat)
			unit.sight_range = [0.0, 2.0, 8.5, 18.0, 30.0][(iteration + index) % 5]
			unit.hp = 0.0 if (iteration + index) % 17 == 0 else 100.0
			if iteration % 11 == 0 and index != 4:
				unit.set_meta("garrison_host", units[4])
			else:
				unit.remove_meta("garrison_host")
		generic.constructed = iteration % 4 != 0
		generic.range_factor = 1.7 if iteration % 5 == 0 else .8
		generic.player = players[iteration % 2]
		units[4]._construction_progress = .5 if iteration % 3 == 0 else 1.0
		var flight = units[2].get_node("Movement")
		flight.phase = flight.Phase.PARKED if iteration % 2 == 0 else flight.Phase.AIRBORNE
		if iteration % 2 != 0:
			units[2].position.y += 8.0
		field.invalidate()
		field._refresh()
		# Preserve non-boolean values: explored membership, not truthiness, wins.
		if not support.explored.has(players[0]):
			support.explored[players[0]] = {0: false}
		var before: Dictionary = support.explored.duplicate(true)
		field.native_exploration = false
		field._native_visibility = null
		support._record_exploration()
		var expected: Dictionary = support.explored.duplicate(true)
		support.explored = before
		field._native_visibility = _native
		field.native_exploration = true
		support._record_exploration()
		for player in players:
			_check(support.explored[player] == expected[player], "Cell mismatch at %d" % iteration)
			_check(
				support.explored[player].keys() == expected[player].keys(),
				"Exploration order mismatch at %d" % iteration
			)
			_comparisons += 1
	var stats: Array = _native.exploration_statistics()
	_check(
		stats.size() == 3 and stats[0] > 0 and stats[1] > 0 and stats[2] > 0,
		"Native exploration did not execute both scans and visibility queries"
	)
	_check(_comparisons == 480, "Full ledger comparison did not finish")
