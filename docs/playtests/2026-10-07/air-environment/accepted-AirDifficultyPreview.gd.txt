extends "res://tests/playtest/AirDifficultyMatches.gd"

var launch_clicks = 0


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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1280, 720)


func _launch_air():
	game.hud._toggle_pause()
	var before = game.simulation_time
	await _activate(game.hud._launch, launch_clicks % 2 == 0)
	launch_clicks += 1
	var active = game.flights.filter(func(flight): return flight.state == "flying")
	_check(active.size() == 1, "Rendered launch failed")
	_check(paused and game.simulation_time == before, "Launch advanced paused time")
	if launch_clicks == 1 and active.size() == 1:
		active[0].unit.issue_manual_order(null)
		await _frames(3)
		var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new().capture(game)
		var archive = load("res://source/match/saves/SaveFile.gd").new()
		_check(archive.write_file(evidence_prefix + "-held-archive.json", snapshot), archive.error)
		await _stage_capture("held", active[0].unit.global_position_yless)
		await _activate(game.hud._continue, false)
		_check(
			active[0].unit.get_node("Movement")._has_destination, "Continue did not resume flight"
		)
		_check(paused and game.simulation_time == before, "Continue advanced paused time")
		print("AIR INPUT continue-enter at=", before)
	if launch_clicks == 3:
		await _stage_capture("two-safe", game.map.SCREEN)
	print("AIR INPUT launch=", launch_clicks, " at=", before)
	game.hud._toggle_pause()
	return active.size() == 1


func _activate(button, mouse):
	root.size = Vector2i(1280, 720)
	await _frames(3)
	_check(not button.disabled, "Air action unexpectedly disabled")
	if mouse:
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


func _stage_capture(title, point):
	root.size = Vector2i(1280, 720)
	game.get_node("IsometricCamera3D").set_position_safely(point)
	await _frames(5)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Air objectives overlap minimap at 150%"
	)
	for button in [game.hud._launch, game.hud._continue, game.hud._finish]:
		_check(
			game.hud.objective_panel.get_global_rect().encloses(button.get_global_rect()),
			"Air control escaped panel"
		)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Air preview size changed")
	var destination = evidence_prefix + "-" + title + ".png"
	_check(not FileAccess.file_exists(destination), "Air preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
