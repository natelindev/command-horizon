extends "res://tests/headless/ContactApproachRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var output = "res://tmp/contact-recovery-trace.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if FileAccess.file_exists(output):
		push_error("Use a fresh trace output")
		quit(2)
		return
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(CONTACT_ARCHIVE))
	_check(loaded.ok, "Contact trace restore failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var worker = restore.entities["unit-0"]
	var movement = worker.get_node("Movement")
	var started = game.simulation_time
	var rows = []
	var collected = -1.0
	paused = false
	for frame in 1200:
		await physics_frame
		if collected < 0 and worker.resource_a > 3:
			collected = game.simulation_time - started
		if frame == 150:
			_work_faces(worker, movement)
		if frame % 15 != 0:
			continue
		var path = movement.get_current_navigation_path()
		var index = movement.get_current_navigation_path_index()
		var next = path[index] if index < path.size() else movement.target_position
		var direction = ((next - worker.position) * Vector3(1, 0, 1)).normalized()
		var neighbors = game.battlefield.nearby_units(worker.position, 5.0)
		var rays = []
		for angle in [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, 3 * PI / 4.0, -3 * PI / 4.0, PI]:
			var candidate = direction.rotated(Vector3.UP, angle)
			var distance = movement._recovery_clearance(candidate)
			var contact = movement._ground_step_contact(
				worker.position, worker.position + candidate * distance, neighbors
			)
			rays.append(
				{"angle": rad_to_deg(angle), "nav": distance, "free": distance * contact.fraction}
			)
		rows.append(
			{
				"seconds": game.simulation_time - started,
				"position": _xyz(worker.position),
				"target": _xyz(movement.target_position),
				"next": _xyz(next),
				"recovery_left": movement._recovery_left,
				"recovery_direction": _xyz(movement._recovery_direction),
				"winner": _xyz(movement._ground_recovery_direction(direction)),
				"rays": rays,
				"cargo": worker.resource_a
			}
		)
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"collected": collected, "samples": rows}, "\t"))
	file.close()
	print("Contact recovery trace: collected=", collected)
	game.queue_free()
	await _frames(5)
	quit(0)


func _xyz(point):
	return [point.x, point.y, point.z]


func _work_faces(worker, movement):
	var target = worker.action._sub_action._target_unit
	var center = target.global_position_yless
	var contact = (
		worker.radius
		+ target.radius
		+ root.get_node("Utils").Match.Unit.Movement.adherence_margin(worker, target)
	)
	var radius = maxf(target.radius, contact - movement.target_desired_distance - .05)
	var blockers = get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit != worker
				and unit.movement_speed > 0
				and unit.movement_domain == worker.movement_domain
			)
	)
	var rows = []
	for index in 32:
		var radial = Vector3(cos(index * TAU / 32), 0, sin(index * TAU / 32))
		var point = (
			NavigationServer3D.map_get_closest_point(
				movement.get_navigation_map(), center + radial * radius
			)
			* Vector3(1, 0, 1)
		)
		var clearance = INF
		for other in blockers:
			clearance = minf(
				clearance,
				point.distance_to(other.global_position_yless) - worker.radius - other.radius
			)
		rows.append(
			{
				"point": _xyz(point),
				"clearance": clearance,
				"distance": point.distance_to(worker.position),
				"near_old_goal": point.distance_to(movement.target_position) < .5
			}
		)
	print(
		"WORK FACES ",
		JSON.stringify(
			{
				"position": _xyz(worker.position),
				"contact": contact,
				"radius": radius,
				"candidates": rows
			}
		)
	)
