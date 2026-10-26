extends SceneTree

var _errors = []


class Side:
	extends Node
	var team = -1

	func is_allied_with(other):
		return (
			other == self
			or (other != null and "team" in other and team >= 0 and other.team == team)
		)


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
	var sides = [Side.new(), Side.new(), Side.new(), Side.new()]
	for index in sides.size():
		var side = sides[index]
		side.team = index % 2
		root.add_child(side)
	var random = RandomNumberGenerator.new()
	random.seed = 74119
	var bodies = []
	for index in 200:
		var body = Body.new()
		body.player = sides[index % sides.size()]
		body.sight_range = random.randf_range(1.0, 15.0)
		root.add_child(body)
		body.add_to_group("units")
		if index % 10 == 0:
			body.add_to_group("repair_platforms")
		# Include negative coordinates and points immediately beside grid edges.
		body.position = Vector3(
			floorf(random.randf_range(-4, 4)) * 12.0 + .01,
			0,
			floorf(random.randf_range(-4, 4)) * 12.0 - .01
		)
		bodies.append(body)
	await physics_frame
	await physics_frame
	_check_index_parity(field)
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
		var platforms = field.nearby_repair_platforms(point)
		var expected_platforms = bodies.filter(
			func(body):
				return (
					body.is_in_group("repair_platforms")
					and body.position.distance_squared_to(point) <= 4.0
				)
		)
		_check(
			(
				platforms.size() == expected_platforms.size()
				and platforms.all(func(body): return body in expected_platforms)
			),
			"Spatial service decks differ from live scan"
		)
		var platform_queries = field._native_queries
		field._native_queries = null
		var fallback_platforms = field.nearby_repair_platforms(point)
		field._native_queries = platform_queries
		_check(
			(
				fallback_platforms.size() == expected_platforms.size()
				and fallback_platforms.all(func(body): return body in expected_platforms)
			),
			"Script service decks differ from live scan"
		)
		target.position = point
		for side in sides:
			var expected = bodies.any(
				func(body):
					return side.is_allied_with(body.player) and field.can_observe(body, target)
			)
			_check(
				field.is_observed(side, target) == expected, "Spatial vision differs from live scan"
			)
		for reach in [1.0, 5.9, 6.0, 20.0]:
			var actual = field.nearby_units(point, reach)
			var native = field._native_queries
			var resident: bool = field._resident_index_used
			field._native_queries = null
			field._resident_index_used = false
			_check(actual == field.nearby_units(point, reach), "Native query changed body ordering")
			field._native_queries = native
			field._resident_index_used = resident
			var expected = bodies.filter(
				func(body): return body.position.distance_squared_to(point) <= reach * reach
			)
			_check(actual.size() == expected.size(), "Spatial body count differs from live scan")
			for body in expected:
				_check(body in actual, "Spatial query lost a body crossing a cell boundary")
			var allies = field.nearby_units(point, reach, sides[0])
			var enemies = field.nearby_units(point, reach, null, sides[0])
			var combat = field.nearby_combat_targets(point, reach, sides[0])
			var opposing = expected.filter(
				func(body): return not sides[0].is_allied_with(body.player)
			)
			_check(
				(
					combat.size() == opposing.size()
					and combat.all(func(body): return body in opposing)
				),
				"Combat acquisition included a teammate or lost an enemy"
			)
			field._native_queries = null
			field._resident_index_used = false
			_check(
				allies == field.nearby_units(point, reach, sides[0]),
				"Native ally query changed ordered results"
			)
			_check(
				enemies == field.nearby_units(point, reach, null, sides[0]),
				"Native enemy query changed ordered results"
			)
			field._native_queries = native
			field._resident_index_used = resident
			_check(
				field.nearby_units(point, reach, sides[0], sides[0]).is_empty(),
				"Conflicting owner filters returned bodies"
			)
			_check(allies.all(func(body): return body.player == sides[0]), "Ally filter leaked")
			_check(enemies.all(func(body): return body.player != sides[0]), "Enemy filter leaked")
			_check(allies.size() + enemies.size() == actual.size(), "Player filters lost bodies")
	# Neutral service sites need only Node3D position, and queries ignore height.
	var neutral_platform = Node3D.new()
	root.add_child(neutral_platform)
	neutral_platform.position = Vector3(100, 12, 100)
	neutral_platform.add_to_group("repair_platforms")
	var original_platform_queries = field._native_queries
	for platform_backend in [original_platform_queries, null]:
		field._native_queries = platform_backend
		field.invalidate()
		_check(
			neutral_platform in field.nearby_repair_platforms(Vector3(100, -20, 100)),
			"Neutral elevated service deck was lost by a query backend"
		)
	neutral_platform.free()
	field._native_queries = original_platform_queries
	field.invalidate()
	# Ownership is authoritative even after the frame's grid was built.
	var captured = bodies[1]
	captured.player = sides[0]
	_check(
		captured in field.nearby_units(captured.position, 2.0, sides[0]),
		"Same-tick capture lost new ally"
	)
	_check(
		captured not in field.nearby_units(captured.position, 2.0, sides[1]),
		"Same-tick capture retained old owner"
	)
	var new_owner = Node.new()
	root.add_child(new_owner)
	captured.player = new_owner
	_check(
		captured in field.nearby_units(captured.position, 2.0, null, sides[0]),
		"Unassigned owner bit excluded a new owner"
	)
	_check(
		captured in field.nearby_units(captured.position, 2.0, new_owner),
		"Same-tick new owner filter lost capture"
	)
	captured.player = sides[0]
	new_owner.free()
	var spawned = Body.new()
	spawned.player = sides[2]
	root.add_child(spawned)
	spawned.add_to_group("units")
	spawned.position = Vector3(300, 0, -300)
	root.get_node("MatchSignals").unit_spawned.emit(spawned)
	_check(
		spawned in field.nearby_units(spawned.position, 1.0),
		"Spawn signal left the current grid stale"
	)
	spawned.free()
	var queued = Body.new()
	queued.player = sides[0]
	root.add_child(queued)
	queued.add_to_group("units")
	field.invalidate()
	field._refresh()
	queued.queue_free()
	_check(queued not in field.nearby_units(Vector3.ZERO, 5.0), "Queued deletion leaked into query")
	var vision = Body.new()
	vision.player = sides[0]
	root.add_child(vision)
	vision.add_to_group("vision_sources")
	field.invalidate()
	_check_index_parity(field)
	_check(
		vision not in field.nearby_units(Vector3.ZERO, 20), "Vision proxy leaked into body queries"
	)
	vision.free()
	bodies[0].radius = 2.4
	bodies[0].movement_speed = 9.0
	bodies[0].sight_range = 23.0
	bodies[0].set_meta("garrison_host", bodies[1])
	sides[3].team = -1
	_check_index_parity(field)
	_benchmark_index(field)
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
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _check_index_parity(field):
	var native = field._native_queries
	if native == null or not native.has_method("index_observers"):
		return
	var enabled = field._native_index
	var resident: bool = field.native_battlefield_index
	field.native_battlefield_index = false
	field._native_index = false
	field.invalidate()
	field._refresh()
	var expected = [
		field._observers.duplicate(true),
		field._bodies.duplicate(true),
		field._units.duplicate(true),
		field._max_sight,
		field._max_unit_radius,
		field._max_body_step
	]
	var observers = get_nodes_in_group("units") + get_nodes_in_group("vision_sources")
	var actual = native.index_observers(observers, field.get_physics_process_delta_time())
	_check(
		actual == expected, "Native spatial index changed ordered cells, ownership or live bounds"
	)
	field._native_index = enabled
	field.native_battlefield_index = resident
	if resident:
		var bounds: Array = field._native_visibility.rebuild_index(
			observers, field.get_physics_process_delta_time()
		)
		_check(bounds == expected.slice(3), "Resident index changed live bounds")
		field._resident_index_used = bounds.size() == 3
		# Retain the script grids from the same positions as an ordered oracle.
		# Both backends now see subsequent movement through their narrow phases.
	else:
		field.invalidate()
		field._refresh()


func _benchmark_index(field):
	if field._native_queries == null or not field._native_queries.has_method("index_observers"):
		return
	var enabled = field._native_index
	var resident: bool = field.native_battlefield_index
	if resident:
		var statistics: Array = field._native_visibility.index_statistics()
		_check(
			statistics[5] > 0 and statistics[6] > 0, "Resident nearby/observation scans were unused"
		)
	for backend in ["script", "native_dict", "resident"] if resident else ["script", "native_dict"]:
		field._native_index = backend == "native_dict"
		field.native_battlefield_index = backend == "resident"
		var start = Time.get_ticks_usec()
		for index in 100:
			field._frame = -1
			field._refresh()
		print(
			"SPATIAL_INDEX backend=",
			backend,
			" refresh_us=",
			(Time.get_ticks_usec() - start) / 100.0
		)
	field._native_index = enabled
	field.native_battlefield_index = resident


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
