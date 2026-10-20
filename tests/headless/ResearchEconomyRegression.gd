extends "res://tests/headless/SkirmishLaborRegression.gd"

var production_policy
var technology_catalog
var economy_policy


func _initialize():
	create_timer(1000).timeout.connect(
		func():
			push_error("Research economy regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	production_policy = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	technology_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	economy_policy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		var player = await _fixture(faction)
		if "--budget-only" not in OS.get_cmdline_user_args():
			await _capped_income(player)
		await _budget_contracts(player)
		paused = false
		game.queue_free()
		await _frames(5)
		game = null
	for message in errors:
		push_error(message)
	print("Research economy: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.difficulty = 1
		side.faction = "helix" if index == 0 else faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)
	var player = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	_freeze(player)
	paused = true
	while _units(player, "Worker").size() < 6:
		_spawn("Worker", player, Vector3(103 + _units(player, "Worker").size(), 0, 77))
	for entry in [
		["AircraftFactory", Vector3(94, 0, 80)],
		["AntiAirTurret", Vector3(80, 0, 80)],
		["AntiGroundTurret", Vector3(76, 0, 80)],
		["PowerPlant", Vector3(84, 0, 80)],
		["PowerPlant", Vector3(84, 0, 70)]
	]:
		_spawn(entry[0], player, entry[1])
	# A staged full army isolates a legal state with no remaining unit/building
	# demand. Combat is frozen; finite deposits, harvesting and research stay live.
	while player.population() < catalog.POPULATION_LIMIT:
		_spawn("Infantry", player, Vector3(60, 0, 90))
	var parked = 0
	for unit in player._units():
		if unit.movement_speed > 0 and unit.attack_range != null:
			unit.position = Vector3(55 + parked % 15, 0, 88 + parked / 15)
			parked += 1
		if "production_queue" in unit and unit.production_queue != null:
			unit.production_queue.cancel_all()
	return player


func _capped_income(player):
	var workers = _units(player, "Worker")
	var material = _deposit(_units(player, "CommandCenter")[0], "resource_a")
	for worker in workers:
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		worker.issue_manual_order(harvest.new(material))
	player.resource_a = 0
	player.resource_b = 0
	var stock = _stock()
	_check(player.population(true) == 100, "Research fixture is not at its real population limit")
	_check(player._next_building(player._units()) == "", "Research fixture still needs a building")
	_check(
		production_policy.requests(game, player, player._units()).is_empty(),
		"Capped research fixture still requests unit production"
	)
	_check_demand(player, Vector2i(20, 20), "Unpaid Coordination was omitted from labor demand")
	_check(
		labor.plan(game, player, player._units()).values().count(2) > 0,
		player.faction + ": research deficit retained all-materials assignments"
	)
	var start = game.simulation_time
	var started = -1.0
	paused = false
	for frame in 10800:
		# Stop before the next decision: once Coordination completes, the
		# commander rightly buys its next technology, which this stage does not pay.
		if player.coordination_unlocked:
			break
		if frame % 90 == 0:
			player._harvest(player._units())
			player._research(player._units(), player._next_building(player._units()))
			if started < 0 and player.coordination_left > 0:
				started = game.simulation_time - start
		await physics_frame
	paused = true
	_check(started >= 0, player.faction + ": actual harvesting never funded Coordination")
	_check(player.coordination_unlocked, player.faction + ": funded Coordination never completed")
	var paid = Vector2i(20, 20) if started >= 0 else Vector2i.ZERO
	var cargo = Vector2i.ZERO
	for worker in workers:
		cargo += Vector2i(worker.resource_a, worker.resource_b)
	_check(
		stock - _stock() == Vector2i(player.resource_a, player.resource_b) + cargo + paid,
		player.faction + ": research income/payment violated finite-stock conservation"
	)
	print(
		"RESEARCH INCOME ",
		player.faction,
		" started=",
		started,
		" completed=",
		player.coordination_unlocked,
		" elapsed=",
		game.simulation_time - start,
		" funds=",
		Vector2i(player.resource_a, player.resource_b),
		" paid=",
		paid
	)


func _budget_contracts(player):
	# These independent policy contracts use exact price-sized funds. Only the
	# preceding case claims normal income and actual timed research completion.
	for unit in _units(player, "Infantry").slice(6):
		unit.queue_free()
	await _frames(2)
	for worker in _units(player, "Worker"):
		worker.process_mode = Node.PROCESS_MODE_DISABLED
	# Isolate research/vehicle budgets from the expanded infantry roster.
	for role in ["Hero", "AssaultInfantry", "SniperInfantry", "RocketInfantry"]:
		for index in 1 if role == "Hero" else 2:
			_spawn(role, player, Vector3(60 + index * 2, 0, 86))
	player.coordination_unlocked = true
	player.coordination_left = -1.0
	player.technology.cancel()
	_spawn("Drone", player, Vector3(96, 2, 40))
	_spawn("Helicopter", player, Vector3(70, 3, 80))
	var factory = _units(player, "VehicleFactory")[0]
	player._production_index = 0
	var research_cost = technology_catalog.ITEMS.weapons_1.cost
	var job = _job(player, "Tank")
	_check(not job.is_empty() and job.priority == 6, "Missing routine armor fixture")
	if job.is_empty():
		return
	var armor_cost = Vector2i(job.cost.resource_a, job.cost.resource_b)
	_set_funds(player, armor_cost)
	player._train(player._units(), "")
	_check(factory.production_queue.size() == 0, "Routine armor spent unpaid research savings")
	_clear_queues(player)
	_set_funds(player, research_cost + armor_cost)
	player._research(player._units(), "")
	_check(player.technology.active == "weapons_1", "Fully funded unit research did not start")
	_check_demand(player, Vector2i.ZERO, "Already-paid research was reserved a second time")
	player._train(player._units(), "")
	_check(_queued(factory) == "Tank", "Paid active research blocked funded routine production")
	_check(
		Vector2i(player.resource_a, player.resource_b) == Vector2i.ZERO,
		"Combined research/armor price differs"
	)
	_clear_queues(player)
	player.technology.cancel()
	_set_funds(player, research_cost)
	player._research(player._units(), "PowerPlant")
	_check(player.technology.active == "", "Research consumed unpaid construction savings")
	await _urgent_contracts(player)
	await _eligibility_contracts(player)
	print("RESEARCH BUDGET ", player.faction)


func _urgent_contracts(player):
	var scout = _units(player, "Drone")[0]
	var target = _spawn("Helicopter", game._get_human_player(), scout.position + Vector3(3, 0, 0))
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, target), "Research counter fixture is hidden")
	_check_purchase(player, "AntiAirVehicle", 1)
	target.queue_free()
	await _frames(2)
	game.battlefield.invalidate()
	for repair in _units(player, "RepairRobot"):
		repair.queue_free()
	_spawn("Tank", player, Vector3(65, 0, 80))
	await _frames(2)
	_check_purchase(player, "RepairRobot", 3)
	_spawn("RepairRobot", player, Vector3(65, 0, 82))
	for aircraft in _units(player, "Helicopter"):
		aircraft.queue_free()
	await _frames(2)
	_check_purchase(player, "Helicopter", 5)
	_spawn("Helicopter", player, Vector3(65, 3, 84))
	_units(player, "Worker")[0].queue_free()
	await _frames(2)
	_set_funds(player, Vector2i(6, 0))
	player._train(player._units(), "CommandLab")
	_check(
		_queued(_units(player, "CommandCenter")[0]) == "Worker",
		"Research/building reserves blocked emergency worker recovery"
	)
	_clear_queues(player)
	_spawn("Worker", player, Vector3(110, 0, 77))


