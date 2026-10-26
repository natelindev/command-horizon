extends "res://tests/headless/FixedWingFlightRegression.gd"

# Exercise helicopter sorties, Helix EW scouts and the other factions' one-way drones.


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
	await _airfield_lookup()
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
			"PASS: all-faction helicopter sorties; Helix EW scout and Bastion/Frontier drone dives"
		)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _airfield_lookup():
	var helicopter = _spawn("Helicopter", _human, Vector3(30, 0, 20))
	helicopter.stance = helicopter.Stance.HOLD_FIRE
	_check(helicopter._home_airfield() == null, "Helicopter invented an absent airfield")
	var hostile = _spawn("AircraftFactory", _enemy, Vector3(31, 0, 20))
	var building = _spawn("AircraftFactory", _human, Vector3(20, 0, 20))
	building.mark_as_under_construction()
	_check(helicopter._home_airfield() == null, "Helicopter chose enemy or unfinished airfield")
	building.construct(1.0)
	_check(
		helicopter._home_airfield() == building, "Completed airfield was not available immediately"
	)
	var nearer = _spawn("AircraftFactory", _human, Vector3(29, 0, 20))
	_check(helicopter._home_airfield() == nearer, "Helicopter did not choose nearest airfield")
	nearer.queue_free()
	_check(helicopter._home_airfield() == building, "Removed airfield stayed in service lookup")
	building.queue_free()
	_check(helicopter._home_airfield() == null, "Helicopter retained its last removed airfield")
	hostile.queue_free()
	helicopter.queue_free()
	await _ticks(5)


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
	if faction == "helix":
		_check(drone.attack_range == null and not drone.armed(), "Helix EW scout gained a weapon")
		_check(not str(drone.action).begins_with("DroneDive"), "Helix scout accepted a dive order")
		await _ticks(300)
		_check(is_instance_valid(drone), "Helix scout expended its unarmed airframe")
		_check(target.hp == hp, "Helix unarmed scout damaged armor")
		drone.queue_free()
		target.queue_free()
		await _ticks(5)
		return
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
