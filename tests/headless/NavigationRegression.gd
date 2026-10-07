extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
var _game
var _moving
var _human
var _errors = []


func _initialize():
	call_deferred("_run")


func _run():
	_moving = load("res://source/match/units/actions/Moving.gd")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440, 900)
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = 2
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	for index in range(2):
		var config = load("res://source/data-model/PlayerSettings.gd").new()
		config.controller = 1 if index == 0 else 2
		config.spawn_index_offset = index
		config.faction = "helix" if index == 0 else "bastion"
		settings.players.append(config)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	_game.get_node("IsometricCamera3D").set_position_safely(Vector3(25, 0, 26))
	for player in get_nodes_in_group("players"):
		if player != _human:
			player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(90)
	await _test_obstacle_route()
	await _test_group_route()
	await _test_harvesting()
	await _test_new_obstacle()
	await _test_construction_and_rocks()
	_game.queue_free()
	await _frames(6)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print("PASS: obstacle routing, crowded movement, harvesting and factory egress")
	quit(0 if _errors.is_empty() else 1)


func _spawn(role, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), _human, false)
	# Isolate navigation from the idle combat stance chasing the enemy HQ.
	if unit.attack_range != null:
		unit.sight_range = 0
	return unit


func _test_obstacle_route():
	var factory = _spawn("VehicleFactory", Vector3(25, 0, 25))
	var tank = _spawn("Tank", Vector3(17, 0, 25))
	await _frames(90)
	var destination = Vector3(33, 0, 25)
	tank.action = _moving.new(destination)
	var min_distance = 100.0
	for _index in range(900):
		await physics_frame
		min_distance = min(
			min_distance, tank.global_position_yless.distance_to(factory.global_position_yless)
		)
	var remaining = tank.global_position_yless.distance_to(destination)
	print("ROUTE: remaining=", remaining, " minimum building distance=", min_distance)
	_check(remaining < 1.5, "Single tank stuck routing around factory")
	_check(min_distance > factory.radius, "Tank cut through factory")
	tank.queue_free()
	await _frames(3)


func _test_group_route():
	var units = []
	for index in range(12):
		units.append(_spawn("Tank", Vector3(9 + (index % 3) * 2.5, 0, 20 + (index / 3) * 2.5)))
	await _frames(60)
	var destinations = root.get_node("Utils").Match.Unit.Movement.crowd_moved_to_new_pivot(
		units, Vector3(37, 0, 25)
	)
	for entry in destinations:
		entry[0].action = _moving.new(entry[1])
	var arrivals = {}
	for _frame in range(1500):
		await physics_frame
		for entry in destinations:
			if entry[0].global_position_yless.distance_to(entry[1]) < 0.6:
				arrivals[entry[0]] = true
	for entry in destinations:
		if not arrivals.has(entry[0]):
			var movement = entry[0].get_node("Movement")
			print(
				"Crowd arrival missing: ",
				entry[0].position,
				" goal ",
				entry[1],
				" active ",
				movement._has_destination,
				" path ",
				movement.get_current_navigation_path(),
				" index ",
				movement.get_current_navigation_path_index()
			)
	var reached = arrivals.size()
	print("GROUP: reached=", reached, "/", units.size())
	_check(reached == units.size(), "Crowded tank group failed to reach destinations")
	await _capture()
	for unit in units:
		unit.queue_free()
	await _frames(6)


func _test_harvesting():
	var workers = []
	var deposits = get_nodes_in_group("resource_units").filter(
		func(node): return "resource_a" in node
	)
	deposits.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(Vector3(10, 0, 10))
				< b.position.distance_to(Vector3(10, 0, 10))
			)
	)
	for index in range(6):
		workers.append(_spawn("Worker", Vector3(7 + index * 1.4, 0, 12)))
	await _frames(60)
	var before = _human.resource_a
	for worker in workers:
		worker.action = (
			load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
			. new(deposits[0])
		)
	await _frames(5400)
	var income = _human.resource_a - before
	print("HARVEST: 6 workers / 90s income=", income)
	_check(income >= 30, "Workers stalled at crowded deposit or HQ")
	var factory
	for unit in _human.get_children():
		if "type" in unit and unit.type == "VehicleFactory":
			factory = unit
			break
	_human.resource_a = 1000
	_human.resource_b = 1000
	var produced = []
	for _index in range(6):
		factory.production_queue.produce(load(Catalog.scene_path("Tank")))
		factory.production_queue._process(1000)
	await _frames(90)
	for unit in _human.get_children():
		if "type" in unit and unit.type == "Tank":
			produced.append(unit)
			unit.action = _moving.new(Vector3(38, 0, 22 + produced.size() * 2))
	await _frames(1200)
	_check(produced.size() == 6, "Factory failed to produce test batch")
	_check(
		produced.all(func(unit): return unit.global_position.x > 33),
		"Produced units stuck at factory exit"
	)


func _test_new_obstacle():
	for unit in _human.get_children():
		if "type" in unit and unit.type != "CommandCenter":
			unit.queue_free()
	await _frames(90)
	var tank = _spawn("Tank", Vector3(16, 0, 23))
	# An order issued immediately on creation must survive navigation initialization.
	tank.action = _moving.new(Vector3(35, 0, 23))
	await _frames(50)
	var obstacle = _spawn("CommandCenter", Vector3(25, 0, 23))
	await _frames(1200)
	_check(
		tank.global_position_yless.distance_to(Vector3(35, 0, 23)) < 1,
		"Unit did not repath after a building was placed"
	)
	obstacle.queue_free()
	tank.action = _moving.new(Vector3(16, 0, 23))
	await _frames(1200)
	_check(
		tank.global_position_yless.distance_to(Vector3(16, 0, 23)) < 1,
		"Unit did not route through a removed building"
	)


func _test_construction_and_rocks():
	var building = load(Catalog.scene_path("VehicleFactory")).instantiate()
	_game._setup_and_spawn_unit(building, Transform3D(Basis(), Vector3(25, 0, 25)), _human)
	var worker = _spawn("Worker", Vector3(18, 0, 25))
	worker.action = load("res://source/match/units/actions/Constructing.gd").new(building)
	await _frames(3600)
	print("CONSTRUCTION: progress=", building._construction_progress, " worker=", worker.position)
	_check(building.is_constructed(), "Builder cannot reach newly placed factory")
	var rock = Node3D.new()
	rock.name = "TestRock"
	rock.position = Vector3(25, 0, 35)
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = 3.3
	obstacle.affect_navigation_mesh = true
	obstacle.path_height_offset = 0.6
	rock.add_child(obstacle)
	_game.add_child(rock)
	var tank = _spawn("Tank", Vector3(17, 0, 35))
	await _frames(90)
	tank.action = _moving.new(Vector3(33, 0, 35))
	var minimum_distance = 100.0
	for _frame in range(1200):
		await physics_frame
		minimum_distance = min(
			minimum_distance, tank.global_position_yless.distance_to(rock.position)
		)
	print("ROCK: remaining=", tank.global_position_yless.distance_to(Vector3(33, 0, 35)))
	_check(
		tank.global_position_yless.distance_to(Vector3(33, 0, 35)) < 1,
		"Tank stuck at rock formation"
	)
	_check(minimum_distance >= 3.3, "Tank crossed rock footprint")


func _capture():
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/skirmish")
	root.get_texture().get_image().save_png("res://art/skirmish/navigation-regression.png")


func _frames(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
