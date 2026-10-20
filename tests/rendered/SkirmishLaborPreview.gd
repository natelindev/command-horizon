extends "res://tests/headless/SkirmishLaborRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 600000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI economy preview timed out")
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


func _review_labor(player, label):
	var human = game._get_human_player()
	human.color = Color("e0ad46")
	player.color = Color("d86965")
	human.get_color_material().albedo_color = human.color
	player.get_color_material().albedo_color = player.color
	var hq = _units(player, "CommandCenter")[0]
	var scouts = _units(human, "Drone")
	if scouts.is_empty():
		for point in [
			hq.position,
			_units(player, "AircraftFactory")[0].position,
			_deposit(hq, "resource_a").position,
			_deposit(hq, "resource_b").position
		]:
			_spawn("Drone", human, point + Vector3(3, 2, 3))
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(30)
	game.hud._toggle_pause()
	_check(game.battlefield.is_observed(human, hq), "AI economy base hidden in preview")
	var clock = game.simulation_time
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(hq.position + Vector3(-5, 0, -5))
	await _frames(10)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "AI economy preview resolution changed")
	frame.save_png("res://art/skirmish/ai-economy-%s.png" % label)
	_check(game.simulation_time == clock, "AI economy preview advanced paused time")
	print("LABOR CAPTURE ", label)
