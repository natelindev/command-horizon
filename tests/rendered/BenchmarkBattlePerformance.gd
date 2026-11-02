extends "res://tests/headless/SaveRestoreEdges.gd"

const COMBATANTS = 200
const SAMPLES = 240
const WARMUP_SECONDS = 3.0
var _rosters
var _report := {}
var _samples := SAMPLES
var _only_faction := ""
var _only_quality := ""
var _output := "user://benchmark-battle/"
var _battle_units: Array = []
var _battle_view := Rect2()
var _first_use_trace = null


func _run():
	if (
		DisplayServer.get_name() == "headless"
		or Array(OS.get_cmdline_args()).any(
			func(argument): return argument.begins_with("--fixed-fps")
		)
	):
		push_error("BenchmarkBattlePerformance requires graphical real-time rendering")
		quit(1)
		return
	_rosters = load("res://source/match/FactionCatalog.gd")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--av-faction="):
			_only_faction = argument.trim_prefix("--av-faction=")
		elif argument.begins_with("--av-quality="):
			_only_quality = argument.trim_prefix("--av-quality=")
		elif argument.begins_with("--av-samples="):
			_samples = clampi(argument.trim_prefix("--av-samples=").to_int(), 60, 3600)
		elif argument.begins_with("--av-output="):
			_output = argument.trim_prefix("--av-output=").trim_suffix("/") + "/"
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("FeatureFlags").handle_match_end = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	var vsync = DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	options.restore(
		{
			"screen": 1,
			"interface_scale": 1.0,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"master_volume": .75,
			"music_volume": .7,
			"effects_volume": .75,
			"voice_volume": .7,
			"ambience_volume": .7,
			"living_world": true,
			"reduced_flashes": false
		}
	)
	root.mode = Window.MODE_WINDOWED
	await _frames(3)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.scaling_3d_scale = 1.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_check(DirAccess.make_dir_recursive_absolute(_output) == OK, "Cannot create AV output folder")
	_report = {
		"adapter": RenderingServer.get_video_adapter_name(),
		"arguments": OS.get_cmdline_user_args(),
		"raster": [1280, 720],
		"release": not OS.has_feature("debug"),
		"combatants": COMBATANTS,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"samples": _samples,
		"quality": [],
		"diagnostic":
		(
			"--av-script-profile" in OS.get_cmdline_user_args()
			or "--trace-combat-first-use" in OS.get_cmdline_user_args()
			or "--av-cold-effects" in OS.get_cmdline_user_args()
		),
		"production_effects_prewarm": not "--av-cold-effects" in OS.get_cmdline_user_args(),
		"fresh_match_per_quality": true,
		"scope":
		"Real live combat and damage presentation; no fixed-fps, paused simulation, or disabled effects."
	}
	for faction in ["bastion", "helix", "frontier"]:
		if not _only_faction.is_empty() and faction != _only_faction:
			continue
		for quality in ["high", "low"]:
			if not _only_quality.is_empty() and quality != _only_quality:
				continue
			var enabled = quality == "high"
			var quality_options: Dictionary = options.capture()
			quality_options.merge(
				{
					"graphics_shadows": enabled,
					"graphics_ao": enabled,
					"graphics_glow": enabled,
					"graphics_fog": enabled,
					"graphics_liquids": enabled,
					"graphics_clouds": enabled,
					"graphics_dust": enabled,
					"graphics_ground_detail": enabled,
					"graphics_msaa": 1 if enabled else 0
				},
				true
			)
			options.restore(quality_options)
			await _battle(faction)
			await _raster()
			await _measure(faction, quality)
			paused = false
			game.queue_free()
			await _frames(8)
	_check(not _report.quality.is_empty(), "AV arguments selected no benchmark phases")
	_report.failures = errors.duplicate()
	_report.status = "valid" if errors.is_empty() and not _report.diagnostic else "diagnostic"
	_write_report()
	options.restore(original)
	DisplayServer.window_set_vsync_mode(vsync)
	for message in errors:
		push_error(message)
	print("Benchmark battle performance: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _battle(faction: String):
	await _skirmish(faction, "res://source/match/maps/ScenarioMap.tscn", false)


func _skirmish(faction, _map_path = "", _advanced = false):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/ScenarioMap.tscn"
	settings.battlefield_events = false
	settings.match_seed = 1631
	var document = load("res://source/scenario/ScenarioDocument.gd").blank()
	document.items = []
	settings.scenario = document
	for side in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = side + 1
		player.color = root.get_node("Constants").Player.COLORS[side]
		player.faction = (
			faction
			if side == 0
			else {"bastion": "helix", "helix": "frontier", "frontier": "bastion"}[faction]
		)
		settings.players.append(player)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	var map = load(settings.map_path).instantiate()
	map.scenario = document
	game.map = map
	root.add_child(game)
	current_scene = game
	_first_use_trace = null
	if "--trace-combat-first-use" in OS.get_cmdline_user_args():
		_first_use_trace = load("res://source/match/effects/CombatFirstUseTrace.gd").new()
		_first_use_trace.game = game
		_first_use_trace.name = "CombatFirstUseTrace"
		game.add_child(_first_use_trace)
	await _frames(60)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
		side.set_physics_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
	await _frames(3)
	var players = get_nodes_in_group("players")
	var armies := [[], []]
	_battle_units.clear()
	for side in 2:
		for index in COMBATANTS / 2:
			var roles = ["Tank", "Infantry", "CombatRobot", "AdvancedTank", "AssaultInfantry"]
			var unit = (
				load(_rosters.scene_path(players[side].faction, roles[index % roles.size()]))
				. instantiate()
			)
			var x = 26 + (index % 10) * 1.8 if side == 0 else 52 + (index % 10) * 1.8
			var point = Vector3(x, 0, 36 + (index / 10) * 2.0)
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), players[side], false)
			unit.hp_max = 1000000.0
			unit.hp = unit.hp_max * .24
			armies[side].append(unit)
			_battle_units.append(unit)
	await _frames(8)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(armies[0][0]._native_state != null, "AV benchmark silently used script unit state")
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			armies[0][0].get_node("Movement")._native_runtime != null,
			"AV benchmark silently used script movement"
		)
	if not "--av-cold-effects" in OS.get_cmdline_user_args():
		_check(
			await load("res://source/match/effects/CombatPrewarm.gd").prepare(game),
			"AV production combat preparation failed"
		)
	var attacking = load("res://source/match/units/actions/AutoAttacking.gd")
	for side in 2:
		for unit in armies[side]:
			var opponents = armies[1 - side]
			var nearest = opponents[0]
			for opponent in opponents:
				if (
					unit.position.distance_squared_to(opponent.position)
					< unit.position.distance_squared_to(nearest.position)
				):
					nearest = opponent
			unit.issue_manual_order(attacking.new(nearest))
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(48, 0, 45))
	camera.set_size_safely(50)
	game.fog_of_war.reveal()
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	for unit in get_nodes_in_group("units"):
		visibility._recalculate_unit_visibility(unit)
	for unit in armies[0]:
		unit.get_node("Selection").select()
	await _frames(8)
	_frame_battle(camera)


