extends "res://tests/playtest/HorizonDifficultyMatches.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await super()
	options.restore(original)


func _stage_capture(title, point):
	root.size = Vector2i(1280, 720)
	var was_paused = paused
	if not paused:
		game.hud._toggle_pause()
	game.get_node("IsometricCamera3D").set_position_safely(point)
	await _frames(6)
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"North-route objective panel covers minimap"
	)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel), "North-route panel clips")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "North-route frame has wrong dimensions")
	var destination = evidence_prefix + "-" + title + ".png"
	_check(not FileAccess.file_exists(destination), "North-route capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	if not was_paused:
		game.hud._toggle_pause()
