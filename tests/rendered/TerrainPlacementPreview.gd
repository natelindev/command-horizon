extends "res://tests/headless/TerrainNavRegression.gd"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Terrain placement preview requires a renderer")
		quit(1)
		return
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "interface_scale": 1.0})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _create_match()
	nav = game.navigation.terrain.navigation_map_rid
	_check_placement()
	var human = game._get_human_player()
	human.resource_a = 1000
	human.resource_b = 1000
	var barracks = load("res://source/match/units/Barracks.tscn").instantiate()
	game._setup_and_spawn_unit(barracks, Transform3D(Basis(), Vector3(32, 3, 35)), human, false)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(20)
	var target = Vector3(49, 1.5, 45)
	camera.set_position_safely(target)
	# Reveal the reviewed terrain with an ordinary friendly worker.
	var worker = load("res://source/match/units/Worker.tscn").instantiate()
	game._setup_and_spawn_unit(worker, Transform3D(Basis(), target + Vector3(4, -.5, 0)), human)
	await _frames(20)
	paused = true
	var handler = human.get_node("StructurePlacementHandler")
	var prototype = load("res://source/match/units/AntiGroundTurret.tscn")
	handler._start_structure_placement(prototype)
	handler._set_blueprint_position(camera.unproject_position(target))
	await _frames(5)
	_check(
		handler._calculate_blueprint_position_validity() == handler.BlueprintPositionValidity.VALID,
		"Actual turret blueprint rejects gentle ramp"
	)
	await _capture_placement("gentle-ramp-blueprint")
	var before = Vector2i(human.resource_a, human.resource_b)
	var cost = factions.cost(human, "AntiGroundTurret", true)
	handler._handle_lmb_up_event(null)
	await _frames(5)
	var placed = get_nodes_in_group("units").filter(
		func(unit): return unit.type == "AntiGroundTurret" and unit.position.distance_to(target) < 1
	)
	_check(placed.size() == 1, "Valid ramp click did not place exactly one structure")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== before - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Ramp placement charged the wrong construction cost"
	)
	if placed.size() == 1:
		placed[0].construct(1.0)
	await _frames(5)
	await _capture_placement("gentle-ramp-built")
	handler._start_structure_placement(prototype)
	handler._active_blueprint_node.position = target
	_check(
		(
			handler._calculate_blueprint_position_validity()
			== handler.BlueprintPositionValidity.COLLIDES_WITH_OBJECT
		),
		"Relaxed terrain validation allows overlapping buildings"
	)
	# A 2 m circular footprint demonstrably straddles this plateau lip.
	handler._pending_structure_radius = 2.0
	handler._active_blueprint_node.position = Vector3(56, 3, 20)
	_check(
		handler._calculate_blueprint_position_validity() != handler.BlueprintPositionValidity.VALID,
		"Actual blueprint accepts a cliff crossing"
	)
	before = Vector2i(human.resource_a, human.resource_b)
	handler._handle_lmb_up_event(null)
	_check(
		Vector2i(human.resource_a, human.resource_b) == before,
		"Rejected cliff click spent resources"
	)
	handler._cancel_structure_placement()
	paused = false
	await _close()
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Terrain placement preview: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _capture_placement(label):
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://art/terrain-placement")
	)
	root.get_texture().get_image().save_png("res://art/terrain-placement/%s.png" % label)