func _eligibility_contracts(player):
	var guards = economy_policy.guards(player._units())
	for unit in guards:
		unit.hp = unit.hp_max * .4
	_check_demand(player, Vector2i.ZERO, "Wounded army retained optional research demand")
	for unit in guards:
		unit.hp = unit.hp_max
	var lab = _units(player, "CommandLab")[0]
	var point = lab.position
	_check(player.basic_programs_unlocked(), "Research prerequisite was not previously unlocked")
	lab.queue_free()
	await _frames(2)
	_check(player.basic_programs_unlocked(), "Fixture did not preserve sticky program unlock")
	_check_demand(player, Vector2i.ZERO, "Destroyed lab retained unstartable research demand")
	lab = _spawn("CommandLab", player, point)
	lab.mark_as_under_construction()
	_check_demand(player, Vector2i.ZERO, "Unfinished lab reserved unstartable research")
	lab.construct(1.0)
	_check_demand(
		player,
		technology_catalog.ITEMS.weapons_1.cost,
		"Rebuilt lab did not restore eligible research demand"
	)
	player.coordination_unlocked = false
	_set_funds(player, Vector2i(20, 20))
	_check(player.start_coordination(lab), "Coordination active-slot fixture failed to start")
	_check_demand(player, Vector2i.ZERO, "Active Coordination reserved another research payment")
	player.cancel_coordination()


func _check_purchase(player, role, priority):
	var job = _job(player, role)
	_check(not job.is_empty() and job.priority == priority, "Missing urgent " + role + " fixture")
	if job.is_empty():
		return
	_set_funds(player, Vector2i(job.cost.resource_a, job.cost.resource_b))
	player._research(player._units(), "")
	_check(player.technology.active == "", "Research displaced urgent " + role)
	player._train(player._units(), "")
	_check(_queued(job.producer) == role, "Research savings blocked urgent " + role)
	_clear_queues(player)


func _check_demand(player, extra, message):
	var units = player._units()
	var operational = production_policy.reserve(player, units, player._next_building(units))
	for job in production_policy.requests(game, player, units, true):
		operational += Vector2i(job.cost.resource_a, job.cost.resource_b)
	_check(
		production_policy.demand(game, player, units) == operational + extra,
		player.faction + ": " + message
	)


func _job(player, role):
	for job in production_policy.requests(game, player, player._units()):
		if job.role == role:
			return job
	return {}


func _clear_queues(player):
	for unit in player._units():
		if "production_queue" in unit and unit.production_queue != null:
			unit.production_queue.cancel_all()
	player._production_index = 0


func _queued(producer):
	var jobs = producer.production_queue.get_elements()
	return "" if jobs.is_empty() else catalog.type_from_path(jobs[0].unit_prototype.resource_path)


func _set_funds(player, funds):
	player.resource_a = funds.x
	player.resource_b = funds.y


func _stock():
	var result = Vector2i.ZERO
	for deposit in get_nodes_in_group("resource_units"):
		if deposit.is_queued_for_deletion():
			continue
		result += Vector2i(
			deposit.resource_a if "resource_a" in deposit else 0,
			deposit.resource_b if "resource_b" in deposit else 0
		)
	return result
