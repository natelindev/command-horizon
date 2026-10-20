extends "res://tests/headless/FixedWingFlightRegression.gd"

# Exercise the complete expend/return/rearm/resume and one-way drone flows.


func _run():
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _ticks(30)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _ticks(5)
	for faction in ["bastion", "helix", "frontier"]:
		_human.faction = faction
		_field = _spawn("AircraftFactory", _human, FIELD_CENTER)
		await _ticks(10)
		await _helicopter_sortie(faction)
		await _drone_strike(faction)
		_field.queue_free()
		await _ticks(5)
	_game.queue_free()
	await _ticks(5)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			"PASS: all-faction helicopter ammo, helipad rearm and resume; drone hold and one-way dive"
		)
	quit(0 if _errors.is_empty() else 1)


func _helicopter_sortie(faction):
	var helicopter = _spawn("Helicopter", _human, Vector3(31, 0, 20))
	var target = _spawn("Tank", _enemy, Vector3(37, 0, 20))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	helicopter.stance = helicopter.Stance.HOLD_FIRE
	await _ticks(10)
	var station = helicopter.global_position * Vector3(1, 0, 1)
	for _index in 12:
		_game.projectile_system.launch(helicopter, target)
	_check(
		helicopter.rockets == 0 and not helicopter.armed(), faction + " helicopter ammo not spent"
	)
	_game.projectile_system.clear()
	target.queue_free()
	await _ticks(2)
	_check(
		(
			helicopter.action != null
			and helicopter.action.get_script().resource_path.ends_with("RecoveringAtService.gd")
		),
		faction + " empty helicopter did not return to service"
	)
	_check(helicopter.resume_point.distance_to(station) < 0.1, faction + " lost sortie station")
	var rearmed = await _until(func(): return helicopter.rockets == 12, 1800)
	_check(rearmed, faction + " helicopter never refilled its rocket load on the helipad")
	_check(_field.services(helicopter), faction + " helicopter refilled away from its helipad")
	await _ticks(5)
	_check(
		not helicopter.resume_point.is_finite(),
		faction + " rearmed helicopter did not resume sortie"
	)
	var returned = await _until(
		func(): return helicopter.global_position_yless.distance_to(station) < 2.0, 1200
	)
	_check(returned, faction + " rearmed helicopter did not return to its station")
	helicopter.queue_free()
	await _ticks(5)


func _drone_strike(faction):
	var drone = _spawn("Drone", _human, Vector3(31, 0, 20))
	var target = _spawn("Tank", _enemy, Vector3(36, 0, 20))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	await _ticks(60)
	_check(drone.stance == drone.Stance.HOLD_FIRE, faction + " drone did not default to Hold Fire")
	var hp = target.hp
	_check(hp == target.hp_max, faction + " idle drone attacked without an order")
	drone.issue_manual_order(load(ACTIONS + "AutoAttacking.gd").new(target))
	_check(
		str(drone.action).begins_with("DroneDive"), faction + " attack did not start a drone dive"
	)
	var drone_ref = weakref(drone)
	var expended = await _until(func(): return drone_ref.get_ref() == null, 300)
	_check(expended, faction + " drone did not expend its airframe")
	_check(not is_instance_valid(target) or target.hp < hp, faction + " drone did not damage armor")
	if is_instance_valid(drone):
		drone.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	await _ticks(5)
