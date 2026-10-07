extends "res://tests/headless/PolicyRecoveryRegression.gd"

var advance_point = Vector3(38, 0, 25)


func _assault_destination(_enemy_start):
	return advance_point


func _recovery_fixture(faction):
	game = await _start(_settings(faction, "helix" if faction == "bastion" else "bastion", false))
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(5)
	var infantry = _recovery_actor("Infantry", Vector3(32, 0, 24))
	var tank = _recovery_actor("Tank", Vector3(32, 0, 27))
	await _frames(10)
	phase = "attack"
	phase_started = game.simulation_time
	retreating.clear()
	metrics = {"first_assault": game.simulation_time}
	advance_point = Vector3(38, 0, 25)
	for unit in [infantry, tank]:
		_check(
			unit.action != null and unit.action.is_idle(),
			"Fixture needs the real idle-defense action"
		)
	_command()
	for unit in [infantry, tank]:
		_check(
			is_instance_of(unit.action, attack_move_action),
			"%s idle %s did not join the assault" % [faction, unit.type]
		)
	await _frames(210)
	for unit in [infantry, tank]:
		_check(
			unit.position.distance_to(advance_point) < 3,
			"%s did not reach its first waypoint" % unit.type
		)
	advance_point = Vector3(44, 0, 25)
	_command()
	for unit in [infantry, tank]:
		_check(
			is_instance_of(unit.action, attack_move_action),
			"%s completed %s did not continue the route" % [faction, unit.type]
		)
	await _frames(210)
	for unit in [infantry, tank]:
		_check(
			unit.position.distance_to(advance_point) < 3,
			"%s did not reach the next waypoint" % unit.type
		)
	var enemy = load(Catalog.scene_path("Tank")).instantiate()
	var enemy_player = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	game._setup_and_spawn_unit(
		enemy, Transform3D(Basis(), tank.position + Vector3(2, 0, 0)), enemy_player, false
	)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	tank.issue_manual_order(null)
	game.battlefield.invalidate()
	await _frames(20)
	var firing = tank.action
	_check(not firing.is_idle(), "Fixture needs active idle-defense fire")
	_command()
	_check(tank.action == firing, "Continuing an advance interrupted active defensive fire")
	print("POLICY ADVANCE ", faction, " infantry=", infantry.position, " tank=", tank.position)
	game.queue_free()
	await _frames(5)
