extends "res://tests/headless/CrowdBoundaryRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Crowd boundary preview timed out")
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
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	await _archived_traffic(0)
	for faction in ["bastion", "helix"]:
		await _paired_harvesting(faction)
	saves.autosaves_enabled = autosaves
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered crowd boundary: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_traffic(worker, label):
	var was_paused = paused
	if not was_paused:
		await _frames(30)
	paused = true
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(worker.position + Vector3(3, 0, 0))
	if worker.player == game._get_human_player():
		root.get_node("MatchSignals").deselect_all_units.emit()
		worker.get_node("Selection").select()
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Traffic review resolution changed")
	frame.save_png("res://art/skirmish/crowd-%s.png" % label)
	print("CROWD CAPTURE ", label, " at ", game.simulation_time)
	paused = was_paused
	return true
