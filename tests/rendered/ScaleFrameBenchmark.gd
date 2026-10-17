extends "res://tests/headless/ScaleBenchmark.gd"

# Run without --fixed-fps, with -- --behaviors --realtime --no-capture.
var _gpu_samples = []
var _render_cpu_samples = []


func _run():
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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


func _sample_render():
	_gpu_samples.append(
		RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	)
	_render_cpu_samples.append(
		RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	)


func _mean(samples):
	return samples.reduce(func(total, value): return total + value, 0.0) / maxi(1, samples.size())
