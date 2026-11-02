extends "res://tests/headless/MacroEconomyRegression.gd"

const OUTPUT = "res://art/economy/depletion/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Resource depletion preview requires a renderer")
		quit(1)
		return
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	var settings = _settings("bastion", "helix", false)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	settings.visibility = settings.Visibility.FULL
	game = await _start(settings)
	game.set_physics_process(false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for node in get_nodes_in_group("resource_units"):
		node.queue_free()
	await _frames(6)
	var piles = []
	for kind in ["A", "B"]:
		var node = load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
		node.position = Vector3(24 if kind == "A" else 29, 0, 25)
		game.map.get_node("Resources").add_child(node)
		piles.append(node)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(7.5)
	camera.set_position_safely(Vector3(26.5, 0, 25))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for stock in [600, 300, 150, 60]:
		piles[0].resource_a = stock
		piles[1].resource_b = stock
		await _frames(12)
		for pile in piles:
			_check(
				is_equal_approx(pile.radius, .6),
				"Depletion changed the actual navigation footprint"
			)
			_check(
				pile.get_node("Geometry").get_child_count() == (5 if stock == 600 else 1),
				"Depletion duplicated or retained obsolete pile geometry"
			)
		await RenderingServer.frame_post_draw
		var pixels = root.get_texture().get_image()
		_check(pixels.save_png(OUTPUT + "%d.png" % stock) == OK, "Could not save depletion stage")
		print("Captured finite material/electronics stock ", stock)
	game.queue_free()
	await _frames(6)
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Resource depletion preview: 4 stages, %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
