extends "res://tests/headless/SkirmishOffenseRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI offense preview timed out")
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
	await super()
	options.restore(original)


func _review_wave(region, departures):
	if departures.is_empty():
		return
	var tank = departures[0]
	# A staged reconnaissance position reveals the departing enemy formation.
	# The archived army's orders and positions are not changed for the capture.
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.position = tank.global_position_yless + Vector3(0, 2, 6)
	scout.issue_manual_order(null)
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	await _frames(30)
	game.hud._toggle_pause()
	var clock_before = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	scout.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(tank.global_position_yless + Vector3(8, 0, 0))
	await _frames(10)
	_check(game.battlefield.is_observed(scout.player, tank), "Departing army hidden in preview")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Offense preview resolution changed")
	frame.save_png("res://art/skirmish/ai-offense-%s-departure.png" % region)
	_check(game.simulation_time == clock_before, "Offense preview advanced paused time")
	print("OFFENSE CAPTURE ", region)
	game.hud._toggle_pause()
