extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for language in ["zh_CN", "en"]:
		preferences.language = language
		preferences.apply()
		for scene_name in ["Main", "World", "Play", "Campaign"]:
			var scene = load("res://source/main-menu/%s.tscn" % scene_name).instantiate()
			root.add_child(scene)
			current_scene = scene
			await _frames(70)
			_shot(language + "-" + scene_name.to_lower())
			if scene_name == "Main":
				var dialog = root.get_node("Globals").open_settings()
				await _frames(5)
				_shot(language + "-settings")
				dialog._finish(false)
				await _frames(3)
			scene.queue_free()
			await _frames(3)
	preferences.language = "zh_CN"
	preferences.apply()
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var worker = _units(game._get_human_player(), "Worker")[0]
	worker.get_node("Selection").select()
	await _frames(10)
	_shot("zh_CN-battle")
	game.queue_free()
	await _frames(5)
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	tank.get_node("Selection").select()
	await _frames(8)
	_shot("zh_CN-program")
	game.hud.open_technology()
	await _frames(8)
	_shot("zh_CN-technology")
	game.hud._close_menu()
	await _frames(3)
	game.hud.open_visual_editor([tank], "user://preview-program-library.json")
	await _frames(8)
	_shot("zh_CN-rules")
	game.hud.program_editor.close_editor()
	await _frames(3)
	var saves = root.get_node("SaveManager")
	await saves.open_dialog("save")
	await _frames(8)
	_shot("zh_CN-archive")
	saves.close_dialog()
	await _frames(3)
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	print("World and language preview complete")
	quit()


func _shot(label):
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://art/localization/" + label + ".png")
	print("Captured ", label)
