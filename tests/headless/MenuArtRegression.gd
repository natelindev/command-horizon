extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "menu_motion": false})
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for scale in [1.0, 1.25, 1.5]:
		preferences.interface_scale = scale
		preferences.apply()
		await _frames(5)
		var bounds = root.get_visible_rect()
		for button in menu.find_children("*", "Button", true, false):
			_check(
				bounds.encloses(button.get_global_rect()),
				"Menu action clipped at %s: %s" % [scale, button.text]
			)
	var buttons = menu.find_children("*", "Button", true, false)
	var settings = menu.find_child("Settings", true, false)
	await _click(settings)
	var dialog = root.get_node("Globals").settings_dialog
	_check(is_instance_valid(dialog), "Settings mouse activation failed")
	if is_instance_valid(dialog):
		_check(
			root.get_visible_rect().encloses(dialog._panel.get_global_rect()),
			"Settings clipped at 150%"
		)
		dialog._tabs.current_tab = 1
		await _frames(3)
		var before = preferences.day_cycle
		await _click(dialog.controls.day_cycle)
		_check(preferences.day_cycle != before, "Graphics checkbox did not preview")
		await _key(KEY_ESCAPE)
		_check(
			not is_instance_valid(root.get_node("Globals").settings_dialog),
			"Escape did not close graphics"
		)
		_check(preferences.day_cycle == before, "Escape failed to restore graphics")
	menu.queue_free()
	await _frames(3)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Menu art regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)


func _frames(count):
	for index in count:
		await process_frame


func _click(control):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
