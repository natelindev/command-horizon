extends "res://tests/headless/AmbientLifeRegression.gd"


func _initialize():
	Engine.max_fps = 60
	super()


func _freeze_units():
	pass


func _run():
	path = "user://industrial-preview-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	await _frames(30)
	_check(await _menu() == true, "Industrial menu check aborted")
	if "--menu-only" in OS.get_cmdline_user_args():
		options.restore(original)
		print("Industrial menu input: %d failures" % errors.size())
		quit(0 if errors.is_empty() else 1)
		return
	await _create("IndustrialCrossroads")
	await _capture("home-fog", Vector3(21, 0, 48), 42)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture("overview", Vector3(64, 0, 52), 128)
	await _capture("junction", Vector3(64, 0, 49), 52)
	await _capture("workshop", Vector3(52, 0, 36), 26)
	await _capture("office", Vector3(76, 0, 36), 26)
	await _capture("hall-and-ruin", Vector3(64, 0, 66), 48)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await _capture("wide-900p", Vector3(64, 0, 50), 75)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _capture("inspection", Vector3(63, 0, 51), 45)
	if "--inspect" in OS.get_cmdline_user_args():
		await create_timer(45).timeout
	await _close()
	await _create("BrokenFoundryMap")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture("foundry-overview", Vector3(92, 0, 58), 135)
	await _capture("foundry-furnaces", Vector3(133, 0, 57), 62)
	await _close()
	DirAccess.remove_absolute(path)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Industrial menu and preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _menu():
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(menu)
	await _frames(5)
	if "--menu-inspect" in OS.get_cmdline_user_args():
		print("Native industrial menu ready for mouse/keyboard input")
		while menu._get_selected_map_path() != "res://source/match/maps/IndustrialCrossroads.tscn":
			await menu._map_list.item_selected
	else:
		# Deterministic artwork setup; actual mouse/keyboard acceptance uses --menu-inspect.
		menu._map_list.select(4)
		menu._on_map_list_item_selected(4)
	_check(
		menu._get_selected_map_path().ends_with("IndustrialCrossroads.tscn"),
		"Menu failed to select Industrial Crossroads"
	)
	_check(not menu._map_list.get_popup().visible, "Map popup stayed open")
	_check(
		(
			menu._preview.buildings.size() == 6
			and menu._preview.roads.size() == 6
			and menu._preview.relays.size() == 2
			and menu._preview.deposits.size() == 4
		),
		"Preview omitted district features"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/environment/industrial-menu-720p.png"
	)
	if "--menu-inspect" in OS.get_cmdline_user_args():
		await create_timer(12).timeout
	menu.queue_free()
	await _frames(3)
	return true


func _capture(label, point, zoom):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 180
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/environment/industrial-%s.png" % label
	)
