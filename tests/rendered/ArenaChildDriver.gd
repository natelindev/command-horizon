extends "res://tests/rendered/LuaEditorPreview.gd"


func _run():
	Engine.max_fps = 60
	create_timer(40).timeout.connect(
		func():
			push_error("Child arena timed out")
			quit(1)
	)
	var main = load("res://source/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	while current_scene == main:
		await process_frame
	var arena = current_scene
	await _settle_window()
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("Globals").options.interface_scale = 1.5
	root.content_scale_factor = 1.5
	await _frames(5)
	await _click(arena._run_button)
	await arena.session.completed
	await _frames(3)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Arena child resolution differs")
	frame.save_png("res://art/skirmish/arena-child-result-720p.png")
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	await _click(_button_named(arena, "Return to editor [Esc]"))


func _settle_window():
	var started = Time.get_ticks_msec()
	var matched_since = -1
	while Time.get_ticks_msec() - started < 6000:
		await process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			matched_since = -1
		elif matched_since < 0:
			matched_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - matched_since > 1800:
			return
	_check(false, "Arena did not settle into windowed mode")
