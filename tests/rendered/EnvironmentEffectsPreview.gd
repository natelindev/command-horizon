extends "res://tests/rendered/TerrainLayersPreview.gd"

const EFFECT_OUTPUT = "res://art/environment-effects/"
var measurements = []


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Environment effects preview requires a renderer")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"time_of_day": 0,
			"graphics_dof": false,
			"weather_particles": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUTPUT))
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	var cases = [
		["CoastalFoundryMap", 1, "water"],
		["CoastalFoundry", 1, "legacy-water"],
		["PinebreakValleyMap", 2, "river"],
		["CinderRingMap", 1, "lava"],
		["RedrockDivideMap", 1, "dust"],
		["PinebreakValleyMap", 4, "fog"],
		["VerdantCommonsMap", 2, "clouds"]
	]
	for entry in cases:
		var filters = OS.get_cmdline_user_args()
		if not filters.is_empty() and not Array(filters).any(func(f): return f in entry[2]):
			continue
		var map_path = (
			"res://source/match/maps/%s.tscn"
			% (entry[0] if entry[0] == "CoastalFoundry" else "battlefields/" + entry[0])
		)
		await _skirmish("bastion", map_path)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		await _frames(20)
		paused = true
		options.weather = entry[1]
		var camera = game.get_node("IsometricCamera3D")
		var center = game.map.size / 2.0
		var zoom = 28.0
		if entry[2] in ["water", "lava", "river"]:
			var pools = game.map.layout.water.filter(func(w): return not w.get("ford", false))
			var pool = pools.back() if entry[2] == "lava" else pools.front()
			center = Vector2.ZERO
			for vertex in pool.polygon:
				center += vertex
			center /= pool.polygon.size()
			zoom = 36.0
		if entry[2] == "legacy-water":
			center = Vector2(64, 25)
			zoom = 55.0
		camera.set_size_safely(zoom)
		camera.set_position_safely(Vector3(center.x, 0, center.y))
		game.simulation_time = 37.0
		for level in ["off", "low", "high"]:
			options.graphics_liquids = level != "off"
			options.graphics_clouds = level != "off"
			options.graphics_dust = level != "off"
			options.graphics_fog = level != "off"
			options.environment_quality = int(level == "high")
			options.apply()
			await _frames(45)
			await _shot(entry[2] + "-" + level)
			await _measure(entry[2], level)
		game.simulation_time = 41.0
		game.get_node("WorldAtmosphere")._update(0.0)
		await _shot(entry[2] + "-motion")
		if entry[2] == "river":
			options.graphics_clouds = false
			options.graphics_fog = false
			options.graphics_dust = false
			options.apply()
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(EFFECT_OUTPUT + "flow-frames")
			)
			for frame in 90:
				game.simulation_time = 37.0 + frame / 30.0
				game.get_node("WorldAtmosphere")._update(0.0)
				await _shot("flow-frames/river-%03d" % frame)
		if entry[2] == "clouds":
			for locale in ["en", "zh_CN"]:
				options.language = locale
				options.apply()
				var dialog = root.get_node("Globals").open_settings()
				dialog._tabs.current_tab = 1
				await _shot("graphics-settings-" + locale)
				dialog._finish(false)
		game.queue_free()
		await _frames(5)
		paused = false
	options.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	var report = FileAccess.open(EFFECT_OUTPUT + "performance.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
	for message in errors:
		push_error(message)
	print("Environment effects rendered preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	await _frames(4)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	if pixels != null:
		_check(pixels.save_png(EFFECT_OUTPUT + label + ".png") == OK, "Capture failed")
	print("Captured ", label)


func _measure(label, level):
	var samples = []
	for frame in 90:
		var start = Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	var result = {
		"scene": label,
		"detail": level,
		"median_ms": samples[45],
		"p95_ms": samples[85],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name()
	}
	measurements.append(result)
	print(JSON.stringify(result))
