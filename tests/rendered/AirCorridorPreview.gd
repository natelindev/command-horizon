extends "res://tests/rendered/SupplyLinePreview.gd"


func _run():
	path = "user://air-ui-progress-%d.json" % OS.get_process_id()
	var manager = root.get_node("SaveManager")
	manager.autosaves_enabled = true
	manager.slots.directory = "user://air-ui-slots-%d" % OS.get_process_id()
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
	await _click(menu._operation_buttons[3])
	_check(menu._mission_id == "air_corridor", "Air Corridor briefing inaccessible")
	_check(menu._start_button.get_global_rect().end.y <= 710, "Fourth briefing clips")
	await _capture("air-corridor-briefing-720p")
	menu._start_button.grab_focus()
	await _key(root, KEY_SPACE)
	for frame in 240:
		await process_frame
		if is_instance_valid(current_scene) and "flights" in current_scene:
			break
	game = current_scene
	_check("flights" in game, "Air Corridor failed to start")
	if not "flights" in game:
		quit(1)
		return
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(35)
	_check(
		FileAccess.file_exists(manager.slots.path_for("auto-1")),
		"Air Corridor start checkpoint missing"
	)
	_check(
		game.hud._launch.disabled and game.hud._finish.disabled,
		"Initial launch/completion gate wrong"
	)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Air objectives cover minimap"
	)
	await _click(_named_button(game.hud, "Ground screen"))
	_check(get_nodes_in_group("selected_units").size() == 16, "Ground screen selection wrong")
	await _click(_named_button(game.hud, "Air wing"))
	_check(get_nodes_in_group("selected_units").size() == 3, "Air wing includes ground/evac units")
	_check(game.find_child("UnitMenus")._program_panel != null, "Air wing lacks program controls")
	await _capture("air-corridor-commands-720p")
	# Controlled objective fixture; AirCorridorRegression clears sites in actual combat.
	for site in game.sites:
		site.unit.hp = 0
	await _frames(10)
	await _click(game.hud._pause_button)
	await _click(game.hud._launch)
	_check(game.flights[0].state == "flying" and paused, "Paused launch button failed")
	var point = game.flights[0].unit.position
	await _click(_named_button(game.hud, "Active flight"))
	_check(get_nodes_in_group("selected_units").size() == 1, "Flight selection failed")
	_check(await manager.save_slot("manual-1"), "Air Corridor save failed")
	_check(
		manager.slots.describe("manual-1").summary.begins_with("Air Corridor"),
		"Archive title wrong"
	)
	await manager.open_dialog("load", "manual-1")
	await _capture("air-corridor-archive-720p")
	_check(await manager.load_slot("manual-1"), "Air Corridor load failed")
	game = current_scene
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	_check(
		paused and game.flights[0].unit.position == point, "Loaded flight advanced or disappeared"
	)
	await _click(game.hud._pause_button)
	await _frames(150)
	_check(game.flights[0].unit.position.distance_to(point) > 1, "Loaded flight did not resume")
	await _click(_named_button(game.hud, "Active flight"))
	_check(game.find_child("UnitMenus")._squad_panel == null, "Evacuation exposes coordination")
	await _click(_named_button(game.find_child("UnitMenus"), "Stop current orders"))
	_check(game.flights[0].unit.action == null, "Player could not hold evacuation")
	await _click(game.hud._continue)
	_check(game.flights[0].unit.action != null, "Continue flight did not restore exit order")
	await _capture("air-corridor-flight-720p")
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 200
	camera.set_size_safely(140)
	camera.set_position_safely(Vector3(72, 0, 52))
	game.fog_of_war.reveal()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture("air-corridor-overview-720p")
	# Move fixture flights to the exit to exercise the actual extraction/Finish control.
	game.flights[0].unit.position = Vector3(
		game.map.EXIT.x, game.flights[0].unit.position.y, game.map.EXIT.z
	)
	await _frames(10)
	await _click(game.hud._launch)
	game.flights[1].unit.position = Vector3(
		game.map.EXIT.x, game.flights[1].unit.position.y, game.map.EXIT.z
	)
	await _frames(10)
	_check(
		not game.hud._finish.disabled and not game.finished,
		"Two-flight optional continuation missing"
	)
	await _click(game.hud._finish)
	_check(game.result == "Victory", "Finish operation failed")
	await _capture("air-corridor-result-720p")
	await _click(_named_button(game.hud, "Play again"))
	await _frames(100)
	game = current_scene
	game.progress_path = path
	_check(
		game.settings.mission_id == "air_corridor" and game.rescued() == 0 and not paused,
		"Air Corridor replay failed"
	)
	game.hud._open_menu()
	await _frames(4)
	await _click(_named_button(game.hud, "Campaign"))
	await _frames(8)
	_check(current_scene.has_method("_start") and not paused, "Air Corridor Campaign return failed")
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
	print("Air Corridor UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
