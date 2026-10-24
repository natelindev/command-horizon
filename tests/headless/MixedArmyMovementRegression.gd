extends "res://tests/headless/NavigationRegression.gd"


## Twenty mixed-size/speed units cross authored settlements and a factory,
## then retreat through a stationary friendly screen. Reuses the ordinary
## click-formation dispatcher and measures actual motion, not only nav paths.
func _test_group_route():
	var units = []
	var roles = ["Infantry", "Worker", "Tank", "AdvancedTank", "RepairRobot"]
	for index in 20:
		var point = Vector3(8 + (index % 4) * 2.5, 0, 17 + (index / 4) * 2.5)
		var unit = _spawn(roles[index % roles.size()], point)
		unit.stance = unit.Stance.HOLD_FIRE
		units.append(unit)
	await _frames(60)
	await _traverse(units, Vector3(39, 0, 25), "mixed advance")
	var screen = []
	for point in [Vector3(25, 0, 21), Vector3(25, 0, 24), Vector3(25, 0, 27)]:
		var defender = _spawn("Tank", point)
		defender.stance = defender.Stance.HOLD_FIRE
		screen.append(defender)
	await _frames(60)
	await _traverse(units, Vector3(9, 0, 25), "mixed retreat through allies")
	for unit in units + screen:
		unit.queue_free()
	await _frames(6)


func _traverse(units, destination, label):
	var utility = root.get_node("Utils").Match.Unit.Movement
	var pairs = utility.crowd_moved_to_new_pivot(units, destination)
	var order_type = load("res://source/match/orders/ManualOrders.gd")
	var previous = {}
	var arrived = {}
	var max_step = 0.0
	var elapsed = 0.0
	var excess_steps = 0
	for pair in pairs:
		pair[0].manual_orders.submit(order_type.point_order("move", pair[1]))
		previous[pair[0]] = pair[0].global_position
	for frame in 2700:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		for pair in pairs:
			var unit = pair[0]
			var step = previous[unit].distance_to(unit.global_position)
			max_step = maxf(max_step, step)
			if step > unit.get_node("Movement").speed / Engine.physics_ticks_per_second + 0.003:
				excess_steps += 1
			previous[unit] = unit.global_position
			if _formation_arrived(unit, pair[1], units):
				arrived[unit] = true
		if arrived.size() == units.size():
			break
	for pair in pairs:
		if not arrived.has(pair[0]):
			print(
				"MIXED STALL ",
				label,
				" ",
				pair[0].type,
				" at=",
				pair[0].position,
				" goal=",
				pair[1]
			)
	_check(arrived.size() == units.size(), label + ": stranded mixed-army units")
	_check(excess_steps == 0, label + ": unit exceeded its movement speed")
	print(
		"MIXED ",
		label,
		" arrived=",
		arrived.size(),
		"/",
		units.size(),
		" seconds=",
		elapsed,
		" max_step=",
		max_step
	)
