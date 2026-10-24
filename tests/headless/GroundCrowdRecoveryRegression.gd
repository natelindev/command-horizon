extends "res://tests/headless/NavigationRegression.gd"

# Mechanism reproduction of the intermittent arena crowd stall, not an exact
# replay of its unrecorded neighbor state. These non-overlapping positions were
# observed after settling a crowd beside the eastern settlement. The mover has
# a two-metre backward escape but only centimetres of room on either side.
const MOVER = 3
const GOAL = Vector3(35.14706, 0, 23.58824)
const POSITIONS = [
	Vector3(34.5, 0, 21.25),
	Vector3(37.45, 0, 21.7),
	Vector3(34.55, 0, 27.45),
	Vector3(31.42166, 0, 28.24897),
	Vector3(37.0, 0, 27.45),
	Vector3(39.5, 0, 23.75),
	Vector3(39.45, 0, 27.45),
	Vector3(32.1, 0, 20.1),
	Vector3(32.10592, 0, 29.91385),
	Vector3(37.0, 0, 29.9),
	Vector3(41.50225, 0, 20.36661),
	Vector3(41.47224, 0, 29.63395),
]


func _test_group_route():
	var units = []
	for point in POSITIONS:
		units.append(_spawn("Tank", point))
	await _frames(60)
	for index in range(units.size()):
		var unit = units[index]
		unit.action = null
		unit.global_position = POSITIONS[index]
		unit.reset_physics_interpolation()
		unit.get_node("Movement").stop()
		unit.get_node("Movement").set_velocity_forced(Vector3.ZERO)
	_game.battlefield.invalidate()
	var mover = units[MOVER]
	var movement = mover.get_node("Movement")
	var path = NavigationServer3D.map_get_path(
		movement.get_navigation_map(), mover.global_position, GOAL, true
	)
	_check(path.size() > 1, "Crowd recovery fixture has no route")
	if path.size() <= 1:
		return
	var direction = ((path[1] - mover.global_position) * Vector3(1, 0, 1)).normalized()
	var neighbors = units.filter(func(unit): return unit != mover)
	var chosen = movement._ground_recovery_direction(direction)
	var distance = movement._recovery_clearance(chosen)
	var contact = movement._ground_step_contact(
		mover.global_position, mover.global_position + chosen * distance, neighbors
	)
	_check(
		distance * contact.fraction >= 1.9,
		"Recovery preferred centimetres of side clearance over a clear backward escape"
	)
	_check(chosen.dot(direction) < -0.5, "Crowd fixture did not select the open backward escape")
	mover.action = _moving.new(GOAL)
	var arrived = false
	var largest_step = 0.0
	var minimum_separation = INF
	var started = _game.simulation_time
	for frame in range(Engine.physics_ticks_per_second * 20):
		var previous = mover.global_position
		await physics_frame
		largest_step = maxf(largest_step, previous.distance_to(mover.global_position))
		for other in neighbors:
			minimum_separation = minf(
				minimum_separation,
				mover.global_position_yless.distance_to(other.global_position_yless)
			)
		if mover.global_position_yless.distance_to(GOAL) < 0.6:
			arrived = true
			break
	_check(arrived, "Tank did not escape the settled crowd and reach its destination")
	_check(
		largest_step <= mover.movement_speed / Engine.physics_ticks_per_second + 0.002,
		"Crowd recovery exceeded normal movement speed"
	)
	_check(
		minimum_separation >= mover.radius * 2 - 0.03,
		"Crowd recovery passed through a settled tank"
	)
	print(
		"CROWD RECOVERY: arrived=",
		arrived,
		" elapsed=",
		_game.simulation_time - started,
		" remaining=",
		mover.global_position_yless.distance_to(GOAL),
		" max_step=",
		largest_step,
		" min_separation=",
		minimum_separation
	)
	for unit in units:
		unit.queue_free()
	await _frames(6)
	await _test_blocked_corner()


func _test_blocked_corner():
	# Recorded from the exported mixed-army stall. A settled tank covers a
	# navigation corner; the worker must repath after its lateral escape.
	var points = [
		Vector3(12.12364, 0, 20.88976),
		Vector3(9.187503, 0, 20.11208),
		Vector3(12.4856, 0, 19.38254)
	]
	var units = []
	for index in points.size():
		var unit = _spawn("Worker" if index == 2 else "Tank", points[index])
		unit.stance = unit.Stance.HOLD_FIRE
		units.append(unit)
	await _frames(60)
	for index in units.size():
		units[index].global_position = points[index]
		var movement = units[index].get_node("Movement")
		movement.stop()
		movement.set_velocity_forced(Vector3.ZERO)
	_game.battlefield.invalidate()
	var mover = units[2]
	var goal = Vector3(8.08073, 0, 22.67416)
	mover.action = _moving.new(goal)
	var arrived = false
	var max_step = 0.0
	var minimum_gap = INF
	for frame in range(Engine.physics_ticks_per_second * 30):
		var previous = mover.global_position
		await physics_frame
		max_step = maxf(max_step, mover.global_position.distance_to(previous))
		for other in units.slice(0, 2):
			minimum_gap = minf(
				minimum_gap,
				(
					mover.global_position.distance_to(other.global_position)
					- mover.radius
					- other.radius
				)
			)
		if mover.global_position_yless.distance_to(goal) < .6:
			arrived = true
			break
	_check(arrived, "Worker kept returning to a corner inside a settled tank")
	_check(
		max_step <= mover.movement_speed / Engine.physics_ticks_per_second + .003,
		"Corner recovery exceeded movement speed"
	)
	_check(minimum_gap >= -.03, "Corner recovery passed through a tank")
	print(
		"CORNER RECOVERY: arrived=",
		arrived,
		" remaining=",
		mover.global_position.distance_to(goal),
		" min_gap=",
		minimum_gap,
		" max_step=",
		max_step
	)
	for unit in units:
		unit.queue_free()
	await _frames(6)
