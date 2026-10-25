extends "res://tests/headless/UnitAnimationRegression.gd"

const OUTPUT = "res://art/vehicle-damage/performance.json"
const WARMUP = 180
const SAMPLES = 240
const COUNT = 96


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Damage performance probe requires a renderer")
		quit(1)
		return
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	var vsync = DisplayServer.window_get_vsync_mode()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"living_world": false,
			"reduced_flashes": false,
			"master_volume": .75,
			"effects_volume": .75
		}
	)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var report = {
		"adapter": RenderingServer.get_video_adapter_name(),
		"units": COUNT,
		"samples_per_phase": SAMPLES,
		"warmup_frames": WARMUP,
		"comparison":
		(
			"Same stationary army at 24% HP. Damage particles/audio disabled/enabled; "
			+ "health, orders, chassis poses and simulation remain unchanged."
		),
		"factions": []
	}
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		_game.set_process(false)
		_game.set_physics_process(false)
		_game.hud.hide()
		_game.get_node("HUD").hide()
		_game.subtitles.hide()
		var camera = _game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(34)
		camera.set_position_safely(Vector3(39, 0, 29))
		var units = []
		for index in COUNT:
			var unit = _spawn(
				["Tank", "AntiAirVehicle", "CombatRobot"][index % 3],
				0,
				Vector3(21 + (index % 16) * 2.4, 0, 22 + (index / 16) * 2.4)
			)
			unit.hp = unit.hp_max * .24
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			unit.set_process(false)
			unit.set_physics_process(false)
			unit.get_node("Movement").set_physics_process(false)
			units.append(unit)
		var initial = units.map(func(unit): return [unit.hp, unit.position, unit.action])
		var before = await _measure(false)
		var decorated = await _measure(true)
		var after = await _measure(false)
		for index in units.size():
			_check(
				[units[index].hp, units[index].position, units[index].action] == initial[index],
				"Probe changed authoritative unit state"
			)
		var entry = {
			"faction": faction,
			"baseline_before": before,
			"damage_presentation": decorated,
			"baseline_after": after
		}
		report.factions.append(entry)
		print("DAMAGE PERFORMANCE ", JSON.stringify(entry))
		_game.combat_effects._headless = false
		await _close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file = FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	options.restore(original)
	DisplayServer.window_set_vsync_mode(vsync)
	for message in _errors:
		push_error(message)
	print("Vehicle damage performance: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _measure(decorated):
	# Existing presentation gates only. Never toggle authoritative HP, damage bands,
	# movement, action or physics to produce the baseline.
	_game.combat_effects._headless = not decorated
	root.get_node("Globals").options.effects_volume = .75 if decorated else 0.0
	await _frames(WARMUP)
	var frame_times = []
	var process_times = []
	var draws = []
	var last = Time.get_ticks_usec()
	for frame in SAMPLES:
		await process_frame
		var now = Time.get_ticks_usec()
		frame_times.append((now - last) / 1000.0)
		last = now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var pools = {}
	for kind in _game.combat_effects._emitters:
		pools[kind] = _game.combat_effects._emitters[kind].amount
	var voices = _game.combat_audio._players.filter(func(voice): return voice.active)
	var damage = voices.filter(
		func(voice): return voice.kind in ["damage_diesel", "damage_plasma", "damage_steam"]
	)
	_check(
		_game.combat_audio._players.size() <= 24 and damage.size() <= 4,
		"Dense army exceeded audio pool bounds"
	)
	return {
		"frame_ms": _stats(frame_times),
		"process_ms": _stats(process_times),
		"draw_calls": _stats(draws),
		"particle_capacity_by_kind": pools,
		"allocated_audio_voices": _game.combat_audio._players.size(),
		"active_audio_voices": voices.size(),
		"active_damage_voices": damage.size()
	}


func _stats(values):
	values.sort()
	return {
		"median": values[values.size() / 2],
		"p95": values[int(values.size() * .95)],
		"max": values[-1]
	}
