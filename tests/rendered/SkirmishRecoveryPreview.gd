extends "res://tests/headless/SkirmishRecoveryRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 360000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI recovery preview timed out")
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


func _review_recovery(label):
	var human = game._get_human_player()
	human.color = Color("e0ad46")
	opponent.color = Color("d86965")
	human.get_color_material().albedo_color = human.color
	opponent.get_color_material().albedo_color = opponent.color
	if _units(human, "Drone").is_empty():
		for point in [Vector3(53, 2, 40), Vector3(64, 2, 43), Vector3(74, 2, 43)]:
			var scout = load(catalog.scene_path("Drone")).instantiate()
			game._setup_and_spawn_unit(scout, Transform3D(Basis(), point), human, false)
			scout.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(30)
	game.hud._toggle_pause()
	var clock = game.simulation_time
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(Vector3(65, 0, 48))
	await _frames(10)
	_check(
		wounded.all(func(unit): return game.battlefield.is_observed(human, unit)),
		"A recovering role is hidden in rendered review"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Recovery preview resolution changed")
	frame.save_png("res://art/skirmish/ai-recovery-%s.png" % label)
	_check(game.simulation_time == clock, "Recovery preview advanced paused time")
	print("RECOVERY CAPTURE ", label)
