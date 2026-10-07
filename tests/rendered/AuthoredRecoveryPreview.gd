extends "res://tests/headless/AuthoredRecoveryRegression.gd"


func _run():
	Engine.max_fps = 60
	_load_authoring()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		await _frames(5)
		for mode in ["lua", "visual"]:
			await _authored_service(mode, "Tank")
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered authored recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_authored(unit, mode, label):
	var was_paused = paused
	paused = true
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(unit.position + Vector3(3, 0, 0))
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Authored recovery resolution changed")
	frame.save_png(
		"res://art/skirmish/authored-recovery-%s-%s-%s.png" % [unit.player.faction, mode, label]
	)
	print(
		"AUTHORED CAPTURE ",
		unit.player.faction,
		" ",
		mode,
		" ",
		label,
		" at ",
		game.simulation_time
	)
	paused = was_paused
	return true
