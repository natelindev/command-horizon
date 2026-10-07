extends "res://tests/headless/AlpineRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _skirmish("bastion", ALPINE)
	game.settings.visibility = 2
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 150
	camera.set_size_safely(106)
	camera.set_position_safely(Vector3(64, 0, 52))
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/alpine-overview-bastion.png")
	camera.set_size_safely(36)
	camera.set_position_safely(Vector3(64, 0, 36))
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/alpine-pass-720p.png")
	game.queue_free()
	await _frames(5)
	quit()
