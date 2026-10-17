extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	seed(811)
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false})
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var load_start = Time.get_ticks_usec()
	await _skirmish("bastion", "res://source/match/maps/ExpandedAlpineRelay.tscn", true)
	print("FINAL_LOAD_MS ", (Time.get_ticks_usec() - load_start) / 1000.0)
	game.get_node("IsometricCamera3D").set_position_safely(
		_units(game._get_human_player(), "CommandCenter")[0].position
	)
	await _frames(30)
	var started = Time.get_ticks_usec()
	var previous = started
	var simulation = game.simulation_time
	var samples = []
	var previous_pipelines = _pipelines()
	var gpu = 0.0
	var max_units = 0
	var next_report = started + 10000000
	var duration = 15000000 if "--short-capture" in OS.get_cmdline_user_args() else 60000000
	while Time.get_ticks_usec() - started < duration:
		await process_frame
		var now = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		var pipelines = _pipelines()
		if samples[-1] > 50:
			print("PIPELINE_SPIKE previous=", previous_pipelines, " current=", pipelines)
		previous_pipelines = pipelines
		if samples[-1] > 50:
			print(
				"FINAL_SPIKE ",
				JSON.stringify(
					{
						"elapsed_s": (now - started) / 1000000.0,
						"frame_ms": samples[-1],
						"units": get_nodes_in_group("units").size(),
						"gpu_ms":
						RenderingServer.viewport_get_measured_render_time_gpu(
							root.get_viewport_rid()
						),
						"render_cpu_ms":
						RenderingServer.viewport_get_measured_render_time_cpu(
							root.get_viewport_rid()
						),
						"physics_ms":
						Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
						"navigation_ms":
						Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000
					}
				)
			)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		if now >= next_report:
			next_report = now + 10000000
			max_units = maxi(max_units, get_nodes_in_group("units").size())
			print("FINAL_PLAY_PROGRESS ", (now - started) / 1000000.0, " units=", max_units)
	samples.sort()
	var total = samples.reduce(func(a, b): return a + b, 0.0)
	print(
		"FINAL_PLAY ",
		JSON.stringify(
			{
				"mean_ms": total / samples.size(),
				"p95_ms": samples[int(samples.size() * .95)],
				"p99_ms": samples[int(samples.size() * .99)],
				"max_ms": samples[-1],
				"over_100ms": samples.filter(func(t): return t > 100).size(),
				"samples": samples.size(),
				"gpu_ms": gpu / samples.size(),
				"wall_s": total / 1000.0,
				"simulation_s": game.simulation_time - simulation,
				"max_units": max_units
			}
		)
	)
	game.queue_free()
	await _frames(5)
	options.restore(original)
	quit(0)


func _pipelines():
	var values = []
	for kind in range(6, 11):
		values.append(RenderingServer.get_rendering_info(kind))
	return values
