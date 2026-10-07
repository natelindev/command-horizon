extends "res://tests/headless/CommandHorizonRegression.gd"


func _initialize():
	Engine.max_fps = 60
	super()


func _run():
	path = "user://horizon-environment-preview-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Progress.new().record_foundry_victory(path)
	await _make_match()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 230
	await _capture("base-fog", Vector3(37, 0, 65), 55)
	game.fog_of_war.reveal()
	game.hud.hide()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture("overview", Vector3(92, 0, 66), 185)
	await _capture("pump-and-power", Vector3(69, 0, 90), 58)
	await _capture("service-ruin", Vector3(53, 0, 44), 23)
	await _capture("north-cut", Vector3(115, 0, 24), 42)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await _capture("wide-900p", Vector3(83, 0, 69), 95)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var aircraft = _units(game._get_human_player(), "Helicopter")[0]
	aircraft.position = Vector3(116, 8, 63)
	aircraft.get_node("Movement")._align_unit_position_to_navigation()
	aircraft.get_node("Selection").select()
	aircraft.get_node("AirToTerrainMarker")._process(0)
	await _capture("flight-clearance", Vector3(116, 0, 66), 32)
	game.hud.show()
	if "--inspect" in OS.get_cmdline_user_args():
		await _capture("inspection", Vector3(116, 0, 66), 32)
		game.get_node("RectangularSelection3D").started.connect(
			func(): print("Native selection started")
		)
		game.get_node("RectangularSelection3D").finished.connect(_native_selection)
		await create_timer(90).timeout
	await _close()
	DirAccess.remove_absolute(path)
	options.restore(original)
	print("Horizon environment preview complete")
	quit()


func _capture(label, point, camera_size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(camera_size)
	camera.set_position_safely(point)
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/environment/horizon-%s.png" % label)


func _native_selection(polygon):
	await process_frame
	print(
		"Native selection finished: ",
		polygon,
		" selected=",
		get_nodes_in_group("selected_units").size()
	)
