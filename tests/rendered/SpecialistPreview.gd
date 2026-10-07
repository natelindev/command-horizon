extends "res://tests/rendered/ProgramPreview.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(9)
	camera.set_position_safely(Vector3(11, 0, 26))
	await _frames(50)
	var human = _game._get_human_player()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	camera.set_size_safely(16)
	camera.set_position_safely(Vector3(20, 0, 24))
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	var tank = tanks[0]
	var air = load("res://source/match/units/Helicopter.tscn").instantiate()
	_game._setup_and_spawn_unit(air, Transform3D(Basis(), Vector3(22, 0, 27)), human, false)
	await _frames(30)
	tank.program.run()
	await _frames(3)
	for unit in [tank, air]:
		unit.get_node("Selection").select()
	_game.hud._toggle_pause()
	await _frames(20)
	var menu = _game.find_child("UnitMenus")
	var panel = menu._program_panel
	panel.library_path = "user://specialist-ui-%d.json" % OS.get_process_id()
	var index = panel._preset_ids.find("strike_return")
	_check(index >= 0, "Mixed selection missing aircraft specialist")
	panel._preset.select(index)
	panel._preset.item_selected.emit(index)
	panel._assign_area()
	_game.hud.accept_program_assignment(Vector3(25, 0, 28), null)
	panel._arm("safe")
	# A factory warning during map assignment must be delivered after the instruction.
	_game.hud.show_notice("Factory program incompatible; new unit received Hold.")
	_game.hud.accept_program_assignment(Vector3(18, 0, 28), null)
	_check(
		tank.program.mode == "Running" and tank.program.safe_point == null,
		"Specialist assignment interrupted incompatible tank"
	)
	panel._name.text = "Raid and regroup"
	panel._save()
	panel._load_saved(1)
	panel._run.pressed.emit()
	_check(air.program.config.preset == "strike_return", "UI failed to apply aircraft preset")
	_check(tank.program.config.preset == "hold", "Mixed Apply changed incompatible tank")
	await _frames(20)
	await _capture("specialist-strike-720p")
	_check(menu.get_global_rect().position.y >= 0, "Specialist panel exceeds 720p height")
	_check(menu.get_global_rect().end.x <= 1280, "Specialist panel exceeds 720p width")
	_game.hud._process(5.0)
	_check(
		_game.hud._assignment_hint.text.begins_with("Factory program incompatible"),
		"Assignment discarded factory fallback notice"
	)
	_game.hud._toggle_pause()
	await _frames(40)
	_check(air.program.mode == "Running", "Strike program did not start after pause")
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	await _frames(5)
	panel = menu._program_panel
	_check(
		"strike_return" not in panel._preset_ids, "Armor selector shows irrelevant aircraft preset"
	)
	panel.library_path = "user://specialist-ui-%d.json" % OS.get_process_id()
	panel._library.read_library(panel.library_path)
	panel._refresh_saved()
	panel._load_saved(1)
	_check(panel._run.disabled, "Incompatible saved preset can run on tank")
	index = panel._preset_ids.find("standoff")
	panel._preset.select(index)
	panel._preset.item_selected.emit(index)
	panel._assign_area()
	_game.hud.accept_program_assignment(Vector3(20, 0, 26), null)
	panel._run.pressed.emit()
	await _frames(25)
	await _capture("specialist-standoff-720p")
	_check(tank.program.config.preset == "standoff", "Standoff UI Apply failed")
	DirAccess.remove_absolute(panel.library_path)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: specialist role filtering/mixed Apply/map assignments/save/load; "
				+ "incompatible saved draft; deferred fallback notice; paused execution; 720p"
			)
		)
	quit(0 if _errors.is_empty() else 1)
