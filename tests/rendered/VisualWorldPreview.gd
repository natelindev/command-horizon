extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(70)
	await _shot("menu")
	var dialog = root.get_node("Globals").open_settings()
	dialog._tabs.current_tab = 1
	await _frames(10)
	await _shot("graphics-menu")
	dialog._finish(false)
	await _frames(3)
	menu.queue_free()
	await _frames(3)
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var camera_check = game.get_node("IsometricCamera3D")
	camera_check.size_max = 190
	camera_check.set_size_safely(36)
	camera_check.set_position_safely(Vector3(114, 0, 54))
	await _frames(12)
	await _shot("unexplored-enemy")
	var screen = root.get_final_transform() * camera_check.unproject_position(Vector3(114, 0, 54))
	var hidden = root.get_texture().get_image().get_pixelv(Vector2i(screen))
	_check(hidden.r + hidden.g + hidden.b < .03, "Scenic lighting revealed the hidden enemy base")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 190
	camera.set_size_safely(80)
	camera.set_position_safely(Vector3(64, 0, 20))
	await _frames(20)
	await _shot("city-afternoon")
	camera.set_size_safely(46)
	camera.set_position_safely(Vector3(55, 0, 39))
	await _frames(20)
	await _shot("street-afternoon")
	preferences.graphics_shadows = false
	preferences.graphics_ao = false
	preferences.apply()
	await _frames(10)
	await _shot("street-effects-off")
	preferences.graphics_shadows = true
	preferences.graphics_ao = true
	preferences.apply()
	preferences.time_of_day = 1
	preferences.apply()
	await _frames(20)
	await _shot("street-sunset")
	preferences.time_of_day = 2
	preferences.apply()
	await _frames(20)
	await _shot("street-night")
	camera.set_size_safely(80)
	camera.set_position_safely(Vector3(64, 0, 0))
	await _frames(20)
	await _shot("city-night")
	preferences.time_of_day = 0
	preferences.weather = 3
	preferences.apply()
	await _frames(90)
	await _shot("city-rain")
	preferences.graphics_dof = true
	preferences.weather = 4
	preferences.apply()
	await _frames(20)
	await _shot("city-mist-dof")
	var atmosphere = game.get_node("WorldAtmosphere")
	print(
		"Render method: ",
		RenderingServer.get_current_rendering_method(),
		" AO: ",
		atmosphere.environment.ssao_enabled,
		" DOF: ",
		atmosphere.attributes.dof_blur_far_enabled
	)
	game.queue_free()
	await _frames(4)
	for map_name in ["CoastalFoundry", "AlpineRelay", "DesertFrontier"]:
		preferences.time_of_day = 1
		preferences.weather = 1
		preferences.graphics_dof = false
		preferences.apply()
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name, false)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		var map_camera = game.get_node("IsometricCamera3D")
		map_camera.size_max = 190
		map_camera.set_size_safely(104)
		map_camera.set_position_safely(Vector3(64, 0, 45))
		await _frames(15)
		await _shot(map_name.to_lower())
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Visual world preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	# A paused static dialog may skip redraws; explicitly render for capture.
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://art/visual-upgrade")
	)
	root.get_texture().get_image().save_png("res://art/visual-upgrade/" + label + ".png")
	print("Captured ", label)
