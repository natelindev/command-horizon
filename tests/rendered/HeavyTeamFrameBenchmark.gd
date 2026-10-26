class_name HeavyTeamPerformanceMainLoop
extends "res://tests/rendered/ScaleFrameBenchmark.gd"

## Native-4K heavy 2v2 workload. Run serially without --headless/--fixed-fps.
## Export through tools/performance/build_benchmark.py for production timings;
## release export templates do not expose the editor's --script entry point.
const TARGET_FPS := 60.0
var _options
var _original_options
var _camera
var _players = []
var _bases = []
var _report = {}
var _output = ""
var _seconds = 8.0
var _mobile_count = 100
var _structure_count = 40
var _resolution = Vector2i(3840, 2160)
var _runtime_log


class RuntimeLog:
	extends Logger
	var messages = []
	var warnings = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		var destination: Array = warnings if _type == Logger.ERROR_TYPE_WARNING else messages
		if destination.size() < 16:
			destination.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if is_instance_valid(current_scene):
		current_scene.free()
		current_scene = null
	if DisplayServer.get_name() == "headless" or "--fixed-fps" in OS.get_cmdline_args():
		push_error("Heavy team measurement requires real-time rendering")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument.begins_with("--seconds="):
			_seconds = argument.trim_prefix("--seconds=").to_float()
		elif argument.begins_with("--mobile="):
			_mobile_count = argument.trim_prefix("--mobile=").to_int()
		elif argument.begins_with("--structures="):
			_structure_count = argument.trim_prefix("--structures=").to_int()
		elif argument.begins_with("--resolution="):
			var parts = argument.trim_prefix("--resolution=").split("x")
			_resolution = Vector2i(parts[0].to_int(), parts[1].to_int())
	_check(_mobile_count > 0 and _mobile_count <= 100, "Invalid mobile population")
	_check(_structure_count > 0 and _structure_count <= 40, "Invalid structure population")
	_check(_seconds >= 4.0, "Samples must cover at least four real seconds")
	_check(_output.is_absolute_path(), "Pass an absolute --output= report path")
	if _checks_failed > 0:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	_options = root.get_node("Globals").options
	_original_options = _options.capture()
	_options.restore(
		{"screen": 1, "edge_scrolling": false, "day_cycle": false, "time_of_day": 0, "weather": 2}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.mode = Window.MODE_WINDOWED
	root.size = _resolution
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = _resolution
	root.scaling_3d_scale = 1.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	seed(20261026)
	_runtime_log = RuntimeLog.new()
	OS.add_logger(_runtime_log)
	_report = {
		"resolution": [_resolution.x, _resolution.y],
		"scale_3d": 1.0,
		"target_fps": TARGET_FPS,
		"target_frame_ms": 1000.0 / TARGET_FPS,
		"mobile_per_player": _mobile_count,
		"structures_per_player": _structure_count,
		"teams": [0, 0, 1, 1],
		"live_commander_ai": true,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"visibility":
		(
			"revealed terrain, observed units"
			if "--reveal-terrain" in OS.get_cmdline_user_args()
			else "per player"
		),
		"release": not OS.has_feature("debug"),
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"graphics": _options.capture(),
		"fixture_note":
		"Elevated fixture HP retains population; real weapons and effects remain active.",
		"phases": []
	}
	await _fixture()
	print("HEAVY_READY ", JSON.stringify(_counts()))
	# Warm shaders, model registration and initial navigation before timing.
	await _warmup(3.0)
	_camera.set_size_safely(45)
	_camera.set_position_safely(Vector3(112, 0, 112))
	_order_movement()
	await _warmup(1.0)
	await _phase("day_movement")
	_interleave_combat()
	await _warmup(3.0)
	await _phase("day_combat")
	_options.time_of_day = 2
	_game.get_node("WorldAtmosphere")._update(0.0)
	await _warmup(1.0)
	await _phase("night_combat")
	_camera.set_size_safely(32)
	_camera.set_position_safely(_bases[0] + Vector3(10, 0, 10))
	await _warmup(1.0)
	await _phase("night_base")
	_camera.set_size_safely(45)
	_camera.set_position_safely(Vector3(112, 0, 112))
	_options.day_cycle = true
	_options.weather = 3
	_game.get_node("WorldAtmosphere")._update(0.0)
	await _warmup(3.0)
	await _phase("cycling_weather_combat")
	OS.remove_logger(_runtime_log)
	_report.engine_errors = _runtime_log.messages
	_report.engine_warnings = _runtime_log.warnings
	_check(_runtime_log.messages.is_empty(), "Runtime errors invalidate the benchmark")
	_report.failures = _checks_failed
	_report.status = "valid" if _checks_failed == 0 else "rejected"
	_report.final_counts = _counts()
	var file = FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()
	print("HEAVY_RESULT ", JSON.stringify({"output": _output, "failures": _checks_failed}))
	_game.queue_free()
	await _frames(8)
	_options.restore(_original_options)
	await root.get_node("Globals").quit_game(0 if _checks_failed == 0 else 1)


func _fixture():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.match_seed = 20261026
	settings.map_path = "res://source/match/maps/battlefields/CopperBadlandsMap.tscn"
	settings.battlefield_events = false
	for index in 4:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = 1 if index == 0 else 2
		side.faction = ["helix", "bastion", "frontier", "frontier"][index]
		side.team = 0 if index < 2 else 1
		side.spawn_index = index
		side.color = root.get_node("Constants").Player.COLORS[index]
		settings.players.append(side)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_camera = _game.get_node("IsometricCamera3D")
	_camera.set_physics_process(false)
	_camera.size_max = 45
	_players = get_nodes_in_group("players")
	paused = true
	for player in _players:
		var hq = player.get_children().filter(func(unit): return unit.get("type") == "CommandCenter")[0]
		_bases.append(hq.global_position)
		player.set_process(false)
	for unit in _game.get_units():
		unit.queue_free()
	await _frames(4)
	var placement = _players[1]
	var navmap = _game.navigation.terrain.navigation_map_rid
	_report.structure_layout = []
	var layout = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/heavy-team-layout.json")
	)
	_check(layout.map == settings.map_path and layout.schema == 1, "Wrong structure layout")
	var replay_layout = not "--rebuild-layout" in OS.get_cmdline_user_args()
	for side in 4:
		var player = _players[side]
		player.resource_a = 10000
		player.resource_b = 10000
		player.coordination_unlocked = true
		for index in _structure_count:
			if index % 10 == 0:
				print("HEAVY_SETUP base=", side, " structures=", index)
			# One runway, with ordinary compact facilities making up the base.
			var roles = [
				"AircraftFactory",
				"CommandLab",
				"RepairDepot",
				"Barracks",
				"PowerPlant",
				"PowerPlant",
				"VehicleFactory",
				"AntiGroundTurret",
				"AntiAirTurret"
			]
			var role = "CommandCenter" if index == 0 else roles[(index - 1) % roles.size()]
			if index > 9 and role == "AircraftFactory":
				role = "PowerPlant"
			var prototype = load(Catalog.scene_path(role)).instantiate()
			var footprint = load("res://source/match/utils/Footprint.gd")
			var site = Transform3D(Basis.IDENTITY, _bases[side])
			if replay_layout:
				var saved = layout.structures[side * 40 + index]
				_check(saved.player == side and saved.role == role, "Wrong structure layout role")
				site = Transform3D(
					Basis(Vector3.UP, saved.yaw),
					Vector3(saved.position[0], saved.position[1], saved.position[2])
				)
				if index > 0:
					var obstacles = _game.get_units() + _game.get_cached_group("resource_units")
					var rules = root.get_node("Utils").Match.Unit.Placement
					var valid = (
						rules.validate_footprint_placement(
							footprint.outline_at(footprint.local_outline(prototype), site),
							obstacles,
							navmap,
							_game.map
						)
						if footprint.has_outline(prototype)
						else rules.validate_agent_placement_position(
							site.origin, prototype.radius, obstacles, navmap, _game.map
						)
					)
					_check(
						valid == rules.VALID, "Saved structure layout is no longer legal: " + role
					)
			elif index > 0:
				site.origin = Vector3.INF
				for offset in [
					Vector3.ZERO, Vector3(20, 0, 12), Vector3(12, 0, 20), Vector3(30, 0, 20)
				]:
					var direction = Vector3(
						1 if _bases[side].x < 112 else -1, 0, 1 if _bases[side].z < 112 else -1
					)
					var origin = _bases[side] + offset * direction
					if footprint.has_outline(prototype):
						site = placement._find_footprint_site(
							origin, footprint.local_outline(prototype), navmap
						)
					else:
						site.origin = placement._find_site(origin, prototype.radius, navmap)
					if site.origin.is_finite():
						break
			prototype.free()
			_check(site.origin.is_finite(), "Could not legally place " + role)
			if not site.origin.is_finite():
				continue
			var structure = _spawn(role, player, site.origin)
			structure.global_basis = site.basis
			_report.structure_layout.append(
				{
					"player": side,
					"role": role,
					"position": [site.origin.x, site.origin.y, site.origin.z],
					"yaw": site.basis.get_euler().y
				}
			)
			# Armor research derives maximum HP from base_hp_max. Keep the fixture
			# population durable after a live commander completes that research too.
			structure.base_hp_max = 1000000
			structure.hp_max = structure.base_hp_max
			structure.hp = structure.hp_max
	# Let all construction footprints publish before any army requests paths.
	paused = false
	await _settle_navigation()
	paused = true
	for side in 4:
		var army = []
		for index in _mobile_count:
			var roles = [
				"Tank",
				"Infantry",
				"RocketInfantry",
				"CombatRobot",
				"Helicopter",
				"RepairRobot",
				"AntiAirVehicle",
				"Infantry",
				"AdvancedTank",
				"Worker"
			]
			var point = Vector3(
				78 + index % 10 * 2.8 + (side % 2) * 38, 0, 68 + index / 10 * 2.8 + (side / 2) * 65
			)
			var unit = _spawn(roles[index % roles.size()], _players[side], point)
			unit.base_hp_max = 100000
			unit.hp_max = unit.base_hp_max
			unit.hp = unit.hp_max
			army.append(unit)
			_start_positions[unit] = unit.global_position
		_armies.append(army)
	_game.simulation_time = 720.0
	if "--reveal-terrain" in OS.get_cmdline_user_args():
		# Legacy comparison fixture: terrain is revealed, but the already active
		# visibility handler still shows units only when the human team observes.
		_game.settings.visibility = settings.Visibility.FULL
		_game.fog_of_war.reveal()
	# Three genuine AI commanders remain enabled at the workload caps.
	for index in range(1, 4):
		_players[index].set_process(true)
	_check(_players[0].is_allied_with(_players[1]), "First team is not allied")
	_check(not _players[0].is_allied_with(_players[2]), "Opposing teams are allied")
	paused = false


