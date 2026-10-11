extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore(
		{"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1, "time_of_day": 0}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.position = (
			Vector3(115, 0, 100) if unit.player != game._get_human_player() else Vector3(7, 0, 100)
		)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var catalog = load("res://source/match/BastionCatalog.gd")
	var human = game._get_human_player()
	var structures = []
	for index in catalog.STRUCTURES.size():
		var role = catalog.STRUCTURES[index]
		var unit = load(catalog.scene_path(role)).instantiate()
		var point = Vector3(15 + (index % 3) * 7, 0, 34 + (index / 3) * 7)
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
		structures.append(unit)
	var worker = _units(human, "Worker")[0]
	worker.position = Vector3(14, 0, 29)
	root.get_node("MatchSignals").deselect_all_units.emit()
	worker.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 190
	camera.set_size_safely(30)
	camera.set_position_safely(Vector3(22, 0, 41))
	await _frames(25)
	await _shot("in-game-roster")
	root.get_node("MatchSignals").deselect_all_units.emit()
	camera.set_size_safely(17)
	camera.set_position_safely(Vector3(18, 0, 35))
	await _frames(12)
	await _shot("fortress-and-barracks")
	camera.set_position_safely(Vector3(25, 0, 42))
	await _frames(12)
	await _shot("reactor-and-radar")
	var site = load(catalog.scene_path("VehicleFactory")).instantiate()
	game._setup_and_spawn_unit(site, Transform3D(Basis(), Vector3(20, 0, 56)), human, true)
	await _frames(3)
	site.get_node("Selection").select()
	camera.set_position_safely(Vector3(20, 0, 56))
	await _frames(12)
	await _shot("foundation")
	_check(site.hp == 80, "Vehicle factory does not start at 80 HP")
	root.get_node("MatchSignals").deselect_all_units.emit()
	camera.set_size_safely(64)
	camera.set_position_safely(Vector3(64, 0, 0))
	await _frames(12)
	await _shot("civilian-industry")
	preferences.restore(original)
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Bastion structures preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://art/bastion/structures-v2/" + label + ".png")
	print("Captured ", label)
