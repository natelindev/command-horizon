extends "res://tests/headless/BaseAccessRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Base access preview timed out")
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
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	await _rebuild_archived_turret()
	saves.autosaves_enabled = autosaves
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered base access: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_traffic(_worker, label):
	var was_paused = paused
	paused = true
	# These are spatial diagnostics of the opponent's base, with the HUD
	# hidden so spectator resource bars do not cover the layout comparison.
	game.get_node("HUD").hide()
	game.hud.hide()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(26)
	camera.set_position_safely(Vector3(112, 0, 63))
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Base review resolution changed")
	frame.save_png("res://art/skirmish/%s.png" % label)
	print("BASE CAPTURE ", label, " at ", game.simulation_time)
	paused = was_paused
	return true
