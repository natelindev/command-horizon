extends "res://tests/headless/BrokenFoundryRegression.gd"


func _initialize():
	Engine.max_fps = 60
	super()


func _run():
	path = "user://foundry-live-progress-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _make_match()
	await _play_foundry()
	await _stage_capture("foundry-live-result", game.map.CONTROL)
	await _close()
	DirAccess.remove_absolute(path)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Broken Foundry normal-clock playthrough: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _stage_capture(title, point):
	game.get_node("IsometricCamera3D").set_position_safely(point)
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s-720p.png" % title)
