extends "res://tests/rendered/SplitSignalPreview.gd"


func _run():
	path = "user://supply-ui-progress-%d.json" % OS.get_process_id()
	var manager = root.get_node("SaveManager")
	manager.autosaves_enabled = true
	manager.slots.directory = "user://supply-ui-slots-%d" % OS.get_process_id()
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
	_check(menu._operation_buttons.size() == 6, "Campaign does not expose six operations")
	await _click(menu._operation_buttons[2])
	_check(menu._mission_id == "split_signal", "Third operation inaccessible")
	menu._operation_buttons[0].grab_focus()
	await _key(root, KEY_SPACE)
	_check(menu._mission_id == "supply_line", "Keyboard could not select Supply Line")
	_check(menu._start_button.get_global_rect().end.y <= 710, "Three-operation briefing clipped")
	await _capture("supply-line-briefing-720p")
	await _click(menu._start_button)
	for frame in 240:
		await process_frame
		if is_instance_valid(current_scene) and "convoy" in current_scene:
			break
	game = current_scene
	_check("convoy" in game, "Campaign did not start Supply Line")
	if not "convoy" in game:
		quit(1)
		return
	game.progress_path = path
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	await _frames(35)
	_check(
		FileAccess.file_exists(manager.slots.path_for("auto-1")),
		"Supply Line start checkpoint missing"
	)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Convoy objectives cover minimap"
	)
	await _click(_named_button(game.hud, "Select trucks"))
	_check(get_nodes_in_group("selected_units").size() == 3, "Select trucks selected escorts")
	_check(game.find_child("UnitMenus")._program_panel == null, "Convoy exposes programming")
	await _capture("supply-line-convoy-720p")
	var menu_panel = game.find_child("UnitMenus")
	_check(
		not game.hud.objective_panel.get_global_rect().intersects(menu_panel.get_global_rect()),
		"Convoy panel covers unit orders"
	)
	await _click(game.hud._pause_button)
	var point = game.convoy[0].unit.position
	await _click(game.hud._advance)
	await _frames(15)
	_check(paused and game.convoy[0].unit.position == point, "Paused Advance moved a truck")
	_check(game.convoy[0].unit.action != null, "Advance did not queue a truck movement order")
	_check(await manager.save_slot("manual-1"), "Convoy archive save failed")
	_check(
		manager.slots.describe("manual-1").summary.begins_with("Supply Line"),
		"Archive has wrong mission title"
	)
	await manager.open_dialog("load", "manual-1")
	await _frames(5)
	await _capture("supply-line-archive-720p")
	_check(await manager.load_slot("manual-1"), "Convoy archive load failed")
	game = current_scene
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	_check(
		paused and game.convoy.size() == 3 and game.convoy[0].unit.position == point,
		"Loaded convoy advanced or lost identity"
	)
	await _frames(5)
	await _click(game.hud._pause_button)
	await _frames(180)
	_check(
		game.convoy[0].unit.position.distance_to(point) > 0.3,
		"Loaded convoy did not resume movement"
	)
	await _click(game.hud._hold)
	_check(
		game.trucks().all(func(truck): return truck.action == null),
		"Hold did not stop convoy orders"
	)
	await _click(_named_button(game.hud, "Select escorts"))
	_check(get_nodes_in_group("selected_units").size() == 18, "Escort selection included convoy")
	_check(game.find_child("UnitMenus")._squad_panel == null, "Escort exposes locked coordination")
	_check(
		not game.find_child("UnitMenus")._orders_panel._resume.visible,
		"Conventional escorts expose program auto-resume"
	)
	for index in 3:
		await _click(game.hud._view_buttons[index])
		_check(
			(
				(
					game
					. get_node("IsometricCamera3D")
					. get_ray_intersection(Vector2(640, 360))
					. distance_to(game.map.POINTS[index])
				)
				< 1
			),
			"Route locator did not focus checkpoint"
		)
	await _click(game.hud._pause_button)
	game.convoy[0].unit.position = game.map.POINTS[0]
	game.advance_convoy()
	await _frames(5)
	_check("Hold to clear" in game.hud._truck_labels[0].text, "Checkpoint stop hint missing")
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Checkpoint stop hint covers minimap"
	)
	await _click(game.hud._view_buttons[0])
	await _capture("supply-line-checkpoint-720p")
	await _click(game.hud._hold)
	_check(game.convoy[0].unit.action == null, "Checkpoint Hold did not clear parking order")
	await _click(game.hud._pause_button)
	camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 230
	camera.set_size_safely(175)
	camera.set_position_safely(Vector3(96, 0, 64))
	game.fog_of_war.reveal()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture("supply-line-overview-720p")
	# Only the result-screen fixture skips combat; the headless suite wins via
	# real traversal and combat without removing opponents or changing health.
	for index in 2:
		game.convoy[index].unit.queue_free()
		game.convoy[index].delivered = true
		game.convoy[index].leg = 3
	game._finish("Victory")
	await _frames(4)
	await _capture("supply-line-result-720p")
	await _click(_named_button(game.hud, "Play again"))
	await _frames(100)
	game = current_scene
	game.progress_path = path
	_check(
		game.settings.mission_id == "supply_line" and game.trucks().size() == 3 and not paused,
		"Convoy restart failed"
	)
	game.hud._open_menu()
	await _frames(4)
	await _click(_named_button(game.hud, "Campaign"))
	await _frames(10)
	_check(current_scene.has_method("_start") and not paused, "Convoy Campaign return failed")
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
	print("Supply Line UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _click(control):
	await _frames(3)
	var point = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	# Keep the synthetic click together so native pointer motion between frames
	# cannot release it outside the button. Exercise normal GUI event dispatch.
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(3)
