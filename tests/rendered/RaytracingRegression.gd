extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	var profile = load("res://source/data-model/HardwareProfile.gd")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false

	var detected: Dictionary = profile.detect()
	if not detected.supports_raytracing:
		print(
			(
				"Raytracing regression: skipped (adapter '%s', method '%s' has no Vulkan RT pipeline)"
				% [detected.adapter_name, detected.rendering_method]
			)
		)
		preferences.restore(original)
		await root.get_node("Globals").quit_game(0)
		return

	# Configure Ultra preset at windowed 1080p for deterministic verification.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	preferences.apply_preset(profile.Tier.ULTRA)
	preferences.screen = preferences.Screen.WINDOW
	preferences.day_cycle = false
	preferences.time_of_day = 2
	preferences.weather = 3
	preferences.edge_scrolling = false
	preferences.apply()

	# 1. Verify opaque RTGI + glossy rain-puddle RT Reflections and Fog of War shroud safety.
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var atmosphere = game.get_node("WorldAtmosphere")
	var rt = atmosphere.rt_system
	_check(rt != null, "WorldAtmosphere did not initialize rt_system on RT-capable GPU")
	_check(rt != null and rt.active, "rt_system was not active under Ultra preset")
	_check(
		atmosphere.environment.tonemap_mode == Environment.TONE_MAPPER_AGX,
		"Ultra preset did not enable AgX tonemapping"
	)
	_check(
		not atmosphere.environment.ssil_enabled and not atmosphere.environment.sdfgi_enabled,
		"Fallback GI stayed enabled while hardware RTGI was active"
	)
	_check(
		not atmosphere.environment.ssr_enabled,
		"Fallback SSR stayed enabled while hardware RT Reflections were active"
	)

	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 190
	camera.set_size_safely(36)
	camera.set_position_safely(Vector3(114, 0, 54))
	await _frames(15)
	var shroud_pt = root.get_final_transform() * camera.unproject_position(Vector3(114, 0, 54))
	var shroud_px_rt = root.get_texture().get_image().get_pixelv(Vector2i(shroud_pt))
	preferences.graphics_rt_gi = false
	preferences.graphics_reflections = 0
	preferences.apply()
	await _frames(8)
	var shroud_px_off = root.get_texture().get_image().get_pixelv(Vector2i(shroud_pt))
	_check(
		(
			absf(shroud_px_rt.r - shroud_px_off.r) < 0.015
			and absf(shroud_px_rt.g - shroud_px_off.g) < 0.015
			and absf(shroud_px_rt.b - shroud_px_off.b) < 0.015
		),
		(
			"Hardware RT leaked illumination into unexplored Fog of War shroud (%s vs %s)"
			% [str(shroud_px_rt), str(shroud_px_off)]
		)
	)
	preferences.graphics_rt_gi = true
	preferences.graphics_reflections = 2
	preferences.apply()
	await _frames(10)
	game.queue_free()
	await _frames(6)

	# 2. Verify authored water RT reflections, live RT quality switching, and >=60 FPS target.
	preferences.time_of_day = 1
	preferences.weather = 1
	preferences.apply()
	await _skirmish("bastion", "res://source/match/maps/battlefields/FourRiversMap.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var river_cam = game.get_node("IsometricCamera3D")
	river_cam.size_max = 190
	river_cam.set_size_safely(60)
	river_cam.set_position_safely(Vector3(64, 0, 64))
	await _frames(20)
	var river_atmo = game.get_node("WorldAtmosphere")
	var river_rt = river_atmo.rt_system
	_check(
		river_rt != null and river_rt.has_water_reflections(),
		"FourRivers authored water did not activate hardware RT water reflections"
	)

	# Switch live across Balanced (0), Ultra (2), and back to High (1) to verify safe RID retirement.
	for q in [0, 2, 1]:
		preferences.graphics_rt_quality = q
		preferences.apply()
		await _frames(10)
	_check(
		river_rt != null and river_rt.active and river_rt.has_water_reflections(),
		"RT pipeline failed to stay active after live quality switches"
	)

	# Measure sustained 1080p Ultra frame rate on the RT-capable GPU.
	var t0 = Time.get_ticks_usec()
	await _frames(45)
	var elapsed_sec = float(Time.get_ticks_usec() - t0) / 1000000.0
	var avg_fps = 45.0 / maxf(0.001, elapsed_sec)
	print("Raytracing regression: 1080p Ultra FourRivers avg %.1f FPS" % avg_fps)
	_check(avg_fps >= 60.0, "1080p Ultra RT dropped below 60 FPS (%.1f FPS)" % avg_fps)

	game.queue_free()
	await _frames(6)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Raytracing regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
