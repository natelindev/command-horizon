extends "res://tests/headless/SkirmishBudgetRegression.gd"


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _growth(faction)
	for message in errors:
		push_error(message)
	print("Skirmish build readiness: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _growth(faction):
	await _skirmish("helix", "res://source/match/maps/DesertFrontier.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	paused = true
	var player = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	player.faction = faction
	player.difficulty = 1
	player.resource_a = 5000
	player.resource_b = 5000
	_spawn("Barracks", player, Vector3(100, 0, 60))
	var factory = _spawn("VehicleFactory", player, Vector3(100, 0, 70))
	_spawn("PowerPlant", player, Vector3(110, 0, 60))
	game.simulation_time = 170
	_check(
		player._expansion_building(player._units()) == "",
		faction + ": elapsed time reserved optional technology before an army existed"
	)
	var production = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	var composition = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
	while production.army_size(composition.inventory(player._units())) < 4:
		_spawn("Infantry", player, Vector3(100, 0, 90))
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null, "Readiness fixture did not queue its paid tank")
	var first = "AircraftFactory" if faction == "helix" else "RepairDepot"
	_check(
		player._expansion_building(player._units()) == first,
		faction + ": paid army production did not unlock the first optional facility"
	)
	factory.production_queue.cancel_all()
	_check(
		player._expansion_building(player._units()) == "",
		faction + ": cancelled army production still unlocked an optional facility"
	)
	for role in ["RepairDepot", "CommandLab", "AircraftFactory", "AntiAirTurret"]:
		_spawn(role, player, Vector3(90, 0, 80))
	game.simulation_time = 900
	player.difficulty = 0
	while production.army_size(composition.inventory(player._units())) < 14:
		_spawn("Infantry", player, Vector3(100, 0, 90))
	_check(
		player._expansion_building(player._units()) == "AntiGroundTurret",
		faction + ": Easy army cap prevented finishing its optional base"
	)
	player.difficulty = 1
	_check(
		player._expansion_building(player._units()) == "",
		faction + ": later optional buildings did not wait for a larger army"
	)
	_spawn("AntiGroundTurret", player, Vector3(90, 0, 90))
	player.difficulty = 2
	var price = factions.cost(player, "VehicleFactory", true)
	player.resource_a = price.resource_a
	player.resource_b = price.resource_b
	_check(
		player._expansion_building(player._units()) == "",
		faction + ": extra factory consumed the existing factories' production budget"
	)
	var budget = Vector2i(price.resource_a, price.resource_b)
	for request in production.requests(game, player, player._units(), true):
		budget += Vector2i(request.cost.resource_a, request.cost.resource_b)
	player.resource_a = budget.x
	player.resource_b = budget.y
	_check(
		player._expansion_building(player._units()) == "VehicleFactory",
		faction + ": fully funded production prevented affordable extra capacity"
	)
	_check_balanced_bank(player, production)
	paused = false
	game.queue_free()
	await _frames(5)


func _check_balanced_bank(player, production):
	var labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	# A capped, fully researched commander has no pending expenses.
	player.difficulty = 0
	player.coordination_unlocked = true
	player.technology.completed = ["weapons_1", "armor_1"]
	for index in 2:
		_spawn("PowerPlant", player, Vector3(110, 0, 70 + index * 10))
	while _units(player, "Worker").size() < 5:
		_spawn("Worker", player, Vector3(100, 0, 70))
	for worker in _units(player, "Worker"):
		worker.action = null
		worker.manual_orders.clear_waiting()
	_check(
		production.demand(game, player, player._units()) == Vector2i.ZERO,
		"Bank balance fixture still had an expense"
	)
	player.resource_a = 1000
	player.resource_b = 0
	var assignments = labor.plan(game, player, player._units())
	_check(assignments.values().count(2) == 4, "Idle economy did not bank missing electronics")
	player.resource_a = 0
	player.resource_b = 1000
	assignments = labor.plan(game, player, player._units())
	_check(assignments.values().count(1) == 4, "Idle economy did not bank missing materials")