func _frame_battle(camera):
	var viewport = root.get_visible_rect().size
	var menus = game.find_child("UnitMenus")
	var minimap = game.find_child("Minimap")
	var bottom = minf(menus.get_global_rect().position.y, minimap.get_global_rect().position.y) - 10
	var top = game.hud.system_plate.get_global_rect().end.y + 10
	if game.hud.ability_tray.visible:
		top = maxf(top, game.hud.ability_tray.get_global_rect().end.y + 10)
	_battle_view = Rect2(Vector2(384, top), Vector2(viewport.x - 400, bottom - top))
	var low = Vector2(INF, INF)
	var high = Vector2(-INF, -INF)
	for unit in _battle_units:
		for height in [0.0, 2.0]:
			var point = camera.global_basis.inverse() * (unit.global_position + Vector3.UP * height)
			low = low.min(Vector2(point.x, point.y) - Vector2.ONE * (unit.radius + 3.5))
			high = high.max(Vector2(point.x, point.y) + Vector2.ONE * (unit.radius + 3.5))
	var extent = high - low
	var size = maxf(extent.x / _battle_view.size.x, extent.y / _battle_view.size.y) * viewport.y
	_check(size <= camera.size_max, "200-unit battle does not fit the legal camera view")
	camera.set_size_safely(size)
	var screen_low = Vector2(INF, INF)
	var screen_high = Vector2(-INF, -INF)
	for unit in _battle_units:
		for height in [0.0, 2.0]:
			var point = camera.unproject_position(unit.global_position + Vector3.UP * height)
			screen_low = screen_low.min(point)
			screen_high = screen_high.max(point)
	var offset = _battle_view.get_center() - (screen_low + screen_high) * .5
	var up = (camera.global_basis.y * Vector3(1, 0, 1)).normalized()
	var scale = camera.size / viewport.y
	var center = camera._calculate_pivot_point()
	center -= camera.global_basis.x * offset.x * scale
	center += up * offset.y * scale / up.dot(camera.global_basis.y)
	camera.set_position_safely(center)
	_check(_visible_combatants() == COMBATANTS, "Battle cohort is obscured by its HUD")


