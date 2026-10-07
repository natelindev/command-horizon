extends "res://tests/headless/SaveSlotsRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	manager = root.get_node("SaveManager")
	manager.slots.directory = "user://save-ui-%d" % OS.get_process_id()
	save_path = "user://save-ui-unused-%d.json" % OS.get_process_id()
	path = "user://save-ui-progress-%d.json" % OS.get_process_id()
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(5)
	await _click(_button_named(menu, "LOAD BATTLE"))
	_check(
		manager.dialog != null and manager.dialog._primary.disabled,
		"Empty archive could not open from menu"
	)
	await _capture("save-empty-720p")
	await _key(KEY_ESCAPE)
	_check(manager.dialog == null and not paused, "Archive Escape failed")
	menu.queue_free()
	await _frames(3)
	await _skirmish("helix")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(true)
	await _click(_button_named(game.hud, "Menu [Esc]"))
	await _click(_button_named(game.hud, "Save / Load battle"))
	_check(
		manager.dialog != null and manager.dialog.mode == "save", "Battle menu did not open saves"
	)
	var dialog = manager.dialog
	_check(dialog._primary.get_global_rect().end.y < 705, "Archive actions clipped at 720p")
	await _click(dialog._primary)
	_check(manager.slots.describe("manual-1").valid, "Actual Save button did not write slot")
	await _capture("save-manual-720p")
	await _click(dialog._primary)
	_check(dialog._primary.text == "Overwrite save", "Overwrite needs review confirmation")
	await _capture("save-overwrite-720p")
	await _key(KEY_ESCAPE)
	_check(
		manager.dialog == null and paused and game.hud._overlay != null,
		"Cancel discarded parent menu pause"
	)
	await _key(KEY_ESCAPE)
	_check(not paused, "Parent menu did not close")
	await _key(KEY_F5)
	for frame in range(180):
		await process_frame
		if not manager.busy:
			break
	_check(manager.slots.describe("quick").valid, "F5 did not save")
	var old_game = game
	await _key(KEY_F9)
	_check(
		manager.dialog != null and manager.dialog.selected == "quick", "F9 did not select quicksave"
	)
	var snapshot_time = manager.slots.read_slot("quick").simulation_time
	await _click(manager.dialog._primary)
	_check(manager.dialog._primary.text == "Confirm load", "Load replacement lacks confirmation")
	await _capture("save-load-confirm-720p")
	await _click(manager.dialog._primary)
	for frame in range(300):
		await process_frame
		if not manager.busy:
			break
	game = current_scene
	_check(
		not is_instance_valid(old_game) and manager.dialog == null and paused,
		"Actual quickload did not replace battle"
	)
	_check(game.simulation_time == snapshot_time, "UI load advanced simulation")
	await _capture("save-loaded-720p")
	await _click(game.hud._pause_button)
	_check(not paused, "Loaded battle did not resume from button")
	# UI blocking: camera and world selection stay unchanged while the archive owns input.
	await _key(KEY_F9)
	camera = game.get_node("IsometricCamera3D")
	var position = camera.position
	await _key(KEY_W)
	await _key(KEY_SPACE)
	_check(camera.position == position and paused, "Archive leaked input to the battlefield")
	await _key(KEY_ESCAPE)
	_check(not paused, "Load cancel did not resume original battle")
	# Corrupt-file feedback, then load the good slot from the main menu.
	var bad = FileAccess.open(manager.slots.path_for("manual-2"), FileAccess.WRITE)
	bad.store_string("broken ui fixture")
	bad.close()
	await _click(_button_named(game.hud, "Menu [Esc]"))
	await _click(_button_named(game.hud, "Main menu"))
	await _frames(6)
	await _click(_button_named(current_scene, "LOAD BATTLE"))
	await _key(KEY_DOWN)
	_check(manager.dialog.selected == "manual-2", "Keyboard slot selection failed")
	_check(manager.dialog._primary.disabled, "Corrupt archive entry is actionable")
	await _capture("save-corrupt-720p")
	await _key(KEY_UP)
	_check(manager.dialog.selected == "manual-1", "Keyboard slot selection did not return")
	manager.dialog._primary.grab_focus()
	await _key(KEY_ENTER)
	for frame in range(300):
		await process_frame
		if not manager.busy:
			break
	game = current_scene
	_check(
		manager.dialog == null and game.settings.players[0].faction == "helix",
		"Main menu load failed"
	)
	manager.autosaves_enabled = false
	for file in DirAccess.get_files_at(manager.slots.directory):
		DirAccess.remove_absolute(manager.slots.directory.path_join(file))
	DirAccess.remove_absolute(manager.slots.directory)
	print(
		(
			"PASS: rendered 720p archive, manual save/confirm/cancel, F5/F9, load/resume; "
			+ "input isolation, corruption and main-menu load"
		)
	)
	await _finish()


func _capture(title):
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _click(button):
	_check(is_instance_valid(button), "UI button missing")
	if not is_instance_valid(button):
		return
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)

	while manager.busy:
		await process_frame


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)

	while manager.busy:
		await process_frame


func _button_named(node, value):
	if node is Button and node.text == value:
		return node
	for child in node.get_children():
		var found = _button_named(child, value)
		if found != null:
			return found
	return null
