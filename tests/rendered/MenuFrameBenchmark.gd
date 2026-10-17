extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var scene = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _measure("menu-cold")
	await _measure("menu-warm")
	quit()


func _measure(label):
	var samples = []
	var last = Time.get_ticks_usec()
	var started = last
	var drawn = Engine.get_frames_drawn()
	while Time.get_ticks_usec() - started < 5000000:
		await process_frame
		var now = Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	samples.sort()
	var result = {
		"mean_ms": samples.reduce(func(a, b): return a + b, 0.0) / samples.size(),
		"p95_ms": samples[int(samples.size() * .95)],
		"p99_ms": samples[int(samples.size() * .99)],
		"max_ms": samples[-1],
		"over_33ms": samples.filter(func(value): return value > 33.34).size(),
		"samples": samples.size(),
		"rendered_frames": Engine.get_frames_drawn() - drawn,
		"resolution": str(root.size),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"vsync": DisplayServer.window_get_vsync_mode(),
	}
	print("PACING ", label, " ", JSON.stringify(result))
