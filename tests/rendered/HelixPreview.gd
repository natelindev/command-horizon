extends SceneTree

var _scene = null


func _initialize():
	call_deferred("_run")


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var buttons = menu.find_child("VBoxContainer").get_children()
	assert(buttons[0].text == "SKIRMISH")
	assert(buttons[2].text == "HELIX MODEL REVIEW")
	buttons[2].pressed.emit()
	await process_frame
	await process_frame
	_scene = current_scene
	assert(_scene.scene_file_path == "res://source/showcase/HelixShowcase.tscn")
	_scene._rotation_enabled = false
	for roster in [_scene.UNITS, _scene.STRUCTURES]:
		_scene._show_roster(roster)
		for asset in roster:
			_scene._select(asset)
			assert(is_instance_valid(_scene._model))
			assert(_scene._title.text == roster[asset][0])
			assert(not _scene._model.find_children("*", "MeshInstance3D", true, false).is_empty())
			await process_frame
			await process_frame
			if asset in ["NeedleSkimmer", "SignalLab", "RoboticsFoundry", "KiteScout"]:
				await RenderingServer.frame_post_draw
				var screenshot = root.get_texture().get_image()
				screenshot.resize(1440, 900)
				screenshot.save_png("res://art/helix/v1/godot-%s.png" % asset)
	var old_color = _scene._team_material.albedo_color
	_scene._change_team()
	assert(_scene._team_material.albedo_color != old_color)
	_scene._back()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://source/main-menu/Main.tscn")
	current_scene.queue_free()
	await process_frame
	print("PASS: all 17 Helix GLBs, menu navigation, Godot renders and team-color switching")
	quit()
