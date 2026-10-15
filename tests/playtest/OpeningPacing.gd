extends "res://tests/headless/SkirmishLoop.gd"


func _run():
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct_action = load("res://source/match/units/actions/Constructing.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _opening(faction)
	for message in _errors:
		push_error(message)
	print("Resource-funded opening: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _opening(faction):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", false)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	_spent = Vector2.ZERO
	var started = game.simulation_time
	var first_armor = -1.0
	for tick in 600:
		_economy()
		_train()
		if first_armor < 0 and _unit(human, "Tank") != null:
			first_armor = game.simulation_time - started
		if _force().size() >= 20:
			break
		await _frames(30)
	var elapsed = game.simulation_time - started
	var army = _force()
	_check(army.size() >= 20, faction + ": failed to build a 20-unit force within five minutes")
	_check(
		first_armor > 0 and first_armor <= 180, faction + ": first armor takes over three minutes"
	)
	print(
		"OPENING ",
		faction,
		" army=",
		army.size(),
		" seconds=",
		elapsed,
		" first_armor=",
		first_armor,
		" workers=",
		_economy_workers(plan_rules.owned_units(human)).size(),
		" spent=",
		_spent,
		" resources=",
		Vector2(human.resource_a, human.resource_b)
	)
	game.queue_free()
	await _frames(5)


func _ready_for_command_lab():
	# This opening prioritizes conventional forces before tech upgrades.
	return _force().size() >= 20


func _train():
	var units = plan_rules.owned_units(human)
	for pair in [
		["CommandCenter", "Worker", 8],
		["Barracks", "Infantry", 12],
		["VehicleFactory", "Tank", 6],
		["VehicleFactory", "RepairRobot", 2]
	]:
		if (
			pair[1] == "Infantry"
			and not human.has_completed_structure("VehicleFactory")
			and units.filter(func(unit): return unit.type == "Infantry").size() >= 4
		):
			continue
		var producer = _unit(human, pair[0])
		if (
			producer == null
			or not producer.is_constructed()
			or producer.production_queue.size() > 0
		):
			continue
		if units.filter(func(unit): return unit.type == pair[1]).size() >= pair[2]:
			continue
		var entry = producer.production_queue.produce(load(Catalog.scene_path(pair[1])))
		if entry != null:
			_spent += Vector2(entry.paid_cost.resource_a, entry.paid_cost.resource_b)
			# Disperse completed forces with the real rally system, clearing exits.
			producer.get_node("RallyPoint").position = Vector3(-6, 0, 14)


func _force():
	return plan_rules.owned_units(human).filter(
		func(unit): return unit.movement_speed > 0 and unit.type != "Worker"
	)
