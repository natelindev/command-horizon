extends "res://tests/headless/IndustrialPinchRegression.gd"

var captures = ""


func _run():
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	for trial in 2:
		case_label = "archive-%d" % trial
		await _open_pinch()
		if trial == 1:
			await _pinch_reload(12)
		await _complete_pinch()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered Industrial pinch: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_traffic(label):
	# Match restoration reapplies window settings; establish the review size
	# after each load, before drawing and checking the captured framebuffer.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var was_paused = paused
	game.hud.pause_after_load()
	var clock = game.simulation_time
	var units = watched.filter(func(unit): return is_instance_valid(unit) and unit.hp > 0)
	var actions = units.map(func(unit): return unit.action)
	var player = game._get_human_player()
	var funds = Vector2i(player.resource_a, player.resource_b)
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(22)
	camera.set_position_safely(Vector3(14, 0, 54))
	await _frames(12)
	_check(paused and game.simulation_time == clock, "Traffic review advanced simulation")
	_check(units.map(func(unit): return unit.action) == actions, "Traffic selection changed orders")
	_check(Vector2i(player.resource_a, player.resource_b) == funds, "Traffic review changed funds")
	if captures != "":
		await RenderingServer.frame_post_draw
		_check(
			root.get_texture().get_image().get_size() == Vector2i(1280, 720),
			"Traffic review resolution changed"
		)
		var path = "%s-%s-%s.png" % [captures, case_label, label]
		_check(not FileAccess.file_exists(path), "Traffic review would replace prior evidence")
		if not FileAccess.file_exists(path):
			root.get_texture().get_image().save_png(path)
	if not was_paused:
		game.hud._toggle_pause()
