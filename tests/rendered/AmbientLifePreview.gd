extends "res://tests/headless/AmbientLifeRegression.gd"


func _initialize():
	Engine.max_fps = 60
	super()


func _run():
	path = "user://ambient-preview-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	await _create("CommandHorizonMap")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.map.get_node("AmbientLife").refresh_visibility()
	game.hud.hide()
	await _capture("horizon-street", Vector3(51, 0, 58), 37)
	await _capture("resident-walk", Vector3(51, 0, 39), 18)
	await _capture("fox-trail", Vector3(36, 0, 108), 17)
	await _capture("car-detail", Vector3(51, 0, 66), 18)
	if "--inspect" in OS.get_cmdline_user_args():
		var camera = game.get_node("IsometricCamera3D")
		camera.set_position_safely(Vector3(51, 0, 57))
		camera.set_size_safely(34)
		await create_timer(30).timeout
	if "--clip" in OS.get_cmdline_user_args():
		var camera = game.get_node("IsometricCamera3D")
		camera.set_position_safely(Vector3(51, 0, 57))
		camera.set_size_safely(34)
		DirAccess.make_dir_recursive_absolute("/tmp/ambient-frames")
		for index in 180:
			await _frames(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/ambient-frames/%04d.png" % index)
	await _close()
	await _create("BrokenFoundryMap")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.hud.hide()
	await _capture("foundry-street", Vector3(53, 0, 32), 35)
	await _close()
	await _create("AlpineRelay")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.hud.hide()
	await _capture("alpine-wildlife", Vector3(32, 0, 18), 23)
	await _close()
	options.restore(original)
	DirAccess.remove_absolute(path)
	print("Ambient preview complete")
	quit()


func _capture(label, point, camera_size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(camera_size)
	camera.set_position_safely(point)
	await _frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/environment/ambient-%s.png" % label)
