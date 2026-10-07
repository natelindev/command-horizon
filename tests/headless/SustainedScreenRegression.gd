extends "res://tests/playtest/SustainedScreenMatches.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	constants = root.get_node("Constants")
	factions = load("res://source/match/FactionCatalog.gd")
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	composition = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
	economy_policy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	research_policy = "combined"
	army_policy = "screened-air"
	for faction in factions.IDS:
		await _screen_fixture(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in _errors:
		push_error(error)
	print("Sustained screen: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _screen_fixture(faction):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", true)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud.pause_after_load()
	for unit in plan_rules.owned_units(human):
		if unit.type == "Tank":
			unit.queue_free()
	await _frames(3)
	for index in 6:
		_actor("Infantry", index)
	for index in 2:
		_actor("Worker", index)
	var factory = _unit(human, "VehicleFactory")
	var cost = factions.cost(human, "Tank")
	cost.resource_b += factions.chip_cost(faction)
	human.resource_a = 100
	human.resource_b = cost.resource_b + 3
	metrics = {}
	vehicle_sequence = 0
	_spent = Vector2.ZERO
	_check(not _air_allowed(), faction + ": infantry-only screen reserved air investment")
	var funds = Vector2i(human.resource_a, human.resource_b)
	_produce()
	var jobs = factory.production_queue.get_elements()
	_check(jobs.size() == 1, faction + ": affordable replacement armor stayed blocked")
	if jobs.is_empty():
		return
	_check(jobs[0].paid_cost == cost, "Replacement tank price changed")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Replacement tank debit mismatch"
	)
	_check(not _air_allowed(), "Queued armor counted as a ready screen")
	game.hud._toggle_pause()
	for frame in 6000:
		await _frames(1)
		if factory.production_queue.size() == 0:
			break
	game.hud.pause_after_load()
	_check(_unit(human, "Tank") != null, "Paid replacement tank did not finish")
	_check(not _air_allowed(), "One armor unit admitted optional air investment")
	var second = _actor("CombatRobot", 3)
	_check(_air_allowed(), "Two ready armor units failed to admit air investment")
	second.hp = second.hp_max * .49
	_check(not _air_allowed(), "Badly damaged armor counted as ready")
	second.hp = second.hp_max * .5
	_check(_air_allowed(), "Half-health readiness boundary changed")
	second.queue_free()
	_check(not _air_allowed(), "Dying armor counted toward the screen")
	var flight = _actor("AircraftFactory", 5)
	flight.mark_as_under_construction()
	_check(_air_allowed(), "Existing paid air foundation was abandoned")
	print(
		"SCREEN ", faction, " paid replacement completed; readiness and existing investment checked"
	)


func _actor(role, index):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(35 + index, 0, 25)), human, false)
	return unit