func _order_movement():
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	for side in 4:
		for index in _armies[side].size():
			var point = Vector3(
				90 + index % 10 * 2.4 + (side % 2) * 20, 0, 96 + index / 10 * 2.0 + (side / 2) * 12
			)
			behavior.guard(_armies[side][index], point)


func _settle_navigation():
	var deadline = Time.get_ticks_msec() + 60000
	await _frames(4)
	while not _game.navigation.terrain.is_synchronized():
		await process_frame
		if Time.get_ticks_msec() > deadline:
			_check(false, "Navigation did not settle before fixture movement")
			break


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	point = _game.map.ground_point(Vector2(point.x, point.z))
	var movement = unit.get_node_or_null("Movement")
	if (
		movement != null
		and movement.domain == root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	):
		point = _game.navigation.terrain.closest_point(point)
		point.y = _game.map.height_at(Vector2(point.x, point.z))
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _interleave_combat():
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	for side in 4:
		for index in _armies[side].size():
			var unit = _armies[side][index]
			unit.global_position = _game.map.ground_point(
				Vector2(
					85 + (index % 10 * 2 + side % 2) * 2.8, 85 + (index / 10 * 2 + side / 2) * 2.8
				)
			)
			var movement = unit.get_node("Movement")
			movement.stop()
			movement._align_unit_position_to_navigation()
			movement.set_velocity_forced(Vector3.ZERO)
			unit.reset_physics_interpolation()
			behavior.guard(unit, unit.global_position)
	_game.battlefield.invalidate()


