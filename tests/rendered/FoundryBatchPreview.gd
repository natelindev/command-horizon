extends "res://tests/headless/FoundryBatchRegression.gd"

var original_options = {}
var activations = 0


func _prepare_display():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)


func _restore_display():
	root.get_node("Globals").options.restore(original_options)


func _review(label):
	root.size = Vector2i(1280, 720)
	# Controlled production UI fixture: reveal scenery for context, not observation evidence.
	game.fog_of_war.reveal()
	await _frames(6)
	var row = game.hud._node_labels[0].get_parent()
	var button = row.get_children().filter(func(child): return child is Button)[0]
	var activated = [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	activations += 1
	if activations % 2 == 0:
		button.grab_focus()
		for down in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	else:
		var point = button.get_global_rect().get_center()
		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	_check(activated[0] and paused, "Production locator input failed or resumed battle")
	var hover = InputEventMouseMotion.new()
	hover.position = game.hud._node_labels[0].get_global_rect().get_center()
	root.push_input(hover, true)
	await create_timer(1).timeout
	var tip = game.hud._node_labels[0].tooltip_text
	if not tip.is_empty():
		_check(_tooltip_visible(root, tip), "Waiting tooltip is not visible through real hover")
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Waiting panel covers minimap"
	)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel), "Waiting panel clips")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Waiting frame dimensions changed")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Waiting capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	print("FOUNDRY BATCH UI ", label)


func _tooltip_visible(node, text):
	if (
		node is Label
		and node.text == text
		and node.is_visible_in_tree()
		and node.get_window().visible
	):
		return true
	for child in node.get_children(true):
		if _tooltip_visible(child, text):
			return true
	return false
