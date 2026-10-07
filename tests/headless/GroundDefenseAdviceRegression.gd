extends "res://tests/headless/AirDefenseAdviceRegression.gd"

var factory
var ground_catalog


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	tactics = load("res://source/match/SkirmishTactics.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _ground_fixture(faction)
		_selected([factory], "Rifle-only defense did not select armored production")
		_check("armor" in _defense().description.to_lower(), "Advice omitted heavy armor counter")
		await _unchanged_advice("rifles versus visible armor")
		if not "--original-only" in OS.get_cmdline_user_args():
			await _repeat_production_selection()
			await _production_cases()
			await _counter_cases()
			await _ground_visibility()
			await _construction_cases()
			await _recovery_priority()
		print("GROUND ADVICE VERIFIED ", faction)
		paused = false
		game.queue_free()
		await _frames(5)
		game = null
	for message in errors:
		push_error(message)
	print("Ground defense advice: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _ground_fixture(faction):
	await _fixture(faction)
	raider.queue_free()
	for unit in _units(human, "Tank"):
		unit.queue_free()
	await _frames(2)
	raider = _actor("Tank", enemy, hq_point + Vector3(4, 0, 0))
	factory = _units(human, "VehicleFactory")[0]
	factory.production_queue.fit_chips = false
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, raider), "Heavy raid is hidden")


func _repeat_production_selection():
	var panel = game.hud.battle_plan
	var menus = game.find_child("UnitMenus")
	for repeat in 3:
		panel._select([factory])
		await _frames(8)
		_check(menus._scroll.size.y > 100, "Repeated factory selection collapsed production panel")
		_check(menus._buttons.size() == 4, "Repeated factory selection lost purchase controls")


func _production_cases():
	var cost = factions.cost(human, "Tank")
	human.resource_a = cost.resource_a - 1
	human.resource_b = cost.resource_b - 2
	_check("Short: 1 M / 2 E" in _defense().description, "Exact conventional shortage missing")
	factory.production_queue.fit_chips = true
	var fee = factions.chip_cost(human.faction)
	_check(
		"Short: 1 M / %d E" % (2 + fee) in _defense().description, "Fitted price omitted chip fee"
	)
	await _unchanged_advice("fitted shortage")
	human.resource_a = 1000
	human.resource_b = 1000
	ground_catalog = load("res://source/match/BastionCatalog.gd")
	var tank_scene = load(ground_catalog.scene_path("Tank"))
	var job = factory.production_queue.produce(tank_scene)
	_check(job != null and job.fitted_chip, "Actual fitted purchase failed")
	_check(job.paid_cost.resource_b == cost.resource_b + fee, "Fitted recommendation price wrong")
	_check("already paid" in _defense().description, "Queued counter requested duplicate spending")
	await _unchanged_advice("paid fitted counter")
	var lab = _units(human, "CommandLab")[0]
	lab.queue_free()
	await _frames(2)
	_check("Rebuild" in _defense().description, "Paid counter hid blocked queue after lab loss")
	factory.production_queue.cancel_all()
	_check("Requires" in _defense().description, "Unpaid fitted choice hid missing lab")
	_check("Turn off Fit chips" in _defense().description, "Conventional fallback missing")
	factory.production_queue.fit_chips = false
	_check("Produce " in _defense().description, "Conventional armor incorrectly requires lab")
	_actor("CommandLab", human, hq_point + Vector3(-8, 0, 8))
	for index in root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT:
		_check(
			(
				factory.production_queue.produce(load(ground_catalog.scene_path("RepairRobot")))
				!= null
			),
			"Could not fill queue with non-counter jobs"
		)
	_check("Queue full" in _defense().description, "Full queue advertised immediate production")
	var alternative = _actor("VehicleFactory", human, hq_point + Vector3(-10, 0, -8))
	_selected([alternative], "Advice ignored another factory with space")
	alternative.queue_free()
	await _frames(2)
	factory.production_queue.cancel_all()
	var population_fill = []
	while human.population(true) < 100:
		population_fill.append(_actor("Worker", human, hq_point + Vector3(-25, 0, 15)))
	_check(
		"Unit limit reached" in _defense().description, "Population cap hidden by production advice"
	)
	for unit in population_fill:
		unit.queue_free()
	await _frames(2)
	var count_before = _units(human, "Tank").size()
	var funds = Vector2i(human.resource_a, human.resource_b)
	job = factory.production_queue.produce(tank_scene)
	_check(job != null, "Recommended conventional production failed")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Counter production did not charge exact shown price"
	)
	var left = job.time_left
	await _unchanged_advice("paid conventional counter")
	_check(job.time_left == left, "Paused advice advanced paid queue")
	factory.process_mode = Node.PROCESS_MODE_INHERIT
	game.hud._toggle_pause()
	var start = game.simulation_time
	while _units(human, "Tank").size() == count_before and game.simulation_time - start < 90:
		await _frames(1)
	game.hud._toggle_pause()
	factory.process_mode = Node.PROCESS_MODE_DISABLED
	_check(_units(human, "Tank").size() == count_before + 1, "Real paid counter never completed")
	_selected(plan_rules.army(human), "Completed counter did not restore whole-army defense")
	for unit in _units(human, "Tank"):
		unit.queue_free()
	await _frames(2)


