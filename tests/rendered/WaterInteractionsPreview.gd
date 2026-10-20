extends "res://tests/rendered/EnvironmentEffectsPreview.gd"


func _run():
	if DisplayServer.get_name() == "headless":
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
			"weather_particles": false,
			"graphics_clouds": false,
			"graphics_dust": false,
			"graphics_fog": false,
			"environment_quality": 1,
			"graphics_liquids": true
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EFFECT_OUTPUT + "hybrid-frames")
	)
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	await _skirmish("bastion", "res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	paused = true
	var water = game.get_node("WorldAtmosphere").effects.water_interactions
	var camera = game.get_node("IsometricCamera3D")
	var rivers = game.map.layout.water.filter(
		func(w): return w.has("line") and not w.get("ford", false)
	)
	var river = rivers[0]
	var center: Vector2 = river.line[river.line.size() / 2]
	camera.set_size_safely(28)
	camera.set_position_safely(Vector3(center.x, 0, center.y))
	await _tick(water)
	await _frames(5)
	_check(water.gpu != null, "High detail did not allocate compute simulation")
	if water.gpu == null:
		quit(1)
		return
	var steps = water.steps_dispatched
	water.update(game.simulation_time)
	_check(water.steps_dispatched == steps, "Paused clock advanced solver")
	await _shot("hybrid-before")
	# Real combat miss entry point, including its visibility and wetness checks.
	paused = false
	game.combat_effects.miss(
		Vector3(center.x, water._field.level_at(center), center.y), true, true, Color.WHITE
	)
	paused = true
	_check(water._pending.size() > 0, "Actual combat impact did not reach water")
	# Hide the paused combat flash so it cannot be mistaken for water foam.
	game.combat_effects.hide()
	var initial_outer = 0.0
	var capture = "--capture" in OS.get_cmdline_user_args()
	for frame in 90:
		await _tick(water)
		if frame == 0:
			var initial = _energy(water.gpu.texture.get_image())
			initial_outer = _outer_energy(water, center)
			_check(initial > .001, "GPU impulse produced no displacement")
		if frame == 22:
			_check(
				_outer_energy(water, center) > initial_outer * 3.0,
				"Wave energy did not travel beyond the impact"
			)
			await _shot("hybrid-impact")
		if capture:
			await _shot("hybrid-frames/water-%03d" % frame)
	var active_energy = _energy(water.gpu.texture.get_image())
	_check(active_energy > 0.000001, "Ripple did not propagate")
	# Moving-camera reprojection keeps world-space wakes in place.
	var old_origin = water.origin
	camera.set_position_safely(Vector3(center.x + 2.0, 0, center.y))
	await _tick(water)
	_check(water.origin != old_origin, "Local patch did not follow camera")
	_check(_energy(water.gpu.texture.get_image()) > .000001, "Camera scroll erased entire ripple")
	for index in 240:
		await _tick(water)
	_check(_energy(water.gpu.texture.get_image()) < active_energy, "Ripples do not decay")
	# Real unit sampling in a shallow crossing. Stop its movement controller
	# while the test places the body along a deterministic crossing path.
	var tank = _units(game._get_human_player(), "Tank")[0]
	var saved_position = tank.global_position
	center = Vector2(40, 99)
	camera.set_position_safely(Vector3(center.x, 0, center.y))
	await _tick(water)
	water._pending.clear()
	tank.global_position = Vector3(center.x, .0, center.y - 2.0)
	game.battlefield.invalidate()
	water._sample_units()
	tank.position.z += .3
	game.battlefield.invalidate()
	water._sample_units()
	_check(water._pending.size() > 0, "Moving ford unit did not produce a wake")
	for frame in 30:
		tank.position.z += .06
		game.battlefield.invalidate()
		await _tick(water)
	await _shot("hybrid-ford-wake")
	water._pending.clear()
	tank.visible = false
	tank.position.z += .2
	game.battlefield.invalidate()
	water._sample_units()
	_check(water._pending.is_empty(), "Hidden unit produced a wake")
	tank.visible = true
	tank.position.y = 5.0
	game.battlefield.invalidate()
	water._sample_units()
	tank.position.z += .2
	game.battlefield.invalidate()
	water._sample_units()
	_check(water._pending.is_empty(), "Airborne unit produced a water wake")
	tank.global_position = saved_position
	game.battlefield.invalidate()
	# Fixed dispatch/input budgets even after a long frame.
	for index in 100:
		water._queue(center, 1.0, -.1)
	_check(water._pending.size() <= 128, "Unbounded impulse input")
	steps = water.steps_dispatched
	game.simulation_time += 10.0
	water.update(game.simulation_time)
	_check(water.steps_dispatched - steps <= 2, "Solver caught up without a bound")
	await _frames(3)
	for level in ["low", "high"]:
		options.environment_quality = int(level == "high")
		options.apply()
		await _frames(10)
		_check(
			(water.gpu != null) == (level == "high"),
			"Quality setting did not release/recreate GPU resources"
		)
		# Active solver timing, including visible impulses throughout the sample.
		var samples = []
		for frame in 120:
			var started = Time.get_ticks_usec()
			if level == "high" and frame % 6 == 0:
				water._queue(center, 1.0, -.06)
			await _tick(water)
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		measurements.append(
			{
				"scene": "hybrid-active",
				"detail": level,
				"median_ms": samples[60],
				"p95_ms": samples[114],
				"device": RenderingServer.get_video_adapter_name()
			}
		)
	options.graphics_liquids = false
	options.apply()
	_check(water.gpu == null, "Liquid-off retained solver")
	await _frames(5)
	game.queue_free()
	await _frames(10)
	paused = false
	options.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	var report = FileAccess.open(EFFECT_OUTPUT + "hybrid-performance.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
	for message in errors:
		push_error(message)
	print("Hybrid water rendered regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _tick(_water):
	game.simulation_time += 1.0 / 30.0
	game.get_node("WorldAtmosphere")._update(0.0)
	await process_frame
	await RenderingServer.frame_post_draw


func _energy(pixels: Image) -> float:
	_check(pixels != null, "GPU state cannot be inspected")
	if pixels == null:
		return 0.0
	var energy = 0.0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var value = pixels.get_pixel(x, y)
			_check(is_finite(value.r) and absf(value.r) <= .251, "Solver unstable")
			_check(value.a > .5 or is_zero_approx(value.r), "Ripple crossed dry terrain")
			energy += value.r * value.r
	return energy


func _outer_energy(water, center: Vector2) -> float:
	var pixels = water.gpu.texture.get_image()
	var result = 0.0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var point = water.origin + (Vector2(x, y) + Vector2(.5, .5)) * water.CELL
			if point.distance_to(center) > 2.5:
				result += pow(pixels.get_pixel(x, y).r, 2)
	return result
