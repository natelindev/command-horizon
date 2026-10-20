extends "res://tests/headless/SaveRestoreEdges.gd"

var plan
var factions
var human
var factory
var tank
var harvest
var tank_scene


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan = load("res://tests/UnitQueries.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	tank_scene = load("res://source/match/units/Tank.tscn")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		await _conventional(faction)
		await _lab(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Opening armor: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn", false)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	_spawn("Barracks", Vector3(12, 0, 23))
	factory = _spawn("VehicleFactory", Vector3(24, 0, 33))
	for index in 2:
		_spawn("Infantry", Vector3(18 + index * 2, 0, 30))
	var workers = _units(human, "Worker")
	for kind in ["resource_a", "resource_b"]:
		var worker = workers[0 if kind == "resource_a" else 1]
		var deposits = get_nodes_in_group("resource_units").filter(func(unit): return kind in unit)
		deposits.sort_custom(
			func(a, b):
				return (
					a.position.distance_to(worker.position)
					< b.position.distance_to(worker.position)
				)
		)
		worker.issue_manual_order(harvest.new(deposits[0]))
	human.resource_a = 100
	human.resource_b = 100
	await _frames(5)
	game.hud._toggle_pause()
	_check(paused and not human.lab_research_unlocked(), "Opening fixture has lab research")


func _conventional(faction):
	await _review(faction + "-armor")
	var price = factions.cost(human, "Tank")
	var funds = Vector2i(human.resource_a, human.resource_b)
	human.resource_a = price.resource_a - 1
	human.resource_b = price.resource_b - 1
	_check(factory.production_queue.produce(tank_scene) == null, "Unfunded armor was queued")
	_check(
		human.resource_a == price.resource_a - 1 and human.resource_b == price.resource_b - 1,
		"Unfunded armor spent resources"
	)
	human.resource_a = funds.x
	human.resource_b = funds.y
	var job = factory.production_queue.produce(tank_scene)
	_check(job != null, "Conventional armor required a lab")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(price.resource_a, price.resource_b)
		),
		"Conventional armor charged the wrong price"
	)
	await _review(faction + "-queued")
	factory.production_queue.cancel(job)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "Conventional queue refund differs"
	)
	factory.production_queue.produce(tank_scene)
	await _archive()
	_check(factory.production_queue.size() == 1, "Paid opening armor was lost across archive")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(price.resource_a, price.resource_b)
		),
		"Archive changed the paid armor price"
	)
	game.hud._toggle_pause()
	for frame in 1800:
		await physics_frame
		if not _units(human, "Tank").is_empty():
			break
	_check(not _units(human, "Tank").is_empty(), "Paid conventional armor never completed")
	tank = _units(human, "Tank")[0]
	_check(not human.lab_research_unlocked(), "Conventional tank unlocked lab research")
	var point = _units(human, "CommandCenter")[0].position + Vector3(6, 0, 0)
	tank.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(point))
	for frame in 1200:
		await physics_frame
		if tank.position.distance_to(point) < 1.5:
			break
	_check(tank.position.distance_to(point) < 1.5, "Conventional tank did not obey manual move")
	tank.issue_manual_order(null)
	game.hud._toggle_pause()
	await _review(faction + "-lab")
	print(
		"OPENING ARMOR ", faction, " conventional=true hp=", tank.hp, " time=", game.simulation_time
	)


func _lab(faction):
	_spawn("CommandLab", Vector3(25, 0, 22))
	await _frames(5)
	_check(human.lab_research_unlocked(), "Completed factory and lab did not unlock research")
	await _archive()
	_check(human.lab_research_unlocked(), "Lab research unlock was lost across archive")
	print("OPENING LAB ", faction, " research=", human.lab_research_unlocked())


func _archive():
	var capture = Snapshot.new()
	var saved = capture.capture(game)
	var factory_id = capture._reference(factory)
	var tank_id = capture._reference(tank) if is_instance_valid(tank) else ""
	var file = "user://opening-armor-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, saved), "Opening archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Opening archive restore failed")
	game = loaded.game
	human = game._get_human_player()
	factory = restore.entities[factory_id]
	if tank_id != "":
		tank = restore.entities[tank_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(5)


func _spawn(role, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
	return unit


func _review(_label):
	return true
