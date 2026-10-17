extends SceneTree

var _errors = []


class Body:
	extends Node3D
	var player
	var hp = 100.0
	var radius = 1.0
	var sight_range = 10.0
	var movement_speed = 30.0


func _initialize():
	call_deferred("_run")


func _run():
	var field = load("res://source/match/combat/Battlefield.gd").new()
	root.add_child(field)
	var sides = [Node.new(), Node.new()]
	for side in sides:
		root.add_child(side)
	var random = RandomNumberGenerator.new()
	random.seed = 74119
	var bodies = []
	for index in 128:
		var body = Body.new()
		body.player = sides[index % 2]
		body.sight_range = random.randf_range(1.0, 15.0)
		root.add_child(body)
		body.add_to_group("units")
		# Include negative coordinates and points immediately beside grid edges.
		body.position = Vector3(
			floorf(random.randf_range(-4, 4)) * 12.0 + .01,
			0,
			floorf(random.randf_range(-4, 4)) * 12.0 - .01
		)
		bodies.append(body)
	await physics_frame
	await physics_frame
	field._refresh()
	# Avoidance callbacks move units sequentially after the frame index is built.
	# Move across cell boundaries without invalidation or a physics tick.
	var step: float = field._max_body_step
	_check(step > 0.0, "Fixture did not establish a movement allowance")
	for body in bodies:
		body.position += Vector3.RIGHT.rotated(Vector3.UP, random.randf() * TAU) * step
	var target = Body.new()
	root.add_child(target)
	for index in 160:
		var point := Vector3(random.randf_range(-60, 60), 0, random.randf_range(-60, 60))
		target.position = point
		for side in sides:
			var expected = bodies.any(
				func(body): return body.player == side and field.can_observe(body, target)
			)
			_check(
				field.is_observed(side, target) == expected, "Spatial vision differs from live scan"
			)
		for reach in [1.0, 5.9, 6.0, 20.0]:
			var actual = field.nearby_units(point, reach)
			var expected = bodies.filter(
				func(body): return body.position.distance_squared_to(point) <= reach * reach
			)
			_check(actual.size() == expected.size(), "Spatial body count differs from live scan")
			for body in expected:
				_check(body in actual, "Spatial query lost a body crossing a cell boundary")
			var allies = field.nearby_units(point, reach, sides[0])
			var enemies = field.nearby_units(point, reach, null, sides[0])
			_check(allies.all(func(body): return body.player == sides[0]), "Ally filter leaked")
			_check(enemies.all(func(body): return body.player != sides[0]), "Enemy filter leaked")
			_check(allies.size() + enemies.size() == actual.size(), "Player filters lost bodies")
	# Empty cells and removed bodies must remain safe after prior populated queries.
	bodies[0].free()
	field.nearby_units(Vector3.ZERO, 100.0)
	_check(field.nearby_units(Vector3(1000, 0, 1000), 10.0).is_empty(), "Empty cell leaked bodies")
	for body in bodies:
		if is_instance_valid(body):
			body.free()
	target.free()
	field.free()
	for side in sides:
		side.free()
	for error in _errors:
		push_error(error)
	print("Spatial query regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
