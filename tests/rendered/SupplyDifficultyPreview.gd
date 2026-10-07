extends "res://tests/playtest/SupplyConvoyControls.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _make_match():
	await super()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(5)


func _activate_convoy(advance):
	root.size = Vector2i(1280, 720)
	if game.finished:
		return
	game.hud._toggle_pause()
	var before = game.simulation_time
	var button = game.hud._advance if advance else game.hud._hold
	control_activations.append("mouse-advance" if advance else "enter-hold")
	if advance:
		var point = root.get_final_transform() * button.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, false)
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, false)
			await _frames(2)
	else:
		button.grab_focus()
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			root.push_input(event, false)
			await _frames(2)
	_check(paused and game.simulation_time == before, "Convoy input advanced paused time")
	for truck in game.trucks():
		_check(
			truck.get_node("Movement")._has_destination == advance,
			"Convoy button did not apply expected travel state"
		)
	_check(
		game.hud.objective_panel.get_global_rect().encloses(button.get_global_rect()),
		"Convoy button escaped objective panel"
	)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Convoy panel overlaps minimap at large interface scale"
	)
	print("CONVOY INPUT ", control_activations[-1], " at=", before)
	game.hud._toggle_pause()


func _review_stage(stage):
	root.size = Vector2i(1280, 720)
	if not game.finished:
		game.hud._toggle_pause()
	game.get_node("IsometricCamera3D").set_position_safely(game.map.POINTS[stage])
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Convoy preview resolution changed")
	var destination = evidence_prefix + "-stage-%d.png" % stage
	_check(not FileAccess.file_exists(destination), "Convoy preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	if not game.finished:
		game.hud._toggle_pause()
