extends "res://tests/headless/SkirmishCoordinationRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 360000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI coordination preview timed out")
		quit(1)
	return false


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	var options = root.get_node("Globals").options
	var original = options.capture()
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	for faction in ["bastion", "helix"]:
		await _fixture(faction, 2)
		for point in [
			Vector3(90, 2, 75),
			Vector3(65, 2, 50),
			Vector3(20, 2, 25),
			Vector3(75, 2, 73),
			Vector3(55, 2, 36)
		]:
			_actor("Drone", human, point)
		game.battlefield.invalidate()
		await _live_roles(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	saves.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Coordination preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_task_state(label):
	human.color = Color("e0ad46")
	opponent.color = Color("d86965")
	human.get_color_material().albedo_color = human.color
	opponent.get_color_material().albedo_color = opponent.color
	var point = Vector3(90, 0, 76) if label.ends_with("advance") else Vector3(55, 0, 40)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(36 if label.ends_with("advance") else 48)
	camera.set_position_safely(point)
	paused = false
	await _frames(30)
	paused = true
	var clock = game.simulation_time
	await _frames(10)
	if label.ends_with("advance"):
		var visible = actors.any(
			func(unit):
				return (
					unit.movement_speed > 0
					and unit.position.distance_to(point) < 22
					and game.battlefield.is_observed(human, unit)
				)
		)
		_check(visible, "Coordination advance has no visible local actors")
	else:
		# Capturers can already have joined the next task; inspect its ownership.
		var captured = game.map.relays.any(
			func(relay):
				return relay.captured_by == opponent and relay.position.distance_to(point) < 22
		)
		_check(captured, "Coordination review has no local captured relay")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Coordination preview resolution changed")
	frame.save_png("res://art/skirmish/ai-coordination-%s.png" % label)
	_check(game.simulation_time == clock, "Coordination capture advanced paused time")
	paused = false
	print("COORDINATION CAPTURE ", label)
