extends "res://tests/headless/AttackArrivalProgressRegression.gd"

var capture_prefix = ""


func _run():
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	for trial in 2:
		if trial == 1:
			current_case = LATE_CASES[3]
		var unit = await _open_attack()
		if unit == null:
			continue
		await _review(unit, "%d-before" % trial)
		var action = unit.action
		var point = unit.position
		var started = game.simulation_time
		game.hud._toggle_pause()
		var arrived = -1.0
		for frame in 360:
			await physics_frame
			if unit.action != action:
				arrived = game.simulation_time - started
				break
		_check(arrived > 0 and arrived < 6, "Rendered crowded attack did not settle")
		_check(unit.position.distance_to(point) < 1, "Rendered arrival abandoned its location")
		_check(not unit.get_node("Movement")._has_destination, "Rendered arrival retained movement")
		print(
			"RENDERED ARRIVAL ",
			trial,
			" elapsed=",
			arrived,
			" travel=",
			unit.position.distance_to(point)
		)
		await _review(unit, "%d-arrived" % trial)
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered attack arrival progress: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review(unit, label):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.hud.pause_after_load()
	var clock = game.simulation_time
	var action = unit.action
	var funds = Vector2i(unit.player.resource_a, unit.player.resource_b)
	var pending = unit.manual_orders.pending.duplicate(true)
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(22)
	camera.set_position_safely(unit.position)
	await _frames(12)
	_check(paused and game.simulation_time == clock, "Arrival review advanced simulation")
	_check(unit.action == action and unit.manual_orders.pending == pending, "Review changed orders")
	_check(
		Vector2i(unit.player.resource_a, unit.player.resource_b) == funds, "Review changed funds"
	)
	if capture_prefix != "":
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		_check(picture.get_size() == Vector2i(1280, 720), "Arrival review resolution changed")
		var path = "%s-%s.png" % [capture_prefix, label]
		_check(not FileAccess.file_exists(path), "Review would replace prior evidence")
		if not FileAccess.file_exists(path):
			picture.save_png(path)
