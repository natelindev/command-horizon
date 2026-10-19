extends "res://tests/headless/ScaleBenchmark.gd"

# Run without --fixed-fps, with -- --behaviors --realtime --no-capture.
var _gpu_samples = []
var _render_cpu_samples = []


func _run():
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Keep the measured viewport at 1920x1080 even if Windows resizes the window.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print(
		"BENCHMARK avoidance_threads=",
		ProjectSettings.get_setting_with_override(
			"navigation/avoidance/thread_model/avoidance_use_multiple_threads"
		)
	)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await super()


func _measure(label, frames):
	# Diagnostic runs retain gameplay and animation, changing only raster resolution.
	root.scaling_3d_scale = (
		.5 if "--diagnostic-half-resolution" in OS.get_cmdline_user_args() else 1.0
	)
	var drawn = Engine.get_frames_drawn()
	_gpu_samples.clear()
	_render_cpu_samples.clear()
	process_frame.connect(_sample_render)
	await super(label, frames)
	process_frame.disconnect(_sample_render)
	if Engine.get_frames_drawn() - drawn < _gpu_samples.size() - 10:
		push_error("Scale benchmark window did not render its samples")
		quit(1)
	print(
		"RENDER ",
		label,
		" gpu_ms=",
		snappedf(_mean(_gpu_samples), .01),
		" render_cpu_ms=",
		snappedf(_mean(_render_cpu_samples), .01),
		" pixels=",
		root.get_texture().get_size(),
		" scale_3d=",
		root.scaling_3d_scale,
		" adapter=",
		RenderingServer.get_video_adapter_name(),
		" rendered_frames=",
		Engine.get_frames_drawn() - drawn
	)
	print(
		"TAIL ",
		label,
		" max_frame_ms=",
		snappedf(_frame_times[-1], .01),
		" frames_over_100ms=",
		_frame_times.filter(func(ms): return ms > 100.0).size()
	)
	if label == "combat" and "--input-latency" in OS.get_cmdline_user_args():
		await _input_probe()


func _input_probe():
	# Run after the matched combat sample so input probes cannot change its load.
	# This measures engine event dispatch to frame submission, not mouse hardware
	# or display scan-out latency.
	var hud = _game.hud
	var feedback = hud.command_feedback
	var camera = _game.get_node("IsometricCamera3D")
	hud.select_units(_armies[0].slice(0, 24))
	await _frames(3)
	var samples = []
	for index in 10:
		feedback.markers.clear()
		hud.direct_orders.arm("move")
		var point = camera.unproject_position(Vector3(40 + index % 2, 0, 45))
		point = root.get_final_transform() * point
		var motion = InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, false)
		await process_frame
		var started = Time.get_ticks_usec()
		for pressed in [true, false]:
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = point
			click.global_position = point
			click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			root.push_input(click, false)
		await RenderingServer.frame_post_draw
		if feedback.markers.is_empty():
			await RenderingServer.frame_post_draw
		if feedback.markers.is_empty() or not feedback.markers[-1].accepted:
			push_error("Maximum-population input probe did not acknowledge a move")
			quit(1)
			return
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		await _frames(3)
	samples.sort()
	print(
		"INPUT selected=24 samples=10 event_to_feedback_submit_mean_ms=",
		snappedf(_mean(samples), .01),
		" p95_ms=",
		snappedf(samples[9], .01),
		" maximum_population=true"
	)


func _sample_render():
	_gpu_samples.append(
		RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	)
	_render_cpu_samples.append(
		RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	)


func _mean(samples):
	return samples.reduce(func(total, value): return total + value, 0.0) / maxi(1, samples.size())
