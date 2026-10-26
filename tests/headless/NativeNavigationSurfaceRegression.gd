extends "res://tests/headless/MapResourceBalanceRegression.gd"

## Exercise the complete native nearest-polygon kernel, with containment fast
## paths deliberately absent, against the actual navigation server on every map.
var _comparisons := 0
var _native_queries := 0


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var loader = load("res://source/match/rendering/NativePosePacker.gd").create()
	if loader == null or not ClassDB.class_exists("CopperfinCrowdRuntime"):
		_check(false, "Native runtime is required")
	else:
		for map_path in constants.Match.MAPS:
			await _create(map_path)
			_compare_surface(map_path)
			game.queue_free()
			await _frames(5)
	_check(
		_comparisons == constants.Match.MAPS.size() * 2403,
		"All-map surface comparison did not complete"
	)
	_check(
		_native_queries >= constants.Match.MAPS.size() * 2401,
		"Queries did not reach the native surface hierarchy"
	)
	for message in _errors:
		push_error(message)
	print(
		(
			"Native navigation surface: %d failures across %d direct server comparisons"
			% [_errors.size(), _comparisons]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare_surface(map_path: String):
	var terrain = game.navigation.terrain
	var region: NavigationRegion3D = terrain._navigation_region
	var mesh := region.navigation_mesh
	var iteration := NavigationServer3D.map_get_iteration_id(terrain.navigation_map_rid)
	var units = game.get_units().filter(
		func(unit):
			var movement = unit.get_node_or_null("Movement")
			return (
				movement is NavigationAgent3D
				and movement.domain == constants.Match.Navigation.Domain.TERRAIN
			)
	)
	_check(not units.is_empty(), "Surface fixture has no agent")
	if units.is_empty():
		return
	var agent = units[0].get_node("Movement")
	var processing: bool = agent.is_physics_processing()
	agent.set_physics_process(false)
	var runtime = ClassDB.instantiate("CopperfinCrowdRuntime")
	var handle: int = runtime.bind_agent(agent, units[0], false)
	_check(
		runtime.configure_projection({}, PackedFloat32Array(), 0, 0, false, iteration),
		"Empty containment configuration failed"
	)
	var polygons := []
	for index in mesh.get_polygon_count():
		polygons.append(mesh.get_polygon(index))
	var vertices := mesh.get_vertices()
	_check(
		runtime.configure_surface(vertices, polygons, region.global_transform, iteration),
		"Surface configure failed: " + map_path
	)
	var random := RandomNumberGenerator.new()
	random.seed = 912017
	for index in 2400:
		var point := Vector3(
			random.randf_range(-10, game.map.size.x + 10),
			random.randf_range(-5, 14),
			random.randf_range(-10, game.map.size.y + 10)
		)
		if index < vertices.size():
			# Navmesh vertices and nearby plane/edge points cover ties and near-zero exits.
			point = region.global_transform * vertices[index]
			point += [
				Vector3.ZERO,
				Vector3(.000001, .000001, -.000001),
				Vector3(.01, -.1, .01),
				Vector3(.25, .5, -.25)
			][index % 4]
		_compare_query(runtime, handle, point, map_path)
	# The runtime owns a snapshot, rather than borrowing these engine arrays.
	vertices[0] += Vector3(500, 100, 500)
	polygons.clear()
	_compare_query(runtime, handle, Vector3(18, .5, 18), map_path + " owned arrays")
	var statistics: Array = runtime.surface_statistics()
	_native_queries += statistics[2]
	_check(
		statistics[0] == mesh.get_polygon_count() and statistics[1] > 0, "Surface omitted polygons"
	)
	if statistics[0] > 32:
		_check(
			statistics[3] < statistics[2] * statistics[0] / 2,
			"Hierarchy did not prune polygon work: " + map_path
		)
	var previous_queries: int = statistics[2]
	# Marking publication unavailable must prevent every native nearest query.
	runtime.step(1.0 / 30.0, game.simulation_time, false)
	_compare_query(runtime, handle, Vector3(-2, 3, -2), map_path + " unavailable")
	_check(runtime.surface_statistics()[2] == previous_queries, "Unpublished surface was used")
	_check(
		not runtime.configure_surface(
			mesh.get_vertices(), [PackedInt32Array([-1, 0, 1])], region.global_transform, iteration
		),
		"Invalid polygon indices were accepted"
	)
	_check(
		runtime.surface_statistics()[0] == 0, "Failed surface replacement retained stale geometry"
	)
	runtime.step(1.0 / 30.0, game.simulation_time, true)
	_compare_query(runtime, handle, Vector3(18, .5, 18), map_path + " failed replacement fallback")
	runtime.unbind_agent(handle)
	agent.set_physics_process(processing)
	print(
		(
			"NATIVE_SURFACE %s polygons=%d queries=%d tested=%d"
			% [map_path.get_file(), statistics[0], statistics[2], statistics[3]]
		)
	)


func _compare_query(runtime, handle: int, point: Vector3, label: String):
	var expected := NavigationServer3D.map_get_closest_point(
		game.navigation.terrain.navigation_map_rid, point
	)
	var actual: Vector3 = runtime.project_point(point, handle)
	_comparisons += 1
	if (not actual.is_finite() or actual.distance_to(expected) > .0001) and _errors.size() < 30:
		_check(
			false, "%s: native nearest differs at %s: %s / %s" % [label, point, actual, expected]
		)
