extends "res://tests/headless/NavigationProjectionRegression.gd"


func _run():
	var loader = load("res://source/match/rendering/NativePosePacker.gd").create()
	if loader == null or not ClassDB.class_exists("CopperfinCrowdRuntime"):
		push_error("Native crowd runtime is required for this test")
		await root.get_node("Globals").quit_game(1)
		return
	await super._run()


func _compare_projection(label):
	super._compare_projection(label)
	_compare_native(label, false)


func _compare_hinted_projection(label):
	super._compare_hinted_projection(label)
	_compare_native(label, true)


func _compare_native(label: String, continuous: bool):
	var terrain = game.navigation.terrain
	var iteration := NavigationServer3D.map_get_iteration_id(terrain.navigation_map_rid)
	var valid: bool = (
		not terrain._is_baking
		and terrain._earliest_frame_to_perform_next_rebake == null
		and terrain.is_synchronized()
	)
	if valid and terrain._projection_iteration != iteration:
		terrain._index_projection_surface(iteration)
	var runtime = ClassDB.instantiate("CopperfinCrowdRuntime")
	var agents = game.get_units().filter(
		func(unit):
			var movement = unit.get_node_or_null("Movement")
			return (
				movement is NavigationAgent3D
				and movement.domain == constants.Match.Navigation.Domain.TERRAIN
			)
	)
	_check(not agents.is_empty(), "Native projection fixture has no ground agent")
	if agents.is_empty():
		return
	var unit = agents[0]
	var agent = unit.get_node("Movement")
	var enabled: bool = agent.is_physics_processing()
	agent.set_physics_process(false)
	var handle: int = runtime.bind_agent(agent, unit, false)
	var model = game.map.terrain if terrain._elevated else null
	_check(
		runtime.configure_projection(
			terrain._projection_cells,
			model.heights if model != null else PackedFloat32Array(),
			model.columns if model != null else 0,
			model.rows if model != null else 0,
			terrain._elevated,
			iteration
		),
		"Native projection configuration failed"
	)
	if "--native-nearest-surface" in OS.get_cmdline_user_args():
		var region: NavigationRegion3D = terrain._navigation_region
		var mesh := region.navigation_mesh
		var polygons := []
		for index in mesh.get_polygon_count():
			polygons.append(mesh.get_polygon(index))
		_check(
			runtime.configure_surface(
				mesh.get_vertices(), polygons, region.global_transform, iteration
			),
			"Native nearest surface configuration failed"
		)
	runtime.step(1.0 / 30.0, game.simulation_time, valid)
	var random := RandomNumberGenerator.new()
	random.seed = 87199
	var point := Vector3(112, 0, 112)
	for index in 1800:
		if not continuous or index % 50 == 0:
			point = Vector3(
				random.randf_range(-2, game.map.size.x + 2),
				[-2.0, 0.0, .6, 2.0, 8.0][index % 5],
				random.randf_range(-2, game.map.size.y + 2)
			)
		else:
			point += Vector3(random.randf_range(-.2, .2), 0, random.randf_range(-.2, .2))
		var expected: Vector3 = terrain.closest_point(point)
		var actual: Vector3 = runtime.project_point(point, handle)
		_check(
			actual.distance_to(expected) < .0001,
			"%s: native projection differs at %s: %s / %s" % [label, point, actual, expected]
		)
	if "--native-nearest-surface" in OS.get_cmdline_user_args():
		var surface: Array = runtime.surface_statistics()
		_check(surface[0] > 0 and surface[1] > 0, "Native surface hierarchy was empty")
		_check(
			(surface[2] > 0) == valid,
			"Native nearest surface execution/publication guard differed: " + label
		)
	runtime.unbind_agent(handle)
	agent.set_physics_process(enabled)
