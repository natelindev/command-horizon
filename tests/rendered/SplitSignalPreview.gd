extends "res://tests/headless/SplitSignalRegression.gd"

var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 120000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Split Signal UI exceeded wall-time deadline")
		quit(1)
	return false


func _run():
	path = "user://split-ui-progress-%d.json" % OS.get_process_id()
	var manager = root.get_node("SaveManager")
	manager.autosaves_enabled = true
	manager.slots.directory = "user://split-ui-slots-%d" % OS.get_process_id()
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	var menu = load("res://source/main-menu/Campaign.tscn").instantiate()
	menu.progress_path = path
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	menu._operation_buttons[2].grab_focus()
	await _key(root, KEY_SPACE)
	_check(menu._mission_id == "split_signal", "Keyboard did not choose Split Signal")
	await _click(menu._operation_buttons[1])
	_check(menu._mission_id == "first_orders", "Mouse did not return to First Orders")
	await _click(menu._operation_buttons[2])
	_check(menu._start_button.text == "Start Split Signal", "Briefing/start button did not update")
	_check(menu._start_button.get_global_rect().end.y <= 710, "Campaign selection clipped at 720p")
	await _capture("split-signal-briefing-720p")
	var start_pressed = [false]
	menu._start_button.pressed.connect(func(): start_pressed[0] = true)
	await _click(menu._start_button)
	_check(start_pressed[0], "Mouse did not activate Start Split Signal")
	for frame in 240:
		await process_frame
		if is_instance_valid(current_scene) and "control_seconds" in current_scene:
			break
	game = current_scene
	_check("control_seconds" in game, "Start did not load Split Signal")
	if not "control_seconds" in game:
		for message in errors:
			push_error(message)
		quit(1)
		return
	game.progress_path = path
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	await _frames(35)
	_check(
		FileAccess.file_exists(manager.slots.path_for("auto-1")),
		"Operation start checkpoint missing"
	)
	_check(game.hud._match_label() == "Split Signal", "Battle title is wrong")
	_check(
		game.map.relays.all(func(relay): return not relay._label.visible), "Relay labels overlap"
	)
	_check(
		game.hud._markers[0].get_parent().layer < game.hud.layer, "Relay title covers HUD panels"
	)
	_check(game.hud.objective_panel.get_global_rect().end.y < 500, "Objectives cover minimap")
	for index in 3:
		await _click(game.hud._relay_buttons[index])
		_check(game.hud._markers[index].visible, "Relay locator did not expose public objective")
	await _capture("split-signal-relay-720p")
	# The regular preset panel must coexist with the mission panel.
	var tank = _units(game._get_human_player(), "Tank")[0]
	tank.get_node("Selection").select()
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	_check(
		not game.hud.objective_panel.get_global_rect().intersects(menus.get_global_rect()),
		"Mission covers selection/program controls"
	)
	await _capture("split-signal-program-720p")
	root.get_node("MatchSignals").deselect_all_units.emit()
	# Actual manual archive/save-dialog/load path includes the mission title and paused return.
	_check(await manager.save_slot("manual-1"), "UI scenario could not save operation")
	_check(
		manager.slots.describe("manual-1").summary.begins_with("Split Signal"),
		"Save slot mislabels operation"
	)
	await manager.open_dialog("load", "manual-1")
	await _frames(5)
	await _capture("split-signal-archive-720p")
	_check(await manager.load_slot("manual-1"), "Operation archive could not load")
	game = current_scene
	game.progress_path = path
	_check(
		paused and game.settings.mission_id == "split_signal",
		"Loading operation lost paused state or mission"
	)
	await _frames(5)
	await _click(game.hud._pause_button)
	_check(not paused, "Resume button did not resume operation")
	camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 150
	camera.set_size_safely(100)
	camera.set_position_safely(Vector3(54, 0, 44))
	game.fog_of_war.reveal()
	await _capture("split-signal-overview-720p")
	game._finish("Victory")  # Full combat/objective win is covered by SplitSignalRegression.
	await _frames(4)
	await _capture("split-signal-victory-720p")
	await _click(_named_button(game.hud, "Play again"))
	await _frames(100)
	game = current_scene
	game.progress_path = path
	_check(
		game.settings.mission_id == "split_signal" and game.control_seconds == 0 and not paused,
		"Replay lost mission/reset state"
	)
	game.hud._open_menu()
	await _frames(4)
	await _click(_named_button(game.hud, "Campaign"))
	await _frames(10)
	_check(current_scene.has_method("_start") and not paused, "Campaign return failed")
	manager.autosaves_enabled = false
	for file in DirAccess.get_files_at(manager.slots.directory):
		DirAccess.remove_absolute(manager.slots.directory.path_join(file))
	DirAccess.remove_absolute(manager.slots.directory)
	DirAccess.remove_absolute(path)
	current_scene.queue_free()
	await _frames(3)
	for message in errors:
		push_error(message)
	print("Split Signal UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _click(control):
	# Submit one synthetic gesture together; native pointer motion between a synthetic
	# press/release otherwise changes Button drag state on a shared desktop.
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, false)
	await _frames(3)


func _key(viewport, code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.window_id = viewport.get_window_id()
		event.pressed = pressed
		viewport.push_input(event, true)
		await _frames(3)


func _named_button(node, title):
	var buttons = node.find_children("*", "Button", true, false)
	return buttons.filter(func(button): return button.text == title)[0]


func _capture(title):
	await _frames(8)
	if not root.can_draw():
		print("Capture waiting for visible test window: ", title)
		root.grab_focus()
		for frame in 120:
			await process_frame
			if root.can_draw():
				break
	if not root.can_draw():
		_check(false, "Capture unavailable while test window is obscured: " + title)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)
