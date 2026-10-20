extends "res://tests/headless/BattlePolishRegression.gd"


func _run():
	if (
		DisplayServer.get_name() == "headless"
		or Array(OS.get_cmdline_args()).any(func(arg): return arg.begins_with("--fixed-fps"))
		or "--disable-render-loop" in OS.get_cmdline_args()
	):
		push_error("BattleFrameBenchmark requires graphical, real-time rendering")
		quit(1)
		return
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Optional: -- --map=res://path.tscn --center=x,z (defaults: Expanded Desert Frontier).
	var map_path = "res://source/match/maps/battlefields/DesertFrontierMap.tscn"
	var center = Vector3(96, 0, 72)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			map_path = argument.trim_prefix("--map=")
		elif argument.begins_with("--center="):
			var parts = argument.trim_prefix("--center=").split(",")
			center = Vector3(float(parts[0]), 0, float(parts[1]))
	await _skirmish("helix", map_path)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(_units(game._get_human_player(), "CommandCenter")[0].position)
	camera.set_size_safely(28)
	await _measure_frames("base")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for player in get_nodes_in_group("players"):
		for index in 20:
			var role = ["Tank", "Infantry", "CombatRobot", "Helicopter"][index % 4]
			var unit = load(factions.Bastion.scene_path(role)).instantiate()
			var point = (
				center
				+ Vector3(
					(-6 if player == game._get_human_player() else 6) + (index % 4 - 2),
					0,
					(index / 4 - 2) * 2
				)
			)
			unit.hp_max = 100000
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
			unit.hp_max = 100000
			unit.hp = unit.hp_max
	camera.set_position_safely(center)
	camera.set_size_safely(34)
	await _measure_frames("midfield-combat")
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _measure_frames(label):
	# Update ticks can run without a draw (e.g. native window transitions).
	# Warm both the renderer and real-time simulation before sampling draws.
	var warm_until = Time.get_ticks_msec() + 3000
	for frame in 120:
		await RenderingServer.frame_post_draw
	while Time.get_ticks_msec() < warm_until:
		await RenderingServer.frame_post_draw
	var times = []
	var gpu_ms = 0.0
	var render_cpu_ms = 0.0
	var last = Time.get_ticks_usec()
	var started = game.simulation_time
	var drawn = Engine.get_frames_drawn()
	var physics_started = Engine.get_physics_frames()
	for frame in 240:
		await RenderingServer.frame_post_draw
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(
			root.get_viewport_rid()
		)
		last = now
	times.sort()
	var mean = times.reduce(func(total, sample): return total + sample, 0.0) / times.size()
	_check(
		Engine.get_frames_drawn() - drawn == times.size(),
		"Benchmark window did not render every sample"
	)
	# A fast machine can render all samples in under a second.
	_check(
		(
			absf((game.simulation_time - started) - mean * times.size() / 1000.0) < 0.15
			and Engine.get_physics_frames() > physics_started
		),
		"Benchmark simulation did not advance in real time"
	)
	print(
		"GAMEPLAY ",
		label,
		" units=",
		get_nodes_in_group("units").size(),
		" mean_ms=",
		snappedf(mean, .01),
		" p95_ms=",
		snappedf(times[int(times.size() * .95)], .01),
		" fps=",
		snappedf(1000.0 / mean, .1),
		" simulation_seconds=",
		game.simulation_time - started,
		" wall_seconds=",
		mean * times.size() / 1000.0,
		" viewport=",
		root.get_visible_rect().size,
		" pixels=",
		root.get_texture().get_size(),
		" gpu_ms=",
		snappedf(gpu_ms / times.size(), .01) if gpu_ms > 0.0 else "unavailable",
		" render_cpu_ms=",
		snappedf(render_cpu_ms / times.size(), .01),
		" adapter=",
		RenderingServer.get_video_adapter_name(),
		" rendered_frames=",
		Engine.get_frames_drawn() - drawn,
		" physics_ticks=",
		Engine.get_physics_frames() - physics_started,
		" paused=",
		paused,
		" draw_calls=",
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		" primitives=",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	)
