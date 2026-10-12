extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var catalog
var harvest


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _budget(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish budget: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _budget(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/DesertFrontier.tscn",
		true
	)
	var human = game._get_human_player()
	var player = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	while _units(player, "Worker").size() < 6:
		_spawn("Worker", player, Vector3(100, 0, 72))
	while _units(player, "Infantry").size() < 6:
		_spawn("Infantry", player, Vector3(100, 0, 76))
	# Fill infantry demand so this fixture isolates vehicle/air budgets.
	for role in ["Hero", "AssaultInfantry", "SniperInfantry", "RocketInfantry"]:
		for index in 1 if role == "Hero" else 2:
			_spawn(role, player, Vector3(100 + index * 2, 0, 86))
	var scout = _spawn("Drone", player, Vector3(96, 2, 40))
	var air = _spawn("AircraftFactory", player, Vector3(94, 0, 80))
	_spawn("PowerPlant", player, Vector3(88, 0, 80))
	var factory = _units(player, "VehicleFactory")[0]
	player._production_index = 0
	var price = factions.cost(player, "Helicopter")
	player.resource_a = price.resource_a
	player.resource_b = price.resource_b
	player._train(player._units(), "")
	_check(_queued(air) == "Helicopter", faction + ": ground job consumed first-wing budget")
	_check(factory.production_queue.size() == 0, "First-wing budget also paid for armor")
	_check(player._production_index == 0, "Aircraft advanced ground production sequence")
	air.production_queue.cancel_all()
	factory.production_queue.cancel_all()
	var tank = factions.cost(player, "Tank")
	player.resource_a = tank.resource_a
	player.resource_b = tank.resource_b
	player._production_index = 0
	player._train(player._units(), "")
	_check(
		factory.production_queue.size() == 0 and air.production_queue.size() == 0,
		"Cheaper armor consumed savings for an unfunded first wing"
	)
	_check(
		player.resource_a == tank.resource_a and player.resource_b == tank.resource_b,
		"Reserved budget spent early"
	)
	factory.production_queue.cancel_all()
	air.production_queue.cancel_all()
	var threat = _spawn("Helicopter", human, scout.position + Vector3(3, 0, 0))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, threat), "Budget counter fixture is hidden")
	var counter = factions.cost(player, "CombatRobot")
	player.resource_a = counter.resource_a
	player.resource_b = counter.resource_b
	player._production_index = 0
	player._train(player._units(), "")
	_check(_queued(factory) == "CombatRobot", "First-wing saving delayed a visible-air counter")
	factory.production_queue.cancel_all()
	air.production_queue.cancel_all()
	threat.queue_free()
	await _frames(2)
	game.battlefield.invalidate()
	await _contracts(player, air, factory)
	print("BUDGET ", faction)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _contracts(player, air, factory):
	var production = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	var second_air = _spawn("AircraftFactory", player, Vector3(82, 0, 80))
	player._production_index = 0
	var requests = production.requests(game, player, player._units())
	var wings = requests.filter(func(job): return job.role == "Helicopter")
	_check(wings.size() == 1, "Two idle air factories reserved duplicate first wings")
	player.resource_a = 1000
	player.resource_b = 1000
	player._train(player._units(), "")
	_check(
		air.production_queue.size() + second_air.production_queue.size() == 1,
		"Two air factories purchased duplicate first wings"
	)
	for producer in [air, second_air, factory]:
		producer.production_queue.cancel_all()
	second_air.queue_free()
	await _frames(2)
	for existing_lab in _units(player, "CommandLab"):
		existing_lab.queue_free()
	await _frames(2)
	factory.production_queue.fit_chips = true
	player._production_index = 0
	requests = production.requests(game, player, player._units())
	_check(
		not requests.any(func(job): return job.producer == factory),
		"Unavailable fitted tank reserved resources before a lab"
	)
	_spawn("CommandLab", player, Vector3(82, 0, 70))
	requests = production.requests(game, player, player._units())
	var tank_jobs = requests.filter(func(job): return job.producer == factory)
	_check(
		(
			tank_jobs.size() == 1
			and tank_jobs[0].cost.resource_b == factions.cost(player, "Tank").resource_b + 4
		),
		"Fitted tank forecast omitted hardware cost"
	)
	factory.production_queue.fit_chips = false
	var wing = factions.cost(player, "Helicopter")
	player.resource_a = wing.resource_a
	player.resource_b = wing.resource_b
	player._research(player._units(), "")
	_check(
		(
			player.coordination_left < 0
			and player.resource_a == wing.resource_a
			and player.resource_b == wing.resource_b
		),
		"Optional research consumed first-wing savings"
	)
	player.resource_a = wing.resource_a + 20
	player.resource_b = wing.resource_b + 20
	player._research(player._units(), "")
	_check(
		(
			player.coordination_left > 0
			and player.resource_a == wing.resource_a
			and player.resource_b == wing.resource_b
		),
		"Fully funded research did not preserve first-wing savings"
	)
	player.cancel_coordination()
	var foundation = _spawn("RepairDepot", player, Vector3(80, 0, 60))
	foundation.mark_as_under_construction()
	var worker = _units(player, "Worker")[0]
	var orders = load("res://source/match/orders/ManualOrders.gd")
	var deposit = get_nodes_in_group("resource_units")[0]
	worker.issue_manual_order(harvest.new(deposit))
	worker.manual_orders.submit(orders.target_order("gather", deposit), true)
	# An idle engineer should recover the foundation without stealing an
	# active income route or replacing that gatherer's delivery handoff.
	player._build(player._units(), "RepairDepot")
	var builders = _units(player, "Worker").filter(
		func(unit):
			return (
				unit.action != null
				and unit.action.get_script().resource_path.ends_with("Constructing.gd")
			)
	)
	_check(
		(
			builders.size() == 1
			and builders[0] != worker
			and builders[0].manual_orders.pending.is_empty()
			and worker.manual_orders.pending.size() == 1
		),
		"Foundation recovery interrupted productive labor or retained a builder's stale handoff"
	)
	_check(
		production.reserve(player, player._units(), "RepairDepot") == Vector2i.ZERO,
		"Paid foundation reserved its purchase price again"
	)
	player.resource_a = wing.resource_a
	player.resource_b = wing.resource_b
	player._train(player._units(), "RepairDepot")
	_check(_queued(air) == "Helicopter", "Paid foundation blocked funded aircraft")
	air.production_queue.cancel_all()
	factory.production_queue.cancel_all()
	_units(player, "Worker")[0].queue_free()
	await _frames(2)
	player.resource_a = 6
	player.resource_b = 0
	player._train(player._units(), "CommandLab")
	_check(
		_queued(_units(player, "CommandCenter")[0]) == "Worker",
		"Building/army reserves blocked lost-worker recovery"
	)


func _spawn(role, player, point):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _queued(producer):
	var jobs = producer.production_queue.get_elements()
	return "" if jobs.is_empty() else catalog.type_from_path(jobs[0].unit_prototype.resource_path)