func _warmup(seconds):
	var deadline = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await process_frame


func _phase(label):
	print("HEAVY_BEGIN ", label)
	var atmosphere = _game.get_node("WorldAtmosphere")
	var start_hour = atmosphere.hour
	var times = []
	var gpu = []
	var render_cpu = []
	var draws = []
	var primitives = []
	var physics = []
	var navigation = []
	var process = []
	var focused = 0
	var drawn = Engine.get_frames_drawn()
	var simulation = _game.simulation_time
	var positions = {}
	for army in _armies:
		for unit in army:
			positions[unit] = unit.global_position
	var shots = _game.combat_effects.shots_emitted
	var state_begin: Array = (
		_game.unit_state_store.statistics() if _game.unit_state_store != null else []
	)
	var renderer = _game.get_node("UnitBatchRenderer")
	var presentation_begin: Array = (
		renderer._presentation.statistics() if renderer._presentation != null else []
	)
	var roster_queries_begin := 0
	var exploration_begin: Array = (
		_game.battlefield._native_visibility.exploration_statistics()
		if _game.battlefield.native_exploration
		else []
	)
	var combat_begin: Array = (
		_game.battlefield._native_visibility.combat_statistics()
		if _game.battlefield.native_combat_queries
		else []
	)
	var index_begin: Array = (
		_game.battlefield._native_visibility.index_statistics()
		if _game.battlefield.native_battlefield_index
		else []
	)
	for player in _players:
		roster_queries_begin += player.roster_queries
	var profile_begin := _runtime_profile()
	var cpu_begin: Array = (
		_game.runtime_profiler.cpu_sample() if _game.runtime_profiler != null else []
	)
	var start = Time.get_ticks_usec()
	var previous = start
	while Time.get_ticks_usec() - start < _seconds * 1000000.0:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
		focused += 1 if root.has_focus() else 0
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu.append(
			RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		navigation.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var rendered = Engine.get_frames_drawn() - drawn
	var profile_end := _runtime_profile()
	var cpu_end: Array = (
		_game.runtime_profiler.cpu_sample() if _game.runtime_profiler != null else []
	)
	var moving = 0
	var travel = 0.0
	for unit in positions:
		if is_instance_valid(unit):
			var distance = unit.global_position.distance_to(positions[unit])
			travel += distance
			moving += 1 if distance > .1 else 0
	var entry = {
		"phase": label,
		"day_cycle": _options.day_cycle,
		"weather_option": _options.weather,
		"start_hour": start_hour,
		"end_hour": atmosphere.hour,
		"frame_ms": _stats(times),
		"gpu_ms": _stats(gpu),
		"render_cpu_ms": _stats(render_cpu),
		"draw_calls": _stats(draws),
		"primitives": _stats(primitives),
		"sampled_1s_physics_max_ms": _stats(physics),
		"sampled_1s_navigation_max_ms": _stats(navigation),
		"sampled_1s_process_max_ms": _stats(process),
		"navigation_polygons": Performance.get_monitor(Performance.NAVIGATION_3D_POLYGON_COUNT),
		"physics_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"raw_frame_ms": times,
		"focused_samples": focused,
		"samples": times.size(),
		"rendered_frames": rendered,
		"simulation_seconds": _game.simulation_time - simulation,
		"wall_seconds": (Time.get_ticks_usec() - start) / 1000000.0,
		"shots": _game.combat_effects.shots_emitted - shots,
		"moving_units": moving,
		"total_displacement_m": travel,
		"counts": _counts(),
		"runtime_profile_us": _profile_delta(profile_begin, profile_end),
		"cpu_usage": _cpu_usage(cpu_begin, cpu_end, times.size()),
		"pixels": [root.get_texture().get_width(), root.get_texture().get_height()]
	}
	entry.mean_fps = 1000.0 / entry.frame_ms.mean
	entry.real_time_ratio = entry.simulation_seconds / entry.wall_seconds
	entry.frames_over_budget = times.filter(func(ms): return ms > 1000.0 / TARGET_FPS).size()
	_check(rendered >= times.size() - 2, "Frames were not rendered: " + label)
	_check(focused >= times.size() * .99, "Window lost focus: " + label)
	_check(root.get_texture().get_size() == Vector2(_resolution), "Wrong render resolution")
	_check(not _game.finished, "Match ended during sample")
	_check(entry.counts.mobile >= _mobile_count * 4, "Mobile population dropped")
	_check(entry.counts.structures >= _structure_count * 4, "Structure population dropped")
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(entry.counts.native_crowd_runtime, "Requested native runtime is not active")
		var crowd_statistics: Array = entry.counts.native_crowd_statistics
		_check(
			crowd_statistics.size() == 4 and crowd_statistics[1] > 0,
			"Native movement callbacks did not execute"
		)
	if "--native-visibility-runtime" in OS.get_cmdline_user_args():
		_check(entry.counts.native_visibility_runtime, "Requested native visibility is not active")
		var visibility_statistics: Array = entry.counts.native_visibility_statistics
		_check(
			visibility_statistics.size() == 5 and visibility_statistics[1] > 0,
			"Native visibility queries did not execute"
		)
	if (
		"--native-pose-rigs" in OS.get_cmdline_user_args()
		or "--native-presentation" in OS.get_cmdline_user_args()
	):
		_check(entry.counts.native_pose_rigs, "Requested resident pose rigs are not active")
		_check(
			entry.counts.resident_rigs == entry.counts.batched_units,
			"Batched units fell back from resident pose rigs"
		)
		var rig_statistics: Array = entry.counts.native_rig_statistics
		_check(
			rig_statistics.size() == 5 and rig_statistics[1] > 0 and rig_statistics[3] > 0,
			"Resident pose writes/direct packing did not execute"
		)
	if "--native-presentation" in OS.get_cmdline_user_args():
		_check(entry.counts.native_presentation, "Requested native presentation is not active")
		_check(
			entry.counts.native_presentation_units == entry.counts.batched_units,
			"Batched units fell back from native presentation"
		)
		var presentation: Array = entry.counts.native_presentation_statistics
		if presentation.size() == 7 and presentation_begin.size() == 7:
			entry.native_presentation_activity = []
			for index in 7:
				entry.native_presentation_activity.append(
					presentation[index] - presentation_begin[index]
				)
			_check(
				(
					not _expects_runtime_activity("poses")
					or (
						entry.native_presentation_activity[2] > 0
						and entry.native_presentation_activity[4] > 0
					)
				),
				"Native root capture/direct publication did not execute during the sample"
			)
		else:
			_check(false, "Native presentation returned unexpected statistics")
	if "--native-exploration" in OS.get_cmdline_user_args():
		_check(entry.counts.native_exploration, "Requested native exploration is not active")
		var statistics: Array = entry.counts.native_exploration_statistics
		_check(
			(
				not _expects_runtime_activity("exploration")
				or (
					statistics.size() == 3
					and exploration_begin.size() == 3
					and statistics[0] > exploration_begin[0]
					and statistics[1] > exploration_begin[1]
				)
			),
			"Native exploration did not scan cells during the sample"
		)
	if "--native-combat-queries" in OS.get_cmdline_user_args():
		_check(entry.counts.native_combat_queries, "Requested native combat queries are not active")
		var statistics: Array = entry.counts.native_combat_statistics
		_check(
			statistics.size() == 3 and combat_begin.size() == 3 and statistics[1] > combat_begin[1],
			"Native firing queries did not execute during the sample"
		)
	if "--native-battlefield-index" in OS.get_cmdline_user_args():
		_check(entry.counts.native_battlefield_index, "Requested resident index is not active")
		var statistics: Array = entry.counts.native_battlefield_statistics
		_check(
			(
				statistics.size() == 9
				and index_begin.size() == 9
				and statistics[0] == 1
				and statistics[2] >= entry.counts.batched_units
				and statistics[3] > index_begin[3]
				and statistics[5] > index_begin[5]
			),
			"Resident index did not index the army and execute queries during the sample"
		)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(entry.counts.native_unit_state, "Requested native unit store is not active")
		_check(
			entry.counts.native_unit_records == entry.counts.batched_units,
			"Batched units fell back from resident unit state"
		)
		var state: Array = entry.counts.native_unit_statistics
		if state.size() == 9 and state_begin.size() == 9:
			entry.native_unit_activity = []
			for index in 9:
				entry.native_unit_activity.append(state[index] - state_begin[index])
			_check(
				(
					not _expects_runtime_activity("unit_state")
					or (
						entry.native_unit_activity[3] > 0
						and entry.native_unit_activity[4] > 0
						and entry.native_unit_activity[7] > 0
						and entry.native_unit_activity[8] > 0
					)
				),
				"Resident eligibility/speed/direct reads did not execute during the sample"
			)
		else:
			_check(false, "Resident unit store returned unexpected statistics")
	if "--indexed-player-rosters" in OS.get_cmdline_user_args():
		_check(entry.counts.indexed_player_rosters == 4, "Requested player indexes are not active")
		entry.roster_queries_in_sample = entry.counts.roster_queries - roster_queries_begin
		_check(
			not _expects_runtime_activity("rosters") or entry.roster_queries_in_sample > 0,
			"Player indexes did not execute during the sample"
		)
	if "--native-nearest-surface" in OS.get_cmdline_user_args():
		_check(
			entry.counts.native_nearest_surface, "Requested native surface hierarchy is not active"
		)
		var surface: Array = entry.counts.native_surface_statistics
		_check(
			surface.size() == 6 and surface[0] > 0 and surface[2] > 0,
			"Native nearest surface queries did not execute"
		)
	if "--profile-runtime" in OS.get_cmdline_user_args():
		var timings: Dictionary = entry.runtime_profile_us
		_check(
			(
				timings.scene_wall.size() == 4
				and timings.scene_wall[2] > 0
				and timings.scene_wall[3] > 0
			),
			"Full scene dispatch profiling did not execute"
		)
		if OS.has_feature("windows"):
			_check(
				entry.cpu_usage.available and entry.cpu_usage.main_thread_ms > 0,
				"Windows CPU accounting is unavailable"
			)
		_check(
			(
				not _expects_runtime_activity("poses")
				or (timings.poses.size() == 14 and timings.poses[8] > 0)
			),
			"Pose profile did not execute"
		)
		if entry.counts.native_crowd_runtime:
			_check(
				(
					not _expects_runtime_activity("movement")
					or (
						timings.movement.size() == 8
						and timings.movement[5] > 0
						and timings.movement[6] > 0
					)
				),
				"Native movement profile did not execute"
			)
		if entry.counts.native_visibility_runtime:
			_check(
				(
					not _expects_runtime_activity("visibility")
					or (timings.visibility.size() == 10 and timings.visibility[6] > 0)
				),
				"Native visibility profile did not execute"
			)
	if "movement" in label:
		_check(moving >= _mobile_count, "Movement phase did not sustain army movement")
	if "combat" in label:
		_check(entry.shots >= 30, "Combat phase did not sustain firing")
	_report.phases.append(entry)
	var summary = entry.duplicate()
	summary.erase("raw_frame_ms")
	print("HEAVY_PHASE ", JSON.stringify(summary))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_output.get_basename() + "-" + label + ".png")
	var file = FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()


