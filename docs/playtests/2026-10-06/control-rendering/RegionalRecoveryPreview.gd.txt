extends "res://tests/headless/RegionalRecoveryContinuation.gd"

var captures = ""


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _review(label, tank):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(tank.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	await _frames(15)
	var menus = game.find_child("UnitMenus")
	_check(root.get_visible_rect().encloses(menus.get_global_rect()), "Patient menu overflow")
	var clip = menus._scroll.get_global_rect()
	if menus._scroll.get_v_scroll_bar().visible:
		clip.size.x -= menus._scroll.get_v_scroll_bar().size.x
	for kind in menus._command_buttons:
		var button = menus._command_buttons[kind]
		_check(button.get_global_rect().end.x <= clip.end.x + 1, label + ": clipped " + kind)
	print(
		"EARNED WIDTH ",
		label,
		" content=",
		menus._content.size,
		" minimum=",
		menus._content.get_combined_minimum_size(),
		" clip=",
		clip
	)
	if captures != "":
		await RenderingServer.frame_post_draw
		var file = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(file), "Capture already exists")
		if not FileAccess.file_exists(file):
			root.get_texture().get_image().save_png(file)


func _resume():
	get_root().gui_release_focus()
	for pressed in [true, false]:
		var key = InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		root.push_input(key, true)
		await _frames(1)
	_check(not paused, "Space did not resume the earned battle")
