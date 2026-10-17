extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	seed(2471)
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _skirmish("bastion", "res://source/match/maps/BigArena.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(5)
	var human = game._get_human_player()
	var target = _units(human, "CommandCenter")[0]
	var center = target.global_position
	var workers = []
	var worker_scene = load("res://source/match/units/Worker.tscn")
	for index in 30:
		var point = (
			center + Vector3(target.radius + 1.4 + (index / 10) * 1.5, 0, (index % 10 - 4.5) * 1.5)
		)
		var worker = worker_scene.instantiate()
		game._setup_and_spawn_unit(worker, Transform3D(Basis(), point), human, false)
		workers.append(worker)
	await _frames(20)
	for worker in workers:
		worker.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		worker.process_mode = Node.PROCESS_MODE_DISABLED
	var carrier = worker_scene.instantiate()
	game._setup_and_spawn_unit(
		carrier, Transform3D(Basis(), center + Vector3(target.radius + 6.5, 0, 0)), human, false
	)
	game.get_node("IsometricCamera3D").set_position_safely(center)
	await _frames(30)
	var script = load("res://source/match/units/actions/MovingToUnit.gd")
	var arguments = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		script = load(arguments[0])
	var samples = []
	var gpu = 0.0
	var previous = Time.get_ticks_usec()
	var started = previous
	var simulation = game.simulation_time
	carrier.issue_manual_order(script.new(target))
	var arrived = false
	while Time.get_ticks_usec() - started < 15000000:
		await process_frame
		var now = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		arrived = (
			arrived or root.get_node("Utils").Match.Unit.Movement.units_adhere(carrier, target)
		)
	samples.sort()
	var total = samples.reduce(func(a, b): return a + b, 0.0)
	var result = {
		"samples": samples.size(),
		"mean_ms": total / samples.size(),
		"p95_ms": samples[int(samples.size() * .95)],
		"p99_ms": samples[int(samples.size() * .99)],
		"max_ms": samples[-1],
		"over_100ms": samples.filter(func(t): return t > 100).size(),
		"gpu_ms": gpu / samples.size(),
		"simulation_s": game.simulation_time - simulation,
		"wall_s": total / 1000.0,
		"arrived": arrived,
		"script": script.resource_path
	}
	print("WORKER_RETURN ", JSON.stringify(result))
	_check(arrived, "Worker did not reach the HQ through the crowded approach")
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	quit(0 if errors.is_empty() else 1)