func _expects_runtime_activity(_system: String) -> bool:
	# The production workload always requires activity. Only the explicitly
	# diagnostic ablation subclass overrides this for systems it has stopped.
	return true


func _runtime_profile() -> Dictionary:
	if not "--profile-runtime" in OS.get_cmdline_user_args():
		return {}
	var renderer = _game.get_node_or_null("UnitBatchRenderer")
	var result := {
		"poses": Array(renderer._profile_us) if renderer != null else [],
		"movement":
		(
			_game.crowd_runtime.native.profile(true)
			if _game.crowd_runtime != null and _game.crowd_runtime.active
			else []
		),
		"visibility":
		(
			_game.battlefield._native_visibility.profile(true)
			if _game.battlefield._native_visibility != null
			else []
		),
	}
	if _game.runtime_profiler != null:
		var scene: PackedInt64Array = _game.runtime_profiler.totals
		result.scene_wall = [scene[0], scene[1], scene[4], scene[5]]
		result.scene_cpu = [scene[2], scene[3], scene[4], scene[5]]
	if (
		_game.crowd_runtime != null
		and _game.crowd_runtime.active
		and "--native-nearest-surface" in OS.get_cmdline_user_args()
	):
		var surface: Array = _game.crowd_runtime.native.surface_statistics()
		result.nearest_surface = [surface[5], surface[2]]
	return result


