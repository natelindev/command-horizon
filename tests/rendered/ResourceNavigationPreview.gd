extends "res://tests/headless/ResourceNavigationRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	moving = load("res://source/match/units/actions/Moving.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var settings = _settings("bastion", "helix", false)
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(90)
	var left = _deposit("A", Vector3(30, 0, 25))
	var right = _deposit("B", Vector3(32.5, 0, 25))
	var worker = _spawn("Worker", Vector3(31.25, 0, 20))
	worker.sight_range = 10
	game.battlefield.invalidate()
	await _frames(120)
	worker.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(31.25, 0, 25))
	camera.set_size_safely(18)
	print("Native resource route ready")
	var captured = false
	for direction in [1, -1, 1]:
		var destination = Vector3(31.25, 0, 25 + 5 * direction)
		worker.issue_manual_order(moving.new(destination))
		for frame in 1200:
			await physics_frame
			if not captured and absf(worker.position.x - 31.25) > 1.5:
				await _capture("resource-clearance-route")
				captured = true
			if worker.position.distance_to(destination) < .4:
				break
		_check(worker.position.distance_to(destination) < .4, "Native resource transit stalled")
	var before = human.resource_b
	worker.issue_manual_order(harvest.new(right))
	await _frames(300)
	await _capture("resource-clearance-harvest")
	for frame in 3600:
		await physics_frame
		if human.resource_b >= before + 4:
			break
	_check(human.resource_b >= before + 4, "Native electronics return stalled")
	print("Native resource route and cargo verified: ", _errors.is_empty())
	left.queue_free()
	right.queue_free()
	game.queue_free()
	await _frames(5)
	options.restore(original)
	quit(0 if _errors.is_empty() else 1)


func _capture(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % label)
