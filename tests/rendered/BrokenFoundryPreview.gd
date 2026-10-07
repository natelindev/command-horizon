extends "res://tests/rendered/SupplyLinePreview.gd"


func _run():
	path = "user://foundry-ui-progress-%d.json" % OS.get_process_id()
	var manager = root.get_node("SaveManager")
	manager.autosaves_enabled = true
	manager.slots.directory = "user://foundry-ui-slots-%d" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var menu = load("res://source/main-menu/Campaign.tscn").instantiate()
	menu.progress_path = path
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	_check(menu._operation_buttons.size() == 6, "Campaign operation missing")
	for button in menu._operation_buttons:
		await _click(button)
		_check(menu._start_button.get_global_rect().end.y <= 710, "Campaign briefing clips")
		_check(button.get_global_rect().end.x <= 1250, "Campaign selector clips horizontally")
	await _click(menu._operation_buttons[4])
	_check(menu._mission_id == "broken_foundry", "Foundry briefing inaccessible")
	await _capture("foundry-briefing-720p")
	menu._start_button.grab_focus()
	await _key(root, KEY_SPACE)
	for frame in 240:
		await process_frame
		if is_instance_valid(current_scene) and "nodes" in current_scene:
			break
	game = current_scene
	_check("nodes" in game, "Foundry failed to start")
	if not "nodes" in game:
		quit(1)
		return
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(35)
	_check(FileAccess.file_exists(manager.slots.path_for("auto-1")), "Foundry checkpoint missing")
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Foundry panel covers minimap"
	)
	await _click(_named_button(game.hud, "Infantry"))
	_check(get_nodes_in_group("selected_units").size() == 12, "Infantry selection wrong")
	await _click(_named_button(game.hud, "Repairs"))
	_check(get_nodes_in_group("selected_units").size() == 2, "Repair selection wrong")
	game.hud.show_notice(
		"Production batch 1 / 3 queued. Destroy its node to cancel unfinished units."
	)
	await _frames(4)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Production notice pushes objectives onto minimap"
	)
	await _capture("foundry-support-720p")
	await _click(_named_button(game.hud, "Foundry"))
	# Trigger production through district entry, then save actual paid queue work.
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.position.x = 47
	await _frames(2)
	scout.position.x = 35
	await _frames(750)
	await _click(game.hud._pause_button)
	_check(paused and game.nodes[0].batches == 1, "Foundry production/pause flow failed")
	var left = game.nodes[0].unit.get_node("ProductionQueue").get_elements()[0].time_left
	_check(await manager.save_slot("manual-1"), "Foundry save failed")
	await manager.open_dialog("load", "manual-1")
	await _capture("foundry-archive-720p")
	_check(
		manager.slots.describe("manual-1").summary.begins_with("Broken Foundry"),
		"Foundry archive title wrong"
	)
	_check(await manager.load_slot("manual-1"), "Foundry archive load failed")
	game = current_scene
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	_check(
		(
			paused
			and game.nodes[0].unit.get_node("ProductionQueue").get_elements()[0].time_left == left
		),
		"Loaded factory timer changed"
	)
	await _click(game.hud._pause_button)
	await _frames(90)
	_check(
		game.nodes[0].unit.get_node("ProductionQueue").get_elements()[0].time_left < left,
		"Factory did not resume"
	)
	await _capture("foundry-production-720p")
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 200
	camera.set_size_safely(155)
	camera.set_position_safely(Vector3(80, 0, 58))
	game.fog_of_war.reveal()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture("foundry-overview-720p")
	# Controlled UI result fixture; the headless/live commander verifies real combat.
	for unit in game._enemy.get_children():
		if unit.is_in_group("units") and unit.movement_speed > 0:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.position = Vector3(150, 0, 105)
	for node in game.nodes:
		node.unit.hp = 0
	await _frames(5)
	game.map.relay.captured_by = game._get_human_player()
	var infantry = _units(game._get_human_player(), "Infantry")[0]
	infantry.position = game.map.CONTROL + Vector3(-1.5, 0, 0)
	game.hold_seconds = 29.95
	game.battlefield.invalidate()
	await _frames(10)
	_check(game.result == "Victory", "Foundry result fixture failed")
	await _capture("foundry-result-720p")
	await _click(_named_button(game.hud, "Play again"))
	await _frames(100)
	game = current_scene
	game.progress_path = path
	_check(
		game.settings.mission_id == "broken_foundry" and not game.alarm and not paused,
		"Foundry replay failed"
	)
	game.hud._open_menu()
	await _frames(4)
	await _click(_named_button(game.hud, "Campaign"))
	await _frames(8)
	_check(current_scene.has_method("_start") and not paused, "Foundry campaign return failed")
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
	print("Broken Foundry UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
