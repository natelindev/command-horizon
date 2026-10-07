extends "res://tests/rendered/SupplyLinePreview.gd"


func _run():
	path = "user://horizon-ui-progress-%d.json" % OS.get_process_id()
	var manager = root.get_node("SaveManager")
	manager.autosaves_enabled = true
	manager.slots.directory = "user://horizon-ui-slots-%d" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var menu_scene = load("res://source/main-menu/Campaign.tscn")
	var menu = menu_scene.instantiate()
	menu.progress_path = path
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	_check(menu._operation_buttons.size() == 6, "Finale missing from campaign")
	for button in menu._operation_buttons:
		await _click(button)
		_check(
			menu._start_button.get_global_rect().end.y <= 710,
			"Six-operation briefing clips vertically"
		)
		_check(button.get_global_rect().end.x <= 1250, "Six-operation selector clips horizontally")
	_check(
		menu._mission_id == "command_horizon" and menu._challenge.disabled,
		"Finale/challenge unlocking wrong"
	)
	await _capture("horizon-briefing-720p")
	menu._start_button.grab_focus()
	await _key(root, KEY_SPACE)
	for frame in 300:
		await process_frame
		if is_instance_valid(current_scene) and "deployed" in current_scene:
			break
	game = current_scene
	_check("deployed" in game, "Horizon failed to start")
	if not "deployed" in game:
		quit(1)
		return
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(35)
	_check(FileAccess.file_exists(manager.slots.path_for("auto-1")), "Finale checkpoint missing")
	for entry in [["Infantry", 12], ["Armor", 14], ["Air wing", 3], ["Repairs", 2]]:
		await _click(_named_button(game.hud, entry[0]))
		_check(
			get_nodes_in_group("selected_units").size() == entry[1],
			"Finale selection wrong: " + entry[0]
		)
	game.hud.show_notice(
		"Deployment ready. Keep infantry here while your strike force destroys command."
	)
	await _frames(4)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Finale objective panel covers minimap"
	)
	await _capture("horizon-support-720p")
	await _click(_named_button(game.hud, "Deployment"))
	await _click(game.hud._pause_button)
	_check(paused, "Finale pause failed")
	_check(await manager.save_slot("manual-1"), "Finale save failed")
	await manager.open_dialog("load", "manual-1")
	await _capture("horizon-archive-720p")
	_check(
		manager.slots.describe("manual-1").summary.begins_with("Command Horizon"),
		"Finale archive title wrong"
	)
	_check(await manager.load_slot("manual-1"), "Finale archive load failed")
	game = current_scene
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	_check(
		paused and not game.alternate_route and not game.deployed,
		"Loaded finale phase/route changed"
	)
	var time = game.simulation_time
	await _click(game.hud._pause_button)
	await _frames(60)
	_check(game.simulation_time > time, "Finale did not resume")
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 230
	camera.set_size_safely(185)
	camera.set_position_safely(Vector3(92, 0, 66))
	game.fog_of_war.reveal()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture("horizon-overview-720p")
	# This fixture checks result controls; the independent commander exercises combat.
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = (
				Vector3(15, 0, 103)
				if unit.player == game._get_human_player()
				else Vector3(175, 0, 100)
			)
	game.map.relay.captured_by = game._get_human_player()
	game.deployed = true
	game.hold_seconds = 30
	game.target_command.hp = 0
	var infantry = _units(game._get_human_player(), "Infantry")[0]
	infantry.position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(10)
	_check(game.result == "Victory", "Finale result fixture failed")
	await _capture("horizon-result-720p")
	await _click(_named_button(game.hud, "Play again"))
	await _frames(100)
	game = current_scene
	game.progress_path = path
	_check(
		game.settings.mission_id == "command_horizon" and not game.deployed and not paused,
		"Finale replay failed"
	)
	game.hud._open_menu()
	await _frames(4)
	await _click(_named_button(game.hud, "Campaign"))
	await _frames(8)
	menu = current_scene
	_check(menu.has_method("_start") and not paused, "Finale campaign return failed")
	# Reload isolated test progress to inspect actual unlocked challenge controls.
	menu.queue_free()
	await _frames(3)
	menu = menu_scene.instantiate()
	menu.progress_path = path
	root.add_child(menu)
	current_scene = menu
	await _frames(6)
	await _click(menu._operation_buttons[5])
	_check(not menu._challenge.disabled, "Victory did not unlock challenges")
	# The native popup is exercised separately with desktop input. This fixture
	# verifies the selected challenge's briefing layout and launch integration.
	menu._challenge.select(1)
	menu._challenge.item_selected.emit(1)
	await _frames(4)
	_check(
		menu._challenge.selected == 1 and "Lean:" in menu._response.text,
		"Challenge briefing failed"
	)
	await _capture("horizon-challenge-720p")
	_check(menu._start_button.get_global_rect().end.y <= 710, "Challenge briefing clips")
	manager.autosaves_enabled = false
	for file in DirAccess.get_files_at(manager.slots.directory):
		DirAccess.remove_absolute(manager.slots.directory.path_join(file))
	DirAccess.remove_absolute(manager.slots.directory)
	DirAccess.remove_absolute(path)
	current_scene.queue_free()
	await _frames(3)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Command Horizon UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