func _visible_combatants() -> int:
	var camera = game.get_node("IsometricCamera3D")
	var pixels = root.get_visible_rect().size.y / camera.size
	var count = 0
	for unit in _battle_units:
		var inner = _battle_view.grow(-unit.radius * pixels)
		if (
			unit.is_visible_in_tree()
			and not camera.is_position_behind(unit.global_position)
			and inner.has_point(camera.unproject_position(unit.global_position))
			and inner.has_point(camera.unproject_position(unit.global_position + Vector3.UP * 2.0))
		):
			count += 1
		else:
			print(
				"AV200_VISIBILITY ",
				unit.type,
				" position=",
				unit.global_position,
				" visible=",
				unit.visible,
				" screen=",
				camera.unproject_position(unit.global_position),
				" bounds=",
				inner
			)
	return count


func _measure(faction: String, quality: String):
	var atmosphere = game.get_node("WorldAtmosphere")
	var high := quality == "high"
	_check(atmosphere.sun.shadow_enabled == high, "AV shadow quality did not apply")
	_check(atmosphere.environment.glow_enabled == high, "AV glow quality did not apply")
	_check(
		(
			atmosphere.environment.ssao_enabled
			== (high and RenderingServer.get_current_rendering_method() == "forward_plus")
		),
		"AV ambient occlusion quality did not apply"
	)
	_check(
		root.msaa_3d == (Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED), "AV MSAA mismatch"
	)
	var warm_until = Time.get_ticks_usec() + int(WARMUP_SECONDS * 1000000)
	var warm_frames := 0
	while Time.get_ticks_usec() < warm_until or warm_frames < 120:
		await RenderingServer.frame_post_draw
		warm_frames += 1
	var script_profile := "--av-script-profile" in OS.get_cmdline_user_args()
	if script_profile:
		_check(EngineDebugger.has_profiler("scripts"), "Script profiling requires --debug")
		EngineDebugger.profiler_enable("scripts", true)
	_frame_battle(game.get_node("IsometricCamera3D"))
	var visible_start = _visible_combatants()
	_check(visible_start == COMBATANTS, "AV phase begins with off-screen combatants")
	print("AV200_BEGIN ", faction, " ", quality)
	var start = Time.get_ticks_usec()
	var last = start
	var simulation_start = game.simulation_time
	var shots = game.projectile_system.rounds_fired
	var times := []
	var draws := []
	var gpu := []
	var render_cpu := []
	var physics := []
	var process := []
	var focused_frames := 0
	var slow_frames := []
	var pipelines_begin := _pipeline_counts()
	var pipelines_previous := pipelines_begin
	var physics_previous := Engine.get_physics_frames()
	var phase_begin := _phase_totals()
	var cpu_begin: Array = (
		game.runtime_profiler.cpu_sample() if game.runtime_profiler != null else []
	)
	for frame in _samples:
		await RenderingServer.frame_post_draw
		if root.has_focus():
			focused_frames += 1
		var now = Time.get_ticks_usec()
		var frame_ms: float = (now - last) / 1000.0
		times.append(frame_ms)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu.append(
			RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var pipelines := _pipeline_counts()
		var physics_now := Engine.get_physics_frames()
		if frame_ms > 100.0:
			var compiled := []
			for index in pipelines.size():
				compiled.append(pipelines[index] - pipelines_previous[index])
			slow_frames.append(
				{
					"frame": frame,
					"wall_ms": frame_ms,
					"usec": now,
					"draw_frame": Engine.get_frames_drawn(),
					"simulation_time": game.simulation_time,
					"simulation_seconds": game.simulation_time - simulation_start,
					"physics_ticks": physics_now - physics_previous,
					"shots": game.projectile_system.rounds_fired - shots,
					"render_cpu_ms": render_cpu.back(),
					"pipeline_compilations": compiled
				}
			)
		pipelines_previous = pipelines
		physics_previous = physics_now
	var wall = (last - start) / 1000000.0
	if script_profile:
		EngineDebugger.profiler_enable("scripts", false)
	var phase_end := _phase_totals()
	var phases := []
	for index in phase_end.size():
		phases.append(phase_end[index] - phase_begin[index])
	var cpu_end: Array = game.runtime_profiler.cpu_sample() if game.runtime_profiler != null else []
	var visible_end = _visible_combatants()
	_check(visible_end == COMBATANTS, "AV phase ends with off-screen combatants")
	if not _report.diagnostic:
		_check(focused_frames == _samples, "AV benchmark lost foreground focus")
	var cpu_usage := {}
	if cpu_begin.size() == 4 and cpu_end.size() == 4 and cpu_begin[0] == 1 and cpu_end[0] == 1:
		cpu_usage = {
			"process_ms_per_frame": (cpu_end[1] - cpu_begin[1]) / 1000.0 / _samples,
			"main_thread_ms_per_frame": (cpu_end[2] - cpu_begin[2]) / 1000.0 / _samples
		}
	_check(
		absf(game.simulation_time - simulation_start - wall) < .2,
		"AV simulation did not run in real time"
	)
	_check(game.projectile_system.rounds_fired > shots, "AV phase had no actual weapons fire")
	_check(
		get_nodes_in_group("selected_units").size() == COMBATANTS / 2, "AV army selection changed"
	)
	_check(game.find_child("UnitMenus").is_visible_in_tree(), "AV battle HUD is hidden")
	_check(
		(
			get_nodes_in_group("units").filter(func(unit): return unit.movement_speed > 0).size()
			== COMBATANTS
		),
		"AV workload did not retain 200 live combatants"
	)
	_check(root.get_texture().get_size() == Vector2(1280, 720), "AV raster changed")
	var pools := {}
	for kind in game.combat_effects._emitters:
		pools[kind] = game.combat_effects._emitters[kind].amount
	var renderer = game.get_node("UnitBatchRenderer")
	if "--native-presentation" in OS.get_cmdline_user_args():
		_check(
			renderer._presentation != null and renderer._resident_rigs == renderer._units.size(),
			"AV benchmark silently used script presentation"
		)
	if "--native-combat-queries" in OS.get_cmdline_user_args():
		_check(game.battlefield.native_combat_queries, "AV native combat queries did not activate")
	if "--native-exploration" in OS.get_cmdline_user_args():
		_check(game.battlefield.native_exploration, "AV native exploration did not activate")
	if "--native-battlefield-index" in OS.get_cmdline_user_args():
		_check(game.battlefield.native_battlefield_index, "AV native index did not activate")
	if "--native-visibility-runtime" in OS.get_cmdline_user_args():
		_check(game.battlefield._native_visibility != null, "AV native visibility did not activate")
	if "--native-infantry-poses" in OS.get_cmdline_user_args():
		_check(renderer._native_infantry_solved > 0, "AV native infantry poses did not execute")
	var entry = {
		"faction": faction,
		"quality": quality,
		"frames": times.size(),
		"focused_frames": focused_frames,
		"selected_units": get_nodes_in_group("selected_units").size(),
		"visible_start": visible_start,
		"visible_end": visible_end,
		"frame_ms": _statistics(times),
		"gpu_ms": _statistics(gpu),
		"gpu_timing_available": gpu.any(func(value): return value > 0.0),
		"render_cpu_ms": _statistics(render_cpu),
		"sampled_1s_physics_max_ms": _statistics(physics),
		"sampled_1s_process_max_ms": _statistics(process),
		"scene_dispatch_us": phases,
		"cpu_usage": cpu_usage,
		"slow_frames_over_100ms": slow_frames,
		"pipeline_counts_begin": pipelines_begin,
		"pipeline_counts_end": pipelines_previous,
		"pipeline_count_order": ["canvas", "mesh", "surface", "draw", "specialization"],
		"first_use_events":
		_first_use_trace.events.duplicate(true) if _first_use_trace != null else [],
		"batched_units": renderer._units.size(),
		"resident_rigs": renderer._resident_rigs,
		"native_infantry_solves": renderer._native_infantry_solved,
		"batch_groups": renderer._groups.size(),
		"native_visibility": game.battlefield._native_visibility != null,
		"native_combat_queries": game.battlefield.native_combat_queries,
		"native_exploration": game.battlefield.native_exploration,
		"native_battlefield_index": game.battlefield.native_battlefield_index,
		"raster": [root.get_texture().get_size().x, root.get_texture().get_size().y],
		"draw_calls": _statistics(draws),
		"wall_seconds": wall,
		"wall_start_usec": start,
		"simulation_start": simulation_start,
		"simulation_seconds": game.simulation_time - simulation_start,
		"shots": game.projectile_system.rounds_fired - shots,
		"music_intensity": root.get_node("MusicDirector").intensity,
		"particle_capacities": pools,
		"shocks": game.combat_effects._shockwaves.size()
	}
	_report.quality.append(entry)
	_write_report()
	print("AV200 ", JSON.stringify(entry))
	RenderingServer.force_draw(false)
	_check(
		root.get_texture().get_image().save_png(_output + faction + "-" + quality + ".png") == OK,
		"Cannot save AV capture"
	)


func _raster():
	root.mode = Window.MODE_WINDOWED
	await _frames(3)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_move_to_foreground()
	await _frames(12)
	_check(root.get_texture().get_size() == Vector2(1280, 720), "AV raster initialization failed")


func _phase_totals() -> Array:
	return Array(game.runtime_profiler.totals) if game.runtime_profiler != null else []


func _pipeline_counts() -> Array:
	var counts := []
	for monitor in [
		Performance.PIPELINE_COMPILATIONS_CANVAS,
		Performance.PIPELINE_COMPILATIONS_MESH,
		Performance.PIPELINE_COMPILATIONS_SURFACE,
		Performance.PIPELINE_COMPILATIONS_DRAW,
		Performance.PIPELINE_COMPILATIONS_SPECIALIZATION
	]:
		counts.append(int(Performance.get_monitor(monitor)))
	return counts


func _write_report():
	var file = FileAccess.open(_output + "performance.json", FileAccess.WRITE)
	if file == null:
		_check(false, "Cannot save AV report")
		return
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()


func _statistics(values: Array) -> Dictionary:
	values.sort()
	var total: float = values.reduce(func(sum, value): return sum + value, 0.0)
	return {
		"mean": total / values.size(),
		"median": values[values.size() / 2],
		"p95": values[int(values.size() * .95)],
		"max": values[-1]
	}
