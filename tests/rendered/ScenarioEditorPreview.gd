extends "res://tests/headless/ScenarioEditorRegression.gd"

const OUTPUT = "res://art/scenario-editor/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ScenarioEditorPreview needs a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for language in ["en", "zh_CN"]:
		print("Scenario preview: ", language)
		options.restore({"screen": 1, "interface_scale": 1.5, "language": language})
		root.mode = Window.MODE_WINDOWED
		await _frames(3)
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		set_meta("scenario_editor_draft", Document.blank())
		var editor = load("res://source/scenario/ScenarioEditor.tscn").instantiate()
		root.add_child(editor)
		print("Editor ready")
		current_scene = editor
		await _frames(15)
		editor._select_tool("sandstone")
		var click = (
			editor._surface.global_position + editor._camera.unproject_position(Vector3(43, 0, 49))
		)
		var motion = InputEventMouseMotion.new()
		motion.position = click
		root.push_input(motion, true)
		await _frames(2)
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = click
			event.pressed = pressed
			root.push_input(event, true)
			await _frames(2)
		_check(editor.document.items.size() == 5, "Actual canvas mouse click did not place a piece")
		editor._select_tool("container")
		_check(editor.place_at(Vector3(55, 0, 40)), "Rendered container placement failed")
		editor._select_tool("select")
		editor.place_at(Vector3(43, 0, 49))
		await _frames(8)
		_check(editor._selection >= 0, "Rendered canvas selection failed")
		if language == "zh_CN":
			_check(
				editor._tool_buttons.sandstone.text == "砂岩台地", "Chinese palette was not imported"
			)
		for node in editor.find_children("*", "Control", true, false):
			if (
				node.is_visible_in_tree()
				and (node is Button or node is SpinBox or node is LineEdit)
			):
				_check(
					editor.get_global_rect().grow(1).encloses(node.get_global_rect()),
					"Editor control outside720p: " + str(node.get_path())
				)
		await _capture(language)
		if language == "en":
			editor._play()
			await _frames(200)
			game = current_scene
			_check(
				game != null and game.has_method("_get_human_player"),
				"Editor Play did not launch a battle"
			)
			if game != null and game.has_method("_get_human_player"):
				_check(game.settings.map_path == Document.MAP, "Editor launched the wrong map")
				_check(
					game.map.interior_obstacles.size() == 2, "Editor Play lost the placed pieces"
				)
				game.queue_free()
		else:
			editor.queue_free()
		await _frames(6)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Scenario editor preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture(language: String):
	root.mode = Window.MODE_WINDOWED
	await _frames(3)
	root.size = Vector2i(1280, 720)
	await _frames(12)
	RenderingServer.force_draw(false)
	var picture = root.get_texture().get_image()
	_check(picture.get_size() == Vector2i(1280, 720), "Scenario capture is not720p")
	_check(picture.save_png(OUTPUT + language + ".png") == OK, "Scenario capture failed")
	print("Captured editor ", language)
