extends SceneTree

# Shared helpers for rendered previews that build their own fixture.
var _game
var _path
var _errors = []


func _initialize():
	call_deferred("_run")


func _run():
	push_error("PreviewFixture is a base script; run a preview that extends it.")
	quit(1)


func _capture(title):
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _frames(count):
	for frame in range(count):
		await process_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)


func _prepare_720p():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(8)
	_check(root.size == Vector2i(1280, 720), "Preview window did not settle at 720p")
	return original


func _button_named(node, text):
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _button_named(child, text)
		if found != null:
			return found
	return null


func _click(button):
	_check(is_instance_valid(button), "UI button missing")
	if not is_instance_valid(button):
		return
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(3)


func _key(code, unicode_value = 0):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		root.push_input(event, true)
