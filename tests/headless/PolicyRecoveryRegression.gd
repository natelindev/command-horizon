extends "res://tests/headless/SkirmishDefensePolicy.gd"


func _run():
	plan_rules = load("res://tests/UnitQueries.gd")
	moving_order = load("res://source/match/units/actions/Moving.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _recovery_fixture(faction)
	for error in _errors:
		push_error(error)
	print("Reference policy recovery: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _recovery_fixture(faction):
	game = await _start(_settings(faction, "helix" if faction == "bastion" else "bastion", false))
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(5)
	var barracks = _recovery_actor("Barracks", Vector3(32, 0, 25))
	var depot = _recovery_actor("RepairDepot", Vector3(32, 0, 40))
	var infantry = _recovery_actor("Infantry", Vector3(45, 0, 25))
	var tank = _recovery_actor("Tank", Vector3(45, 0, 40))
	infantry.hp = infantry.hp_max * .35
	tank.hp = tank.hp_max * .35
	# Keep the reference commander's healthy reserve out of this local service test.
	for index in 6:
		var reserve = _recovery_actor("Tank", Vector3(48 + index * 3, 0, 10))
		reserve.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(120)
	phase = "attack"
	phase_started = game.simulation_time
	retreating.clear()
	metrics = {"first_assault": game.simulation_time}
	var healed = {}
	var resumed = {}
	for tick in 180:
		_command()
		await _frames(30)
		for unit in [infantry, tank]:
			var facility = barracks if unit == infantry else depot
			if unit.hp >= unit.hp_max * .85:
				healed[unit] = true
			if (
				healed.has(unit)
				and not retreating.has(unit.get_instance_id())
				and unit.position.distance_to(facility.position) > 7
			):
				resumed[unit] = true
	for unit in [infantry, tank]:
		_check(
			healed.has(unit), "%s wounded %s never received matching service" % [faction, unit.type]
		)
		_check(
			resumed.has(unit), "%s recovered %s never rejoined the advance" % [faction, unit.type]
		)
		print(
			"POLICY FIXTURE ",
			faction,
			" ",
			unit.type,
			" health=",
			unit.hp / unit.hp_max,
			" healed=",
			healed.has(unit),
			" resumed=",
			resumed.has(unit),
			" point=",
			unit.position
		)
	# Recovered units can win this live match; victory pauses the SceneTree.
	# The next faction needs a running simulation of its own.
	paused = false
	game.queue_free()
	await _frames(5)


func _recovery_actor(role, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
	return unit
