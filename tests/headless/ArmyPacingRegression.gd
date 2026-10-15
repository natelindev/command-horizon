extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	departure_type = load("res://source/match/effects/ProductionDeparture.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		await _reinforcements()
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Army pacing: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _reinforcements():
	# A funded batch measures real queue/departure throughput. Resource gathering
	# is deliberately separate: construction and reinforcements still pay full cost.
	var barracks = _spawn("Barracks", Vector3(30, 0, 12))
	var factories = [
		_spawn("VehicleFactory", Vector3(40, 0, 12)), _spawn("VehicleFactory", Vector3(50, 0, 12))
	]
	for index in 3:
		_spawn("PowerPlant", Vector3(30 + index * 8, 0, 24))
	await _frames(30)
	_check(human.production_factor() == 1.0, "Pacing fixture lacks power")
	var producers = [barracks] + factories
	var plans = []
	plans.append(
		[
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry",
			"Infantry"
		]
	)
	for index in 2:
		plans.append(["Tank", "Tank", "Tank", "RepairRobot"])
	var original = get_nodes_in_group("units")
	var budget = Vector2i(human.resource_a, human.resource_b)
	var elapsed = 0.0
	var delivered = 0
	while elapsed < 70.0 and delivered < 20:
		for index in producers.size():
			var queue = producers[index].production_queue
			if not plans[index].is_empty() and queue.size() < 5:
				var role = plans[index].pop_front()
				_check(
					queue.produce(load(factions.Bastion.scene_path(role))) != null,
					"Paid reinforcement refused: " + role
				)
			queue._process(.1)
		# Free each delivered unit after counting, representing a rally away from
		# the exit. Exit crowd handling has its own movement regression.
		for unit in get_nodes_in_group("units"):
			if unit not in original and not unit.is_queued_for_deletion():
				delivered += 1
				unit.queue_free()
		await _frames(1)
		elapsed += .1
	_check(delivered == 20 and elapsed <= 61.0, "Mixed army took over a minute at full power")
	var infantry = factions.cost(human, "Infantry")
	var tank = factions.cost(human, "Tank")
	var support = factions.cost(human, "RepairRobot")
	var cost = Vector2i(infantry.resource_a, infantry.resource_b) * 12
	cost += Vector2i(tank.resource_a, tank.resource_b) * 6
	cost += Vector2i(support.resource_a, support.resource_b) * 2
	_check(
		budget - Vector2i(human.resource_a, human.resource_b) == cost,
		"Faster production changed the mixed-army cost"
	)
	print(
		"PACING ",
		human.faction,
		" delivered=",
		delivered,
		" seconds=",
		elapsed,
		" material=",
		cost.x,
		" electronics=",
		cost.y,
		" basic_base_seconds=",
		(
			factions.BUILD_TIMES.PowerPlant
			+ factions.BUILD_TIMES.Barracks
			+ factions.BUILD_TIMES.VehicleFactory
		)
	)
