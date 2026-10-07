extends "res://tests/headless/RelayFeedbackRegression.gd"

var original_options = {}
var captures = 0
var prefix = "res://docs/playtests/2026-10-07/relay-feedback/preview"


func _prepare_display():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
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


func _review(label):
	root.size = Vector2i(1280, 720)
	var was_paused = paused
	if not was_paused:
		game.hud._toggle_pause()
	var button = game.hud._relay_buttons[0]
	var before = game.simulation_time
	var relay = game.map.relays[0]
	var progress = relay.progress
	var pressed = [false]
	button.pressed.connect(func(): pressed[0] = true, CONNECT_ONE_SHOT)
	await _frames(5)
	if captures % 2 == 0:
		var motion = InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		root.push_input(motion, true)
		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = motion.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	else:
		button.grab_focus()
		for down in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	await _frames(5)
	_check(pressed[0], "Relay locator did not activate: " + label)
	_check(
		game.simulation_time == before and relay.progress == progress,
		"Locator advanced paused capture"
	)
	var camera = game.get_node("IsometricCamera3D")
	_check(absf(camera.position.x - relay.position.x) < 1, "Locator missed relay")
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Relay panel covers minimap"
	)
	for row in game.hud._relay_labels:
		_check(panel.encloses(row.get_global_rect()), "Relay status leaves panel")
	for view in game.hud._relay_buttons:
		_check(panel.encloses(view.get_global_rect()), "Relay locator leaves panel")
	print("RELAY FEEDBACK INPUT ", label, " panel_bottom=", panel.end.y)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Relay preview dimensions changed")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Relay preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	captures += 1
	if not was_paused:
		game.hud._toggle_pause()
