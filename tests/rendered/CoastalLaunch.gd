extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	var config_path = "user://skirmish.cfg"
	var existed = FileAccess.file_exists(config_path)
	var previous = FileAccess.get_file_as_bytes(config_path) if existed else PackedByteArray()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._map_list.select(5)
	menu._on_map_list_item_selected(5)
	menu._start_mode.select(0)
	menu._update_summary()
	print("Native Coastal launch ready")
	await menu.tree_exited
	while not is_instance_valid(current_scene) or not ("simulation_time" in current_scene):
		await physics_frame
	var game = current_scene
	for frame in 60:
		await physics_frame
	var valid = (
		game.settings.map_path.ends_with("CoastalFoundry.tscn")
		and not game.settings.advanced_start
		and game.map.overview().land.size() == 14
		and game.map.get_node("AmbientLife").actors.size() == 13
	)
	print("Native Coastal launch verified: ", valid)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/environment/coastal-native-launch.png"
	)
	await create_timer(20).timeout
	game.queue_free()
	await process_frame
	if existed:
		var file = FileAccess.open(config_path, FileAccess.WRITE)
		file.store_buffer(previous)
	else:
		DirAccess.remove_absolute(config_path)
	options.restore(original)
	quit(0 if valid else 1)
