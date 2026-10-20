extends "res://tests/headless/SkirmishLoop.gd"


func _run():
	plan_rules = load("res://tests/UnitQueries.gd")
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct_action = load("res://source/match/units/actions/Constructing.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
	for error in _errors:
		push_error(error)
	print("Reference economy: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _fixture(faction):
	game = await _start(_settings(faction, "helix" if faction == "bastion" else "bastion"))
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan_rules.owned_units(human):
		if unit.type == "RepairDepot":
			unit.queue_free()
	await _frames(5)
	paused = true
	var workers = _workers()
	for worker in workers:
		worker.issue_manual_order(null)
	human.resource_a = 0
	human.resource_b = 0
	_economy()
	_check(
		_electronics().size() == 1 and workers[2] in _electronics(), "Four-worker opening changed"
	)
	_spawn_worker()
	_economy()
	_check(
		_electronics().size() == 2 and _workers()[4] in _electronics(),
		"Fifth-worker electronics opening changed"
	)
	_spawn_worker()
	_economy()
	_check(_electronics().size() == 2, faction + ": initial allocation lacks electronics")
	for cycle in 2:
		var losses = _electronics()
		if losses.is_empty():
			losses = [_workers()[-1]]
		for worker in losses:
			worker.queue_free()
		await _frames(2)
		for index in losses.size():
			_spawn_worker()
		_economy()
		_check(_electronics().size() == 2, faction + ": replacements lost electronics income")
		print("REFERENCE LABOR ", faction, " cycle=", cycle, " electronics=", _electronics().size())
	var tank = _unit(human, "Tank")
	tank.hp = tank.hp_max * .4
	human.resource_a = 300
	human.resource_b = 300
	var funds = Vector2(human.resource_a, human.resource_b)
	_economy()
	_check(_electronics().size() == 2, faction + ": depot construction interrupted electronics")
	var depots = plan_rules.owned_units(human).filter(func(unit): return unit.type == "RepairDepot")
	_check(depots.size() == 1, faction + ": wounded army never invested in a depot")
	if not depots.is_empty():
		var cost = factions.cost(human, "RepairDepot", true)
		_check(
			(
				Vector2(human.resource_a, human.resource_b)
				== funds - Vector2(cost.resource_a, cost.resource_b)
			),
			"Depot was not paid"
		)
		_economy()
		_check(
			(
				(
					plan_rules
					. owned_units(human)
					. filter(func(unit): return unit.type == "RepairDepot")
					. size()
				)
				== 1
			),
			"Duplicate recovery foundation"
		)
	paused = false
	var income = human.resource_b
	await _frames(3600)
	_check(human.resource_b > income, faction + ": replacement workers never delivered electronics")
	if not depots.is_empty():
		_check(depots[0].is_constructed(), faction + ": paid depot never finished")
	game.queue_free()
	await _frames(5)


func _workers():
	return plan_rules.owned_units(human).filter(func(unit): return unit.type == "Worker")


func _electronics():
	return _workers().filter(
		func(worker):
			return is_instance_of(worker.action, harvest_action) and worker.action._kind == 2
	)


func _spawn_worker():
	var worker = load(Catalog.scene_path("Worker")).instantiate()
	game._setup_and_spawn_unit(
		worker,
		Transform3D(Basis(), _unit(human, "CommandCenter").position + Vector3(6, 0, 3)),
		human,
		false
	)
