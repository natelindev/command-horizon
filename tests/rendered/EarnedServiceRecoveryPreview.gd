extends "res://tests/headless/EarnedServiceRecoveryRegression.gd"

var capture_prefix = ""
var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Native service recovery timed out")
		quit(1)
	return false


func _run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			capture_prefix = arg.trim_prefix("--captures=")
	if capture_prefix == "":
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	await _earned_service()
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Service recovery native: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_earned_service(label):
	game.hud.pause_after_load()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(tank.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	(engineer if label == "paid-foundation" else tank).get_node("Selection").select()
	await _frames(12)
	var menus = game.find_child("UnitMenus")
	await _frames(8)
	game.fog_of_war._physics_process(0.0)
	_check(
		root.get_visible_rect().encloses(menus.get_global_rect()), "Recovery panel escapes viewport"
	)
	await RenderingServer.frame_post_draw
	var file = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Recovery capture already exists")
	if not FileAccess.file_exists(file):
		root.get_texture().get_image().save_png(file)
	if label != "returned":
		print("NATIVE RECOVERY INPUT: Space after ", label)
		while paused and Time.get_ticks_msec() < deadline:
			await _frames(1)
		_check(not paused, "Missing native Space after " + label)
