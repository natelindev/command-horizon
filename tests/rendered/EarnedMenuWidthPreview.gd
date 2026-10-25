extends "res://tests/rendered/EarnedServiceRecoveryPreview.gd"


func _review_earned_service(label):
	game.hud.pause_after_load()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(tank.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	(engineer if label == "paid-foundation" else tank).get_node("Selection").select()
	await _frames(12)
	var menus = game.find_child("UnitMenus")
	await _frames(8)
	game.fog_of_war._physics_process(0.0)
	await RenderingServer.frame_post_draw
	var clip = menus._command_bay.get_global_rect()
	for kind in menus._command_buttons:
		var button = menus._command_buttons[kind]
		if not button.visible:
			continue
		print("LIVE WIDTH ", label, " ", kind, " ", button.get_global_rect(), " clip=", clip)
		_check(button.get_global_rect().end.x <= clip.end.x + 1, label + ": clipped " + kind)
	var file = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Width capture already exists")
	if not FileAccess.file_exists(file):
		root.get_texture().get_image().save_png(file)
