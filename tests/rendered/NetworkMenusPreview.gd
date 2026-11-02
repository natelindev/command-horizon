extends "res://tests/headless/FactionAsymmetryRegression.gd"

const OUTPUT = "res://art/network-platform/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Network menu preview requires a renderer")
		quit(1)
		return
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language in ["en", "zh_CN"]:
		options.restore(
			{"screen": 1, "interface_scale": 1.5, "language": language, "edge_scrolling": false}
		)
		await create_timer(.5).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for scene_name in ["Main", "Multiplayer", "Replays"]:
			var scene = load("res://source/main-menu/%s.tscn" % scene_name).instantiate()
			root.add_child(scene)
			current_scene = scene
			await _frames(12)
			await _window()
			var rect = Rect2(Vector2.ZERO, root.get_visible_rect().size)
			var buttons = scene.find_children("*", "Button", true, false).filter(
				func(button): return button.is_visible_in_tree()
			)
			for button in buttons:
				_check(
					rect.encloses(button.get_global_rect()),
					scene_name + " button escapes 720p: " + button.text
				)
				_check(
					button.focus_mode == Control.FOCUS_ALL,
					scene_name + " keyboard focus missing: " + button.text
				)
			if scene_name == "Main":
				_check(
					(
						scene.find_child("Multiplayer", true, false) != null
						and scene.find_child("Replays", true, false) != null
						and scene.find_child("ScenarioEditor", true, false) != null
					),
					"Main menu omits a platform entry"
				)
				if language == "zh_CN":
					_check(
						scene.find_child("Multiplayer", true, false).text == "多人对战",
						"Multiplayer entry localization differs"
					)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				OUTPUT + language + "-" + scene_name.to_lower() + ".png"
			)
			scene.queue_free()
			await _frames(5)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Network main/lobby/replay menus at 720p 150%% EN/ZH: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _window():
	var deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await _frames(4)
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().get_size() == Vector2i(1280, 720):
			return
	_check(false, "720p native window did not settle")
