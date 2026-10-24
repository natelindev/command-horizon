extends "res://tests/rendered/ScaleFrameBenchmark.gd"


## Same 200 mobile + 80 structure workload as ScaleFrameBenchmark, owned by
## four hostile sides. Run without --headless or --fixed-fps; --profile-field
## adds inclusive query timings and must be compared only with another probe run.
func _run():
	if DisplayServer.get_name() == "headless" or "--fixed-fps" in OS.get_cmdline_args():
		push_error("Four-player frame pacing requires real-time rendering")
		quit(1)
		return
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	Engine.max_fps = 0
	_realtime = true
	_behaviors = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = false
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for index in 4:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = 1 if index == 0 else 2
		side.faction = ["bastion", "helix", "frontier", "bastion"][index]
		side.color = root.get_node("Constants").Player.COLORS[index]
		settings.players.append(side)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 110
	camera.set_size_safely(100)
	camera.set_position_safely(Vector3(50, 0, 50))
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.queue_free()
	await _frames(3)
	var players = get_nodes_in_group("players")
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	for side in 4:
		var right = side % 2 == 1
		var bottom = side >= 2
		for index in 20:
			var role = (
				"CommandCenter"
				if index == 0
				else ["PowerPlant", "Barracks", "VehicleFactory", "RepairDepot"][index % 4]
			)
			var point = Vector3(
				(76 if right else 5) + index % 4 * 5, 0, (76 if bottom else 5) + index / 4 * 4
			)
			_spawn(role, players[side], point)
		var army = []
		for index in 50:
			var role = ["Tank", "Infantry", "CombatRobot", "Helicopter", "RepairRobot"][index % 5]
			var point = Vector3(
				66 - index % 5 * 2 if right else 34 + index % 5 * 2,
				0,
				68 - index / 5 * 2 if bottom else 32 + index / 5 * 2
			)
			var unit = _spawn(role, players[side], point)
			unit.hp_max = 100000
			unit.hp = unit.hp_max
			army.append(unit)
			_start_positions[unit] = unit.global_position
		_armies.append(army)
	_check(get_nodes_in_group("units").size() == 280, "Four-player fixture lost its population")
	_game.settings.visibility = settings.Visibility.FULL
	_game.fog_of_war.reveal()
	if _profile_field:
		_game.battlefield.set_script(load("res://tests/headless/ScaleFieldProbe.gd"))
	paused = true
	_check(
		await load("res://source/match/effects/CombatPrewarm.gd").prepare(_game),
		"FFA prewarm failed"
	)
	paused = false
	for side in 4:
		for unit in _armies[side]:
			behavior.guard(unit, Vector3(46 if side % 2 == 0 else 54, 0, 46 if side < 2 else 54))
	await _measure("movement", 480)
	# Interleave the four hostile lines with legal body spacing, so every
	# armed role has nearby opponents instead of trapping 200 bodies at one
	# shared destination. This is a rendering workload, not a balance trial.
	for side in 4:
		for index in _armies[side].size():
			var unit = _armies[side][index]
			unit.global_position = Vector3(
				27 + index % 10 * 4.8, unit.global_position.y, 20 + index / 10 * 12 + side * 2.4
			)
			unit.reset_physics_interpolation()
			behavior.guard(unit, unit.global_position)
	_game.battlefield.invalidate()
	await _frames(90)
	var shots_before = _game.combat_effects.shots_emitted
	await _measure("combat", 480)
	_check(
		_game.combat_effects.shots_emitted - shots_before >= 100,
		"Combat sample did not sustain real firing"
	)
	var fired = (
		_start_positions
		. keys()
		. filter(func(unit): return unit.has_meta("next_attack_availability_time"))
		. size()
	)
	_check(fired >= 80, "Four-player fixture did not exercise enough weapons")
	_check(
		get_nodes_in_group("units").size() == 280, "Four-player population changed during sample"
	)
	print("FFA owners=4 mobile=200 structures=80 fired=", fired, " failures=", _checks_failed)
	_game.queue_free()
	await _frames(8)
	await root.get_node("Globals").quit_game(0 if _checks_failed == 0 else 1)
