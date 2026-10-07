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
	var labs = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandLab"
	)
	_check(human.start_coordination(labs[0]), "Research did not start")
	human._physics_process(30.0)
	var members = human.get_children().filter(
		func(unit): return "type" in unit and unit.type in ["Tank", "RepairRobot", "Infantry"]
	)
	for unit in members:
		unit.get_node("Selection").select()
	_game.hud._toggle_pause()
	await _frames(20)
	var menu = _game.find_child("UnitMenus")
	var panel = menu._squad_panel
	panel._name.text = "Iron Guard"
	panel._create.pressed.emit()
	var squad = human.squad_roster.squads()[0]
	_check(squad.active_members().size() == members.size(), "Create squad lost selected members")
	_check(squad.ready_members().size() == 3, "Mixed squad readiness count incorrect")
	panel._policy.select(1)
	panel._policy.item_selected.emit(1)
	_check(squad.policy == "focus", "Squad policy selector failed")
	panel._name.text = "Frontier Guard"
	panel._rename.pressed.emit()
	_check(squad.title == "Frontier Guard", "Rename button failed")
	panel._select.pressed.emit()
	await _frames(20)
	_check(get_nodes_in_group("selected_units").size() == members.size(), "Select squad failed")
	menu._program_panel._preset.select(1)
	menu._program_panel._assign_area()
	_game.hud.accept_program_assignment(Vector3(21, 0, 26), null)
	menu._program_panel._run.pressed.emit()
	await _frames(20)
	await _capture("squad-paused-720p")
	_check(menu.get_global_rect().position.y >= 0, "Squad/program panel exceeds 720p height")
	_check(menu.get_global_rect().end.x <= 1280, "Squad/program panel exceeds 720p width")
	_game.hud._toggle_pause()
	await _frames(120)
	_check(
		squad.ready_members().all(func(unit): return unit.program.mode == "Running"),
		"Squad program application failed"
	)
	await _capture("squad-running-720p")
	# Individual override and explicit membership controls work while the squad continues.
	root.get_node("MatchSignals").deselect_all_units.emit()
	members[0].get_node("Selection").select()
	await _frames(5)
	root.get_node("MatchSignals").terrain_targeted.emit(Vector3(18, 0, 25))
	menu._squad_panel._remove.pressed.emit()
	_check(members[0].program_squad == null, "Leave button failed")
	menu._squad_panel._options.select(1)
	menu._squad_panel._options.item_selected.emit(1)
	menu._squad_panel._add.pressed.emit()
	_check(members[0].program_squad == squad, "Add selected button failed")
	menu._squad_panel._disband.pressed.emit()
	_check(
		members.all(func(unit): return unit.program_squad == null), "Disband left members attached"
	)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: rendered squad create/name/policy/select/leave/add/disband; "
				+ "mixed readiness; paused program Apply; 720p layout"
			)
		)
	quit(0 if _errors.is_empty() else 1)
