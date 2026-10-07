extends "res://tests/playtest/SplitClearanceRecovery.gd"

var original_options = {}


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


func _review_recovery(label):
	root.size = Vector2i(1280, 720)
	if label == "loaded":
		var button = game.hud._relay_buttons[0]
		var motion = InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		root.push_input(motion, true)
		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = motion.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)
			await _frames(3)
		_check(
			"Clear contested relays" in game.hud._objective.text,
			"Earned battle lacks clearance hint"
		)
	await _frames(8)
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Earned relay panel covers minimap"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Recovery frame dimensions changed")
	var destination = evidence_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Recovery capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
