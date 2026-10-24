extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")

var _behaviors = "--behaviors" in OS.get_cmdline_user_args()
var _air_combat = "--air-combat" in OS.get_cmdline_user_args()
var _no_capture = "--no-capture" in OS.get_cmdline_user_args()
var _no_motion = "--diagnostic-no-motion" in OS.get_cmdline_user_args()
var _no_queues = "--diagnostic-no-queues" in OS.get_cmdline_user_args()
var _baseline_field = "--baseline-field" in OS.get_cmdline_user_args()
var _baseline_targets = "--baseline-targets" in OS.get_cmdline_user_args()
var _realtime = "--realtime" in OS.get_cmdline_user_args()
var _profile_field = "--profile-field" in OS.get_cmdline_user_args()
var _game
var _armies = []
var _frame_times = []
var _checks_failed = 0
var _peak_projectiles = 0
var _peak_tracers = 0
var _start_positions = {}
var _travel = {}
var _last_positions = {}


func _initialize():
	call_deferred("_run")


func _run():
	_check(
		not _realtime or "--fixed-fps" not in OS.get_cmdline_args(),
		"Realtime measurement cannot use --fixed-fps"
	)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	var constants = root.get_node("Constants")
	var behaviors = load("res://source/match/orders/UnitBehavior.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if index == 0 else "helix"
		player.color = Color.GOLD if index == 0 else Color.CYAN
		player.spawn_index_offset = 3 if index == 1 else 0
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_check(
		int(_baseline_field) + int(_profile_field) + int(_baseline_targets) <= 1,
		"Reference field and timing wrapper are separate runs"
	)
	if _baseline_field:
		_game.battlefield.set_script(load("res://tests/headless/ScaleFieldBaseline.gd"))
	elif _profile_field:
		_game.battlefield.set_script(load("res://tests/headless/ScaleFieldProbe.gd"))
	elif _baseline_targets:
		_game.battlefield.set_script(load("res://tests/headless/ScaleTargetBaseline.gd"))
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 110
	camera.set_size_safely(100)
	camera.set_position_safely(Vector3(50, 0, 50))
	var players = get_nodes_in_group("players")
	players[1].set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.queue_free()
	for side in range(2):
		var player = players[side]
		var army = []
		for index in range(40):
			var roles = ["PowerPlant", "VehicleFactory", "Barracks", "RepairDepot"]
			if _behaviors:
				roles.append("CommandLab")
			var role = "CommandCenter" if index == 0 else roles[index % roles.size()]
			_spawn(
				role,
				player,
				Vector3((5 if side == 0 else 80) + (index % 4) * 5, 0, 5 + (index / 4) * 10)
			)
		for index in range(100):
			var roles = ["Tank", "Infantry", "CombatRobot", "Helicopter", "RepairRobot"]
			if _behaviors:
				roles[1] = "Drone"
			if _air_combat:
				roles.append_array(["AntiAirVehicle", "Fighter", "Bomber"])
			var point = Vector3(
				(30 + (index % 5) * 2) if side == 0 else (70 - (index % 5) * 2),
				0,
				6 + (index / 5) * 4.5
			)
			var unit = _spawn(roles[index % roles.size()], player, point)
			# Keep the full population alive throughout measurement. Real weapons/effects
			# and movement still run; this scenario is not a balance measurement.
			unit.hp_max = 100000.0
			unit.hp = unit.hp_max
			if _air_combat and "unlimited_stores" in unit:
				unit.unlimited_stores = true
			army.append(unit)
		_armies.append(army)
	if _no_motion or _no_queues:
		print("DIAGNOSTIC ablation: no_motion=", _no_motion, " no_idle_queues=", _no_queues)
		for unit in get_nodes_in_group("units"):
			if _no_motion:
				var visual = unit.get_node_or_null("BastionVisuals")
				if visual != null:
					visual.set_process(false)
			if _no_queues:
				var queue = unit.get_node_or_null("ProductionQueue")
				if queue != null:
					_check(queue.size() == 0)
					queue.set_process(false)
	await _frames(180)
	_check(players[0].population() == 100 and players[1].population() == 100)
	var factions = load("res://source/match/FactionCatalog.gd")
	for player in players:
		_check(player.structure_count() == 40)
		_check(not factions.available(player, "PowerPlant", true), "Structure cap bypassed")
	var placement = players[0].get_node("StructurePlacementHandler")
	placement._start_structure_placement(load(Catalog.scene_path("PowerPlant")))
	_check(
		(
			placement._calculate_blueprint_position_validity()
			== placement.BlueprintPositionValidity.STRUCTURE_LIMIT
		)
	)
	var funds_before = players[0].resource_a
	placement._finish_structure_placement()
	_check(players[0].structure_count() == 40 and players[0].resource_a == funds_before)
	for side in range(2):
		for index in range(100):
			var unit = _armies[side][index]
			_start_positions[unit] = unit.global_position
			var point = Vector3(46 if side == 0 else 54, 0, 6 + (index / 5) * 4.5)
			if _behaviors:
				behaviors.guard(unit, point)
			else:
				unit.action = load("res://source/match/units/actions/Moving.gd").new(point)
	await _measure("movement", 600)
	var travelled = _travel.values().filter(func(distance): return distance > 2.0).size()
	_check(travelled >= 190, "Too many units failed to travel under load")
	var moved = 0
	for unit in _start_positions:
		if unit.global_position.distance_to(_start_positions[unit]) > 2.0:
			moved += 1
	_check(moved >= 190, "Too many units failed to move under load")
	for side in range(2):
		for unit in _armies[side]:
			if _behaviors:
				behaviors.guard(unit, Vector3(50, 0, unit.global_position.z))
			elif unit.attack_range != null:
				unit.action = load("res://source/match/units/actions/AttackMoving.gd").new(
					Vector3(55 if side == 0 else 45, 0, unit.global_position.z)
				)
	await _measure("combat", 600)
	var fired = 0
	for unit in _start_positions:
		if unit.has_meta("next_attack_availability_time"):
			fired += 1
	_check(fired >= 80, "Benchmark did not exercise enough weapons")
	print(
		"SCALE behaviors=",
		_behaviors,
		" air_combat=",
		_air_combat,
		" moved=",
		moved,
		"/200 travelled=",
		travelled,
		"/200 fired=",
		fired,
		" peak_live_projectiles=",
		_peak_projectiles,
		" resources=",
		get_nodes_in_group("resource_units").size(),
		" sampled_peak_tracers=",
		_peak_tracers,
		" viewport_pixels=",
		root.get_texture().get_size()
	)
	if DisplayServer.get_name() != "headless" and not (_no_motion or _no_queues or _no_capture):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/skirmish/scale-200.png")
	_game.queue_free()
	await _frames(8)
	print(
		"PASS" if _checks_failed == 0 else "FAIL",
		": 200 mobile units + 80 structures; behaviors=",
		_behaviors,
		" release=",
		not OS.has_feature("debug"),
		" failures=",
		_checks_failed
	)
	await root.get_node("Globals").quit_game(0 if _checks_failed == 0 else 1)


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _measure(label, frames):
	print("SCALE BEGIN ", label, " paused=", paused, " simulation_time=", _game.simulation_time)
	if _profile_field:
		_game.battlefield.timings.clear()
	_frame_times.clear()
	if label == "movement":
		_last_positions = _start_positions.duplicate()
		for unit in _start_positions:
			_travel[unit] = 0.0
	var last = Time.get_ticks_usec()
	var started = last
	var simulation_started = _game.simulation_time
	var physics_started = Engine.get_physics_frames()
	var process_max_sum_ms = 0.0
	var physics_max_sum_ms = 0.0
	var index = 0
	while (
		_game.simulation_time - simulation_started < frames / 60.0 if _realtime else index < frames
	):
		await process_frame
		var now = Time.get_ticks_usec()
		_frame_times.append((now - last) / 1000.0)
		# These engine monitors publish one-second maxima, held between updates.
		# Averaging their sampled values is diagnostic, not mean per-frame work.
		process_max_sum_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000
		physics_max_sum_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
		last = now
		if label == "movement":
			for unit in _last_positions:
				_travel[unit] += unit.global_position.distance_to(_last_positions[unit])
				_last_positions[unit] = unit.global_position
		if index % 30 == 0:
			_peak_projectiles = maxi(_peak_projectiles, _game.projectile_system.round_count())
			_peak_tracers = maxi(_peak_tracers, _game.combat_effects._tracers.size())
		index += 1
		if (Time.get_ticks_usec() - started) > 60000000:
			push_error(
				(
					"Scale benchmark exceeded 60 wall seconds: paused=%s simulation=%s frames=%s"
					% [paused, _game.simulation_time, index]
				)
			)
			quit(1)
			return
	if _profile_field:
		print("FIELD PROFILE ", label, " ", JSON.stringify(_game.battlefield.timings))
	_frame_times.sort()
	var mean = (
		_frame_times.reduce(func(total, sample): return total + sample, 0.0) / _frame_times.size()
	)
	print(
		"SCALE ",
		label,
		" renderer=",
		DisplayServer.get_name(),
		" mean_frame_ms=",
		snappedf(mean, 0.01),
		" p95_frame_ms=",
		snappedf(_frame_times[int(_frame_times.size() * 0.95)], 0.01),
		" p99_frame_ms=",
		snappedf(_frame_times[int(_frame_times.size() * 0.99)], 0.01),
		" frames_over_33ms=",
		_frame_times.filter(func(ms): return ms > 1000.0 / 30.0).size(),
		" samples=",
		_frame_times.size(),
		" simulation_seconds=",
		snappedf(_game.simulation_time - simulation_started, 0.01),
		" wall_seconds=",
		snappedf((Time.get_ticks_usec() - started) / 1000000.0, 0.01),
		" realtime=",
		_realtime,
		" baseline_field=",
		_baseline_field,
		" baseline_targets=",
		_baseline_targets,
		" avg_sampled_1s_process_max_ms=",
		snappedf(process_max_sum_ms / index, 0.01),
		" avg_sampled_1s_physics_max_ms=",
		snappedf(physics_max_sum_ms / index, 0.01),
		" physics_ticks=",
		Engine.get_physics_frames() - physics_started,
		" physics_hz=",
		Engine.physics_ticks_per_second,
		" interpolation=",
		physics_interpolation,
		" diagnostic_no_motion=",
		_no_motion,
		" diagnostic_no_queues=",
		_no_queues
	)


func _frames(count):
	for _index in range(count):
		await process_frame


func _check(condition, message = "Scale workload invariant failed"):
	# Packaged release binaries strip assert(), but their workload must still be
	# verified before frame timings can be accepted.
	if not condition:
		_checks_failed += 1
		push_error(message)
