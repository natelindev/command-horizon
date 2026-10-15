extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	departure_type = load("res://source/match/effects/ProductionDeparture.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		for pair in [
			["Barracks", "Infantry"],
			["CommandCenter", "Worker"],
			["VehicleFactory", "Tank"],
			["AircraftFactory", "Helicopter"]
		]:
			await _clearance(pair[0], pair[1])
		await _packed_exit()
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Automatic exit clearance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _clearance(producer_role, role):
	var building = _spawn(producer_role, Vector3(40, 0, 12))
	await _frames(30)
	var queue = building.production_queue
	var job = queue.produce(load(factions.Bastion.scene_path(role)))
	_check(job != null, "Clearance fixture cannot produce " + role)
	if job == null:
		building.queue_free()
		return
	queue._process((job.time_total - departure_type.seconds(job) * .95) / human.production_factor())
	_check(not queue.exit_blocked, "Clearance fixture starts obstructed: " + role)
	if queue.exit_blocked:
		building.queue_free()
		return
	var blocker = _spawn(role, queue.departure.endpoint)
	blocker.process_mode = Node.PROCESS_MODE_INHERIT
	blocker.stance = blocker.Stance.HOLD_FIRE
	await _frames(5)
	blocker.global_position = queue.departure.endpoint
	var origin = blocker.global_position
	var movement = blocker.get_node("Movement")
	var orders = [
		blocker.manual_orders.current.duplicate(true), blocker.manual_orders.pending.duplicate(true)
	]
	var remaining = job.time_left
	queue._process(.1)
	_check(queue.exit_blocked and job.time_left == remaining, "Obstructed exit spends paid time")
	_check(movement._exit_clearance_target.is_finite(), "Friendly blocker has no sidestep: " + role)
	var produced_before = _units(human, role)
	var funds = Vector2i(human.resource_a, human.resource_b)
	var started = game.simulation_time
	for frame in 480:
		await _frames(1)
		queue._process(1.0 / 60.0)
		if queue.size() == 0:
			break
	_check(queue.size() == 0, human.faction + ": production stayed blocked by " + role)
	_check(blocker.global_position.distance_to(origin) > .3, "Blocker did not actually move")
	_check(
		(
			[
				blocker.manual_orders.current.duplicate(true),
				blocker.manual_orders.pending.duplicate(true)
			]
			== orders
		),
		"Exit clearance replaced manual orders"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Exit clearance charged twice")
	var produced = _units(human, role).filter(func(unit): return unit not in produced_before)
	_check(produced.size() == 1, "Clearance duplicated or lost paid unit")
	print(
		"EXIT ",
		human.faction,
		" ",
		role,
		" seconds=",
		game.simulation_time - started,
		" moved=",
		blocker.global_position.distance_to(origin),
		" produced=",
		produced.size()
	)
	for unit in produced:
		unit.queue_free()
	blocker.queue_free()
	building.queue_free()
	await _frames(5)


func _packed_exit():
	var building = _spawn("VehicleFactory", Vector3(40, 0, 12))
	await _frames(30)
	var queue = building.production_queue
	var job = queue.produce(load(factions.Bastion.scene_path("Tank")))
	queue._process((job.time_total - departure_type.seconds(job) * .95) / human.production_factor())
	if queue.exit_blocked:
		_check(false, "Packed fixture starts blocked")
		building.queue_free()
		return
	var exit = queue.departure.endpoint
	var blockers = []
	for row in 3:
		for column in [-1, 0, 1]:
			var blocker = _spawn("Tank", exit + Vector3(column * 2.2, 0, -row * 2.2))
			blocker.stance = blocker.Stance.HOLD_FIRE
			blocker.process_mode = Node.PROCESS_MODE_INHERIT
			blockers.append(blocker)
	await _frames(5)
	# A genuine opponent blockade must never be moved by this producer.
	var other_player = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var central = blockers[1]
	central.player = other_player
	queue._process(.1)
	_check(queue.exit_blocked, "Enemy blockade was ignored")
	_check(
		not central.get_node("Movement")._exit_clearance_target.is_finite(), "Enemy was auto-moved"
	)
	central.player = human
	var movement = central.get_node("Movement")
	movement.move(exit + Vector3(0, 0, -20))
	var destination = movement.target_position
	queue._process(.1)
	_check(
		movement.target_position == destination and movement._has_destination,
		"Yielding replaced the existing move destination"
	)
	var before = _units(human, "Tank")
	var started = game.simulation_time
	for frame in 900:
		await _frames(1)
		queue._process(1.0 / 60.0)
		if queue.size() == 0:
			break
	_check(queue.size() == 0, human.faction + ": packed nine-tank exit never cleared")
	print("PACKED EXIT ", human.faction, " seconds=", game.simulation_time - started)
	for unit in _units(human, "Tank"):
		if unit in blockers or unit not in before:
			unit.queue_free()
	building.queue_free()
	await _frames(5)
