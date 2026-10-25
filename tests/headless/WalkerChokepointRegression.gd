extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("helix", "res://source/match/maps/battlefields/AlpineRelayMap.tscn", false)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for route in [
		[Vector2(100, 23), Vector2(153, 76)],
		[Vector2(39, 84), Vector2(92, 137)],
		[Vector2(137, 7), Vector2(170, 38)],
		[Vector2(170, 38), Vector2(137, 7)],
		[Vector2(58, 46), Vector2(26, 46)]
	]:
		for count in [6, 8]:
			await _cross(route[0], route[1], count)
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Walker chokepoints: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _cross(start, goal, count):
	var axis = (goal - start).normalized()
	var walkers = []
	for index in count:
		var point = start + axis.orthogonal() * ((index % 4) - 1.5) * 2.1 - axis * (index / 4) * 2.1
		var walker = _spawn("CombatRobot", game.map.ground_point(point))
		walker.process_mode = Node.PROCESS_MODE_INHERIT
		walker.stance = walker.Stance.HOLD_FIRE
		walkers.append(walker)
	await _frames(60)
	var movement_utils = root.get_node("Utils").Match.Unit.Movement
	var destinations = movement_utils.crowd_moved_to_new_pivot(walkers, game.map.ground_point(goal))
	var moving = load("res://source/match/units/actions/Moving.gd")
	for pair in destinations:
		pair[0].issue_manual_order(moving.new(pair[1]))
	var started = game.simulation_time
	var arrived = false
	var crossed = {}
	var passage_times = {}
	var arrived_times = {}
	var recoveries = {}
	var maximum_stall = {}
	var previous = {}
	var stall = {}
	var minimum_gap = INF
	for step in 180:
		await _frames(30)
		for pair in destinations:
			var unit = pair[0]
			var movement = unit.get_node("Movement")
			var along = (Vector2(unit.position.x, unit.position.z) - start).dot(axis)
			if along >= start.distance_to(goal) - 12 and not passage_times.has(unit):
				passage_times[unit] = game.simulation_time - started
			if movement._recovery_left > 0:
				recoveries[unit] = recoveries.get(unit, 0) + 1
			if (
				unit.global_position_yless.distance_to(pair[1] * Vector3(1, 0, 1)) < 2.0
				or (not movement._has_destination and passage_times.has(unit))
			):
				crossed[unit] = true
				if not arrived_times.has(unit):
					arrived_times[unit] = game.simulation_time - started
			if (
				previous.has(unit)
				and unit.position.distance_to(previous[unit]) < .15
				and not crossed.has(unit)
			):
				stall[unit] = stall.get(unit, 0.0) + .5
			else:
				stall[unit] = 0.0
			maximum_stall[unit] = maxf(stall[unit], maximum_stall.get(unit, 0.0))
			previous[unit] = unit.position
		for i in walkers.size():
			for j in range(i + 1, walkers.size()):
				minimum_gap = minf(
					minimum_gap,
					(
						walkers[i].global_position_yless.distance_to(
							walkers[j].global_position_yless
						)
						- walkers[i].radius
						- walkers[j].radius
					)
				)
		arrived = crossed.size() == walkers.size() and passage_times.size() == walkers.size()
		if arrived:
			break
	print(
		"WALKER PASS ",
		count,
		" units ",
		start,
		" -> ",
		goal,
		" arrived=",
		arrived,
		" seconds=",
		game.simulation_time - started
	)
	_check(
		arrived, "%d Lancer walkers failed the Alpine Relay passage %s -> %s" % [count, start, goal]
	)
	_check(minimum_gap >= -.03, "Walkers overlapped in the chokepoint: %.3f m" % minimum_gap)
	if not arrived:
		for pair in destinations:
			print(
				"STRANDED ",
				pair[0].position,
				" destination=",
				pair[1],
				" passage=",
				passage_times.get(pair[0], -1)
			)
	for unit in walkers:
		unit.queue_free()
	await _frames(5)
