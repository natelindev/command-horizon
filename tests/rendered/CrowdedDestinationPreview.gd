extends "res://tests/headless/CrowdedDestinationRegression.gd"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	var unit = await _open_capture()
	if unit != null:
		await _capture(unit, "before")
		var hp = unit.hp
		var start = unit.position
		paused = false
		await _frames(240)
		_check(
			not unit.get_node("Movement")._has_destination,
			"Rendered Move kept pushing into its blocked endpoint"
		)
		_check(unit.hp > hp, "Rendered infantry did not start treatment")
		_check(unit.position.distance_to(start) < 1, "Rendered arrival changed destinations")
		await _capture(unit, "healing")
		print("RENDERED ARRIVAL hp=", hp, " -> ", unit.hp)
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered crowded destination: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(unit, label):
	paused = true
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(17)
	camera.set_position_safely(Vector3(21, 0, 23))
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Arrival preview resolution changed")
	frame.save_png("res://art/skirmish/crowded-destination-%s.png" % label)
