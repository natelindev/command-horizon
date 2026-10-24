extends "res://tests/headless/UnitInfoTextRegression.gd"

const OUTPUT = "res://art/unit-info-review/"
var captures = 0


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Unit info text preview requires native rendering")
		quit(1)
		return
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language in ["en", "zh_CN"]:
		preferences.restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"language": language,
				"interface_scale": 1.5,
				"master_volume": 0.0,
				"day_cycle": false,
				"weather": 1
			}
		)
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _info_fixture("res://source/match/maps/battlefields/DesertFrontierMap.tscn")
		root.size = Vector2i(1280, 720)
		var squad = [walker]
		for offset in [Vector3(-3, 0, -2), Vector3(3, 0, -2), Vector3(0, 0, 4)]:
			var unit = _info_unit("CombatRobot", review_center + offset)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			squad.append(unit)
		game.hud.select_units(squad)
		site.contested = true
		site._update_presentation()
		var camera = game.get_node("IsometricCamera3D")
		camera.set_position_safely(review_center + Vector3(1, 0, -2))
		camera.set_size_safely(23)
		await _frames(6)
		_assert_hidden()
		for unit in squad:
			_check(not unit._mode_badge.visible, "The repeated Precision labels are visible")
		await _capture_info("ordinary-" + language)
		await _toggle_info()
		_check(diagnostics.visible, "F1 did not show the diagnostic overlay")
		for unit in squad:
			_check(unit._mode_badge.visible, "F1 did not show a Precision diagnostic label")
		await _capture_info("diagnostics-" + language)
		await _toggle_info()
		_assert_hidden()
		for unit in squad:
			_check(not unit._mode_badge.visible, "F1 did not clear the Precision labels")
		await _capture_info("ordinary-restored-" + language)
		commander.free()
		paused = false
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Unit info text preview: %d failures, %d captures" % [errors.size(), captures])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture_info(label):
	Input.warp_mouse(Vector2(1260, 360))
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(1260, 360)
	root.push_input(motion, true)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.get_size() == Vector2i(1280, 720), "Unexpected capture size: " + label)
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	captures += 1
	print("Captured ", label)
