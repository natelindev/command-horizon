extends "res://tests/headless/UnitAnimationRegression.gd"


## Compare the complete native ground steering/contact callback against the
## existing script on the same terrain, commands, bodies and safe velocities.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var loader = load("res://source/match/rendering/NativePosePacker.gd").create()
	if loader == null or not ClassDB.class_exists("CopperfinCrowdRuntime"):
		push_error("Native crowd runtime is required for this test")
		await root.get_node("Globals").quit_game(1)
		return
	await _fixture("bastion")
	var pairs := []
	for role in ["Tank", "AdvancedTank", "Infantry"]:
		pairs.append([_spawn(role, 0, Vector3(20, 0, 20)), _spawn(role, 0, Vector3(20, 0, 20))])
	var neighbors := []
	for role in ["Tank", "Worker", "CombatRobot", "Infantry"]:
		neighbors.append(_spawn(role, 0, Vector3(25, 0, 25)))
	_spawn("RepairDepot", 0, Vector3(42, 0, 42))
	await _frames(180)
	# This oracle owns its candidate runtime. A match-wide backend would make
	# the reference agent's script callback return without doing any steering.
	for pair in pairs:
		for unit in pair:
			_detach_match_runtime(unit.get_node("Movement"))
	for unit in neighbors:
		_detach_match_runtime(unit.get_node("Movement"))
	var terrain = _game.navigation.terrain
	while not terrain.is_synchronized():
		await physics_frame
	terrain._index_projection_surface(
		NavigationServer3D.map_get_iteration_id(terrain.navigation_map_rid)
	)
	var runtime = ClassDB.instantiate("CopperfinCrowdRuntime")
	_check(
		runtime.configure_projection(
			terrain._projection_cells,
			PackedFloat32Array(),
			0,
			0,
			false,
			terrain._projection_iteration
		),
		"Native movement projection setup failed"
	)
	if "--native-nearest-surface" in OS.get_cmdline_user_args():
		var region: NavigationRegion3D = terrain._navigation_region
		var mesh := region.navigation_mesh
		var polygons := []
		for index in mesh.get_polygon_count():
			polygons.append(mesh.get_polygon(index))
		_check(
			runtime.configure_surface(
				mesh.get_vertices(),
				polygons,
				region.global_transform,
				terrain._projection_iteration
			),
			"Native movement surface setup failed"
		)
	var neighbor_handles := []
	for unit in neighbors:
		var agent = unit.get_node("Movement")
		agent.avoidance_enabled = false
		neighbor_handles.append(runtime.bind_agent(agent, unit, unit.type in agent.VEHICLE_ROLES))
	var random := RandomNumberGenerator.new()
	random.seed = 79213
	var mismatches := 0
	for iteration in 750:
		for pair in pairs:
			for unit in pair:
				unit.position = Vector3(-1000, 0, -1000)
				unit.get_node("Movement").process_mode = Node.PROCESS_MODE_INHERIT
		var reference = pairs[iteration % pairs.size()][0]
		var candidate = pairs[iteration % pairs.size()][1]
		var reference_agent = reference.get_node("Movement")
		var candidate_agent = candidate.get_node("Movement")
		var origin := Vector3(random.randf_range(8, 65), 0, random.randf_range(8, 65))
		if iteration % 11 == 0:
			origin = (
				Vector3(42, .1, 42)
				+ Vector3(random.randf_range(-1, 1), 0, random.randf_range(-1, 1))
			)
		if iteration % 19 == 0:
			origin.y = 1.0
		var root_pose := Transform3D(Basis(Vector3.UP, random.randf_range(-PI, PI)), origin)
		var target := origin + Vector3(random.randf_range(-8, 8), 0, random.randf_range(-8, 8))
		var delta: float = [1.0 / 120.0, STEP, 1.0 / 30.0, .1][iteration % 4]
		var base_speed := random.randf_range(.1, 6.0)
		var requested := Vector3(random.randf_range(-3, 3), 0, random.randf_range(-3, 3))
		var recovery := (
			Vector3(random.randf_range(-1, 1), 0, random.randf_range(-1, 1)).normalized()
		)
		for unit in [reference, candidate]:
			unit.global_transform = root_pose
			unit.aim_target = neighbors[0] if iteration % 3 == 0 else null
			var agent = unit.get_node("Movement")
			agent.process_mode = Node.PROCESS_MODE_ALWAYS
			agent.avoidance_enabled = false
			agent._synchronized = true
			agent.speed = base_speed
			agent.ghosted = iteration % 13 == 0
			agent._physics_delta = delta
			agent._has_destination = iteration % 4 != 0
			agent.target_position = target
			agent.velocity = requested
			agent._command_revision = iteration
			agent._progress_position = origin
			agent._progress_elapsed = .98 if iteration % 7 == 0 else 0.0
			agent._recovery_left = .4 if iteration % 5 == 0 else 0.0
			agent._recovery_checked = iteration % 9 != 0
			agent._recovery_direction = recovery
			agent._previously_set_global_transform_of_unit = null
			agent._rotation_low_pass_filter_window = []
			agent._total_direction_in_the_low_pass_filter_window = Vector3.ZERO
			agent._passive_movement_detected = false
			agent._ground_alignment_height = INF
			agent._uses_platform_height = false
			agent._exit_clearance_target = origin + recovery if iteration % 17 == 0 else Vector3.INF
			agent._exit_clearance_until = _game.simulation_time + 2.0
		for index in neighbors.size():
			var unit = neighbors[index]
			unit.position = (
				origin + Vector3(random.randf_range(-2, 2), 0, random.randf_range(-2, 2))
			)
			var agent = unit.get_node("Movement")
			agent.speed = 0.0 if (iteration + index) % 11 == 0 else 3.0
			agent.ghosted = (iteration + index) % 7 == 0
			agent._has_destination = (iteration + index) % 3 == 0
			agent.velocity = Vector3.ZERO
		var handle: int = runtime.bind_agent(
			candidate_agent, candidate, candidate.type in candidate_agent.VEHICLE_ROLES
		)
		runtime.begin_frame([candidate] + neighbors, get_nodes_in_group("repair_platforms"), true)
		_game.battlefield.invalidate()
		reference_agent._physics_process(delta)
		runtime.step(delta, _game.simulation_time, true)
		var same_control: bool = (
			candidate_agent.velocity.distance_to(reference_agent.velocity) < .0001
		)
		for field in ["_progress_elapsed", "_recovery_left"]:
			same_control = (
				same_control
				and is_equal_approx(candidate_agent.get(field), reference_agent.get(field))
			)
		var safe := Vector3(random.randf_range(-5, 5), 0, random.randf_range(-5, 5))
		if iteration % 23 == 0:
			safe = Vector3.ZERO
		reference_agent._on_velocity_computed(safe)
		runtime.receive_velocity(safe, handle)
		var same_pose: bool = candidate.global_transform.is_equal_approx(reference.global_transform)
		var same_height: bool = (
			absf(candidate_agent.path_height_offset - reference_agent.path_height_offset) < .0001
		)
		if not same_control or not same_pose or not same_height:
			mismatches += 1
			if mismatches <= 8:
				print(
					"NATIVE_MOVEMENT_MISMATCH ",
					iteration,
					" ",
					candidate.type,
					" control=",
					same_control,
					" pose=",
					same_pose,
					" height=",
					same_height,
					" candidate=",
					candidate.position,
					" reference=",
					reference.position,
					" velocity=",
					candidate_agent.velocity,
					" / ",
					reference_agent.velocity
				)
		runtime.unbind_agent(handle)
		var published: Transform3D = candidate.global_transform
		runtime.receive_velocity(Vector3.ONE, handle)
		_check(candidate.global_transform == published, "Stale movement handle changed a unit")
		for unit in [reference, candidate]:
			unit.get_node("Movement").process_mode = Node.PROCESS_MODE_INHERIT
	_check(mismatches == 0, "%d complete native movement comparisons differed" % mismatches)
	var paused_agent = pairs[0][1].get_node("Movement")
	var paused_unit = pairs[0][1]
	paused_agent._synchronized = true
	var paused_handle: int = runtime.bind_agent(paused_agent, paused_unit, true)
	var frozen_pose: Transform3D = paused_unit.global_transform
	paused = true
	runtime.receive_velocity(Vector3.ONE, paused_handle)
	_check(paused_unit.global_transform == frozen_pose, "Native callback moved a paused unit")
	paused = false
	paused_unit.set_meta("garrison_host", neighbors[0])
	runtime.receive_velocity(Vector3.ONE, paused_handle)
	_check(paused_unit.global_transform == frozen_pose, "Native callback moved a garrisoned unit")
	paused_unit.remove_meta("garrison_host")
	runtime.unbind_agent(paused_handle)
	for handle in neighbor_handles:
		runtime.unbind_agent(handle)
	await _close()
	for message in _errors:
		push_error(message)
	print(
		(
			"Native crowd movement: %d failures across 750 complete steering/contact cases"
			% _errors.size()
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _detach_match_runtime(agent):
	if agent._native_runtime == null:
		return
	if agent.velocity_computed.is_connected(agent._native_velocity_callback):
		agent.velocity_computed.disconnect(agent._native_velocity_callback)
	agent._native_runtime.unbind_agent(agent._native_handle)
	agent._native_runtime = null
	agent._native_handle = -1
	agent._native_velocity_callback = Callable()
