extends "res://tests/headless/TerrainSightRegression.gd"

const OUTPUT = "res://art/strategic-polish/"
var _captures = 0


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("StrategicPolishPreview requires a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"interface_scale": 1.0,
			"language": "en",
			"day_cycle": false,
			"weather": 1,
			"time_of_day": 0
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _create_match()
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var subjects = []
	for index in 3:
		var unit = _spawn_unit("Tank", game._get_human_player(), Vector3(43 + index * 3, 3, 24))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.experience = [100, 300, 600][index]
		unit.hp = unit.hp_max * .7
		subjects.append(unit)
	game.hud.select_units(subjects)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(46, 3, 24))
	camera.set_size_safely(24)
	await _frames(30)
	await _capture("veterancy-tactical")
	camera.set_size_safely(10)
	await _capture("veterancy-close")
	game.queue_free()
	await _frames(5)
	for language in ["en", "zh_CN"]:
		options.restore({"screen": 1, "language": language, "interface_scale": 1.5})
		await _frames(5)
		root.size = Vector2i(1280, 720)
		await _first_orders()
		await _capture("first-orders-economy-" + language)
		game.phase = 1
		await _frames(20)
		await _capture("first-orders-direct-orders-" + language)
		game.phase = 2
		var tanks = game._get_human_player().get_children().filter(
			func(unit): return "type" in unit and unit.type == "Tank"
		)
		tanks[0].hp = tanks[0].hp_max * .4
		await _frames(20)
		await _capture("first-orders-recovery-" + language)
		var panel = game.hud.lesson_panel.get_global_rect()
		_check(
			panel.end.y <= root.get_visible_rect().size.y - 246.0,
			"Introductory lesson overlaps minimap: " + language
		)
		_check(
			not panel.intersects(game.find_child("UnitMenus", true, false).get_global_rect()),
			"Introductory lesson overlaps unit controls: " + language
		)
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Strategic polish preview: %d failures, %d captures" % [_errors.size(), _captures])
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _first_orders():
	var settings = _settings("bastion", "helix", false)
	settings.mission_id = "first_orders"
	settings.map_path = "res://source/match/maps/FirstOrdersMap.tscn"
	game = load("res://source/match/campaign/FirstOrders.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = "user://polish-preview-%d.json" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(40)
	game.campaign_story.skip_briefing()
	game.campaign_story.skip_dialogue()
	game.set_physics_process(false)
	game.hud._find_unit()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(16, 0, 19))
	camera.set_size_safely(24)
	root.size = Vector2i(1280, 720)
	await _frames(20)


func _capture(label):
	await _frames(6)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	if label.begins_with("first-orders-"):
		_check(pixels.get_size() == Vector2i(1280, 720), "Lesson capture is not 1280×720: " + label)
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_captures += 1
	print("Captured ", label)
