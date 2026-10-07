extends "res://tests/headless/CornerRecoveryRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Corner recovery preview timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	await _open_corner()
	await _review_corner("before")
	await _travel("original")
	await _close()
	await _archive_recovery()
	for faction in ["bastion", "helix"]:
		await _fresh_corner(faction)
		await _travel("fresh-" + faction)
		await _close()
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered corner recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _travel(label):
	if game.hud._pause_owned:
		game.hud._toggle_pause()
	await super(label)


func _review_corner(label):
	var was_paused = paused
	if not was_paused:
		game.hud._toggle_pause()
	_check(paused, "Corner review did not own tactical pause")
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	watched.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(anchor + Vector3(3, 0, 0))
	await _frames(12)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Corner review resolution changed")
	frame.save_png("res://art/skirmish/corner-recovery-%s.png" % label)
	_check(game.simulation_time == clock, "Corner review advanced paused simulation")
	print("CORNER CAPTURE ", label)
	if not was_paused:
		game.hud._toggle_pause()