func _counter_cases():
	human.coordination_unlocked = true
	for role in ["AdvancedTank", "CombatRobot"]:
		if role == "CombatRobot" and human.faction != "helix":
			continue
		var job = factory.production_queue.produce(load(ground_catalog.scene_path(role)))
		_check(job != null, "Paid specialist counter fixture failed")
		_check("already paid" in _defense().description, "Paid specialist counter was ignored")
		factory.production_queue.cancel_all()
	var hangar = _actor("AircraftFactory", human, hq_point + Vector3(-15, 0, 8))
	var strike_job = hangar.production_queue.produce(load(ground_catalog.scene_path("Helicopter")))
	_check(strike_job != null, "Paid strike counter fixture failed")
	_selected([hangar], "Paid air-to-ground counter was ignored")
	hangar.production_queue.cancel_all()
	hangar.queue_free()
	await _frames(2)
	var walker = _actor("CombatRobot", human, hq_point + Vector3(-3, 0, 2))
	if human.faction == "helix":
		_selected(plan_rules.army(human), "Precision Lancer was not recognized as an armor counter")
		walker.weapon_mode = "interception"
		walker.configure_weapon()
		_selected([walker], "Rifles hid the available Precision stance choice")
		_check("Precision" in _defense().description, "Stance advice omitted Precision")
	else:
		_selected([factory], "Autocannon walker was mistaken for an armor counter")
	walker.queue_free()
	await _frames(2)
	var air = _actor("Helicopter", human, hq_point + Vector3(-4, 3, 0))
	_selected(plan_rules.army(human), "Strike aircraft was not recognized as an armor counter")
	air.queue_free()
	await _frames(2)
	var turret = _actor("AntiGroundTurret", human, hq_point + Vector3(0, 0, 4))
	_selected([turret], "Available static armor counter omitted")
	turret.mark_as_under_construction()
	_selected([factory], "Foundation advertised as ready ground cover")
	turret.queue_free()
	await _frames(2)
	var advanced = _actor("AdvancedTank", human, hq_point + Vector3(-4, 0, 0))
	_selected(plan_rules.army(human), "Heavy mobile counter omitted")
	advanced.queue_free()
	await _frames(2)


func _ground_visibility():
	var worker = _units(human, "Worker")[0]
	var point = worker.position
	worker.position = Vector3(64, 0, 50)
	raider.position = Vector3(74, 0, 50)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, raider), "Hidden armor fixture is observed")
	_no_defense("Hidden heavy armor leaked counter-production advice")
	worker.receive_weapon_hit(raider)
	_check("Enemy fire" in _defense().description, "Unseen incoming fire lost generic defense")
	_check(not "Heavy armor" in _defense().description, "Hidden source classified as armor")
	worker.hp = worker.hp_max
	worker.last_enemy_damage_time = -1000
	worker.position = point
	raider.position = hq_point + Vector3(4, 0, 0)
	game.battlefield.invalidate()
	var aircraft = _actor("Helicopter", enemy, hq_point + Vector3(0, 3, 4))
	game.battlefield.invalidate()
	_check("Aircraft" in _defense().description, "Ground counter displaced urgent anti-air branch")
	aircraft.queue_free()
	await _frames(2)
	for unit in _units(human, "Infantry"):
		unit.queue_free()
	await _frames(2)
	_selected([factory], "Depleted army selected barracks against heavy armor")


func _construction_cases():
	factory.queue_free()
	await _frames(2)
	_build_hint("VehicleFactory")
	var foundation = _actor("VehicleFactory", human, hq_point + Vector3(-10, 0, -8))
	foundation.mark_as_under_construction()
	_check(
		"continue construction" in _defense().description,
		"Unfinished counter factory requested a duplicate"
	)
	await _unchanged_advice("unfinished counter factory")
	foundation.queue_free()
	for unit in _units(human, "Barracks"):
		unit.queue_free()
	await _frames(2)
	_build_hint("Barracks")