func _cpu_usage(before: Array, after: Array, frames: int) -> Dictionary:
	if before.size() != 4 or after.size() != 4 or before[0] != 1 or after[0] != 1:
		return {"available": false}
	return {
		"available": true,
		"process_ms": (after[1] - before[1]) / 1000.0,
		"main_thread_ms": (after[2] - before[2]) / 1000.0,
		"main_thread_cycles": after[3] - before[3],
		"process_ms_per_frame": (after[1] - before[1]) / 1000.0 / frames,
		"main_thread_ms_per_frame": (after[2] - before[2]) / 1000.0 / frames,
	}


func _profile_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		var values := []
		for index in after[key].size():
			values.append(after[key][index] - before[key][index])
		result[key] = values
	return result


func _counts():
	var structures = 0
	var indexed_players := 0
	var roster_rebuilds := 0
	var roster_queries := 0
	for player in _players:
		structures += player.structure_count()
		indexed_players += int(player.indexed_rosters)
		roster_rebuilds += player.roster_rebuilds
		roster_queries += player.roster_queries
	var renderer = _game.get_node_or_null("UnitBatchRenderer")
	var batches = _game.find_children("*", "MultiMeshInstance3D", true, false).size()
	var batched_units = renderer._units.size() if renderer != null else 0
	var poses = renderer._pose_count if renderer != null else 0
	var active_groups := 0
	var shared_groups := 0
	var maximum_group_size := 0
	var rig_statistics := [0, 0, 0, 0, 0]
	var resident_units := 0
	if renderer != null:
		for entry in renderer._entries:
			resident_units += int(entry.unit.get("_native_state") != null)
			if entry.has("native_rig"):
				var statistics: Array = entry.native_rig.statistics()
				for index in 5:
					rig_statistics[index] += statistics[index]
		for group in renderer._groups.values():
			var members: int = group.entries.size()
			active_groups += 1 if members > 0 else 0
			shared_groups += 1 if members > 1 else 0
			maximum_group_size = maxi(maximum_group_size, members)
	return {
		"mobile": _game.get_units().size() - structures,
		"structures": structures,
		"indexed_player_rosters": indexed_players,
		"roster_rebuilds": roster_rebuilds,
		"roster_queries": roster_queries,
		"batched_units": batched_units,
		"unit_batch_models": renderer._models.size() if renderer != null else 0,
		"active_unit_batch_groups": active_groups,
		"shared_unit_batch_groups": shared_groups,
		"largest_unit_batch": maximum_group_size,
		"render_pose_updates": renderer._render_pose_updates if renderer != null else false,
		"native_infantry_poses": renderer._native_infantry_poses if renderer != null else false,
		"native_infantry_solved": renderer._native_infantry_solved if renderer != null else 0,
		"native_infantry_fallbacks": renderer._native_infantry_fallbacks if renderer != null else 0,
		"native_pose_rigs": renderer._native_pose_rigs if renderer != null else false,
		"resident_rigs": renderer._resident_rigs if renderer != null else 0,
		"native_rig_statistics": rig_statistics,
		"native_presentation": renderer != null and renderer._presentation != null,
		"native_presentation_units":
		renderer._presentation_entries.size() if renderer != null else 0,
		"native_presentation_statistics":
		(
			renderer._presentation.statistics()
			if renderer != null and renderer._presentation != null
			else []
		),
		"native_unit_state": _game.unit_state_store != null,
		"native_unit_records": resident_units,
		"native_unit_statistics":
		_game.unit_state_store.statistics() if _game.unit_state_store != null else [],
		"native_crowd_runtime": _game.crowd_runtime != null and _game.crowd_runtime.active,
		"native_crowd_statistics":
		_game.crowd_runtime.statistics() if _game.crowd_runtime != null else [],
		"native_nearest_surface":
		_game.crowd_runtime != null and _game.crowd_runtime.surface_active,
		"native_surface_statistics":
		(
			_game.crowd_runtime.native.surface_statistics()
			if _game.crowd_runtime != null and _game.crowd_runtime.active
			else []
		),
		"native_terrain_sight": _game.map.terrain.native_sight != null,
		"native_spatial_index": _game.battlefield._native_index_used,
		"native_visibility_runtime": _game.battlefield._native_visibility != null,
		"native_exploration": _game.battlefield.native_exploration,
		"native_combat_queries": _game.battlefield.native_combat_queries,
		"native_battlefield_index": _game.battlefield._resident_index_used,
		"native_battlefield_statistics":
		(
			_game.battlefield._native_visibility.index_statistics()
			if _game.battlefield.native_battlefield_index
			else []
		),
		"native_combat_statistics":
		(
			_game.battlefield._native_visibility.combat_statistics()
			if _game.battlefield.native_combat_queries
			else []
		),
		"native_exploration_statistics":
		(
			_game.battlefield._native_visibility.exploration_statistics()
			if _game.battlefield.native_exploration
			else []
		),
		"native_visibility_statistics":
		(
			_game.battlefield._native_visibility.statistics()
			if _game.battlefield._native_visibility != null
			else []
		),
		"native_terrain_outlines":
		(
			_game.map.terrain.native_sight != null
			and _game.map.terrain.native_sight.has_method("terrain_reveal_triangles")
		),
		"pose_rows": poses,
		"multimesh_nodes": batches,
		"projectiles": _game.projectile_system.round_count()
	}


func _stats(values):
	var sorted = values.duplicate()
	sorted.sort()
	return {
		"mean": _mean(values),
		"p50": sorted[int(sorted.size() * .5)],
		"p95": sorted[mini(sorted.size() - 1, int(sorted.size() * .95))],
		"p99": sorted[mini(sorted.size() - 1, int(sorted.size() * .99))],
		"max": sorted[-1]
	}
