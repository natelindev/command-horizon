extends "res://tests/playtest/FoundryDifficultyMatches.gd"

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


func _restore_display():
	root.get_node("Globals").options.restore(original_options)


func _stage_capture(label, point):
	var was_paused = paused
	if not was_paused:
		game.hud._toggle_pause()
	root.size = Vector2i(1280, 720)
	game.get_node("IsometricCamera3D").set_position_safely(point)
	await _frames(6)
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Foundry battle panel covers minimap"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Foundry battle dimensions changed")
	var destination = evidence_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Foundry battle would overwrite capture")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	if not was_paused:
		game.hud._toggle_pause()
