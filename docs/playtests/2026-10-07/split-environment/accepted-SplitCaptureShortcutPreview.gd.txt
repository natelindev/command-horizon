extends "res://tests/headless/SplitCaptureShortcut.gd"

var original_options = {}
var clicks = 0


func _prepare_display():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1280, 720)


func _restore_display():
	root.get_node("Globals").options.restore(original_options)


func _activate(button):
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var activated = [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	clicks += 1
	if clicks % 2 == 0:
		button.grab_focus()
		for down in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	else:
		await _mouse(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(5)
	_check(activated[0], "Capture shortcut input did not activate")
	print("CAPTURE SHORTCUT INPUT ", button.text)


func _capture_order(_unit, point):
	var camera = game.get_node("IsometricCamera3D")
	await _mouse(camera.unproject_position(point), MOUSE_BUTTON_RIGHT)
	print("CAPTURE ORDER right-click ", point)


func _mouse(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)
		await _frames(3)


func _review(label):
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Recovery panel overlaps minimap"
	)
	_check(root.get_visible_rect().encloses(panel), "Recovery panel leaves viewport")
	for button in game.hud._infantry_buttons + game.hud._relay_buttons:
		if button.visible:
			_check(panel.encloses(button.get_global_rect()), "Recovery button leaves panel")
	for row in game.hud._relay_labels:
		_check(panel.encloses(row.get_global_rect()), "Recovery row leaves panel")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Shortcut capture size changed")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Shortcut capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
