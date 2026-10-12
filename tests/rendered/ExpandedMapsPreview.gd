extends "res://tests/headless/ExpandedMapRegression.gd"

const CAPTURES = "res://tmp/expanded-maps/rendered"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.0, "menu_motion": false, "language": "en"})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = "user://expanded-preview-no-preferences.cfg"
	root.add_child(setup)
	current_scene = setup
	for map_name in EXPANDED_MAPS:
		var index = setup._map_paths.find("res://source/match/maps/%s.tscn" % map_name)
		setup._map_list.select(index)
		setup._on_map_list_item_selected(index)
		await _capture(map_name + "-menu")
	setup.queue_free()
	await _frames(5)
	if "--menu-only" not in OS.get_cmdline_user_args():
		for map_name in EXPANDED_MAPS:
			var settings = _settings("bastion", "helix", true)
			settings.map_path = "res://source/match/maps/%s.tscn" % map_name
			game = await _start(settings)
			for player in get_nodes_in_group("players"):
				player.set_process(false)
			game.settings.visibility = 2
			game.fog_of_war.reveal()
			var camera = game.get_node("IsometricCamera3D")
			camera.size_max = 210
			camera.set_size_safely(156)
			camera.set_position_safely(Vector3(game.map.size.x / 2, 0, game.map.size.y / 2))
			await _capture(map_name + "-overview")
			camera.set_size_safely(45)
			var site = game.map.POI_SITES[0].position
			camera.set_position_safely(Vector3(site.x, 0, site.y))
			await _capture(map_name + "-facility")
			game.queue_free()
			await _frames(5)
	options.restore(original)
	print("Expanded map rendered previews saved to ", CAPTURES)
	quit()


func _capture(label):
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CAPTURES.path_join(label + ".png"))
