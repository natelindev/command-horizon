extends "res://tests/headless/SkirmishMatrix.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	metrics = {"damage_hp": [0.0, 0.0], "repaired_hp": [0.0, 0.0], "losses": [{}, {}]}
	game = await _start(_settings("bastion", "helix", false))
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	opponent.set_process(false)
	game.repair_service.set_physics_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("MatchSignals").unit_spawned.connect(_track_unit)
	root.get_node("MatchSignals").unit_destroying.connect(_loss)
	var building = _metric_unit("Barracks", human, Vector3(45, 0, 45), true)
	building.construct(0.5)
	building.construct(0.5)
	_check(metrics.repaired_hp == [0.0, 0.0], "Construction health counted as repair")
	_check(metrics.damage_hp == [0.0, 0.0], "Foundation setup counted as combat damage")
	var tank = _metric_unit("Tank", human, Vector3(56, 0, 48))
	_metric_unit("RepairRobot", human, Vector3(58, 0, 48))
	var shooter = _metric_unit("Tank", opponent, Vector3(63, 0, 48))
	var before = tank.hp
	tank.receive_weapon_hit(shooter)
	_check(
		is_equal_approx(metrics.damage_hp[0], before - tank.hp),
		"Weapon damage was not measured exactly"
	)
	before = tank.hp
	game.repair_service.service(1.0)
	_check(tank.hp > before, "Metric fixture did not perform actual mobile repair")
	_check(
		is_equal_approx(metrics.repaired_hp[0], tank.hp - before), "Repair was not measured exactly"
	)
	_check(metrics.repaired_hp[1] == 0, "Repair attributed to the wrong side")
	while tank.hp > 0:
		tank.receive_weapon_hit(shooter)
	_check(
		metrics.losses[0].get("Tank", 0) == 1,
		"Destruction was not counted before ownership disappeared"
	)
	_check(metrics.losses[1].is_empty(), "Loss attributed to the wrong side")
	game.queue_free()
	await _frames(5)
	for error in _errors:
		push_error(error)
	print("Matrix metric checks: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _metric_unit(role, player, point, construction = false):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, construction)
	return unit
