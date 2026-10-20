extends "res://tests/headless/SupplyLineRegression.gd"

var challenge = ""
var guard_ids = []
var air_shots = false


func _initialize():
	create_timer(1800).timeout.connect(
		func():
			push_error("Horizon regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.campaign_challenge = challenge
	settings.mission_id = "command_horizon"
	settings.map_path = "res://source/match/maps/CommandHorizonMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = difficulty
		settings.players.append(side)
	game = load("res://source/match/campaign/CommandHorizon.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _run():
	path = "user://horizon-progress-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	if "--alternate" in OS.get_cmdline_user_args():
		Progress.new().record_foundry_victory(path)
	for value in ["lean", "reinforced"]:
		if ("--" + value) in OS.get_cmdline_user_args():
			challenge = value
	await _make_match()
	_check(await _play_horizon() == true, "Commander stopped before completing assertions")
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Command Horizon: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _play_horizon():
	var human = game._get_human_player()
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return unit.position.x < 20
	)
	var gather = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var workers = _units(human, "Worker")
	for index in workers.size():
		var deposit = deposits[index % deposits.size()]
		if challenge == "lean" and index == 1:
			deposit = deposits.filter(func(unit): return "resource_b" in unit)[0]
		workers[index].issue_manual_order(gather.new(deposit))
	if challenge == "lean":
		var headquarters = _units(human, "CommandCenter")[0].get_node("ProductionQueue")
		for index in 2:
			_check(
				headquarters.produce(load("res://source/match/units/Worker.tscn")) != null,
				"Lean force could not buy economy replacements"
			)
		var economy_start = game.simulation_time
		while _units(human, "Worker").size() < 4 and game.simulation_time - economy_start < 60:
			await _frames(30)
		workers = _units(human, "Worker")
		_check(workers.size() == 4, "Paid economy replacements did not finish")
		for index in range(2, workers.size()):
			workers[index].issue_manual_order(gather.new(deposits[index % 3]))
	for unit in human.get_children():
		if (
			not unit.is_in_group("units")
			or unit.movement_speed <= 0
			or unit.type in ["Worker", "Drone"]
		):
			continue
		if unit.type == "Infantry":
			unit.issue_manual_order(
				attack_move.new(game.map.DEPLOYMENT + Vector3(-1.5, 0, unit.get_index() % 2))
			)
		elif unit.type == "Helicopter":
			unit.issue_manual_order(attack_move.new(game.map.DEPLOYMENT + Vector3(6, 0, 0)))
		else:
			_assign(unit, game.map.DEPLOYMENT)
	var start = game.simulation_time
	while not game.deployed and not game.finished and game.simulation_time - start < 180:
		_track_air()
		_keep_capturers()
		await _frames(30)
	_check(game.deployed, "Could not secure the deployment zone")
	print(
		"HORIZON deployed=",
		game.deployed,
		" time=",
		game.simulation_time,
		" population=",
		human.population()
	)
	await _stage_capture("horizon-deployment", game.map.DEPLOYMENT)
	if not game.deployed:
		_report()
		return
	guard_ids.clear()
	for role in ["Tank", "CombatRobot", "RepairRobot", "Infantry"]:
		var count = {"RepairRobot": 1, "Tank": 4, "CombatRobot": 2, "Infantry": 4}[role]
		if role == "Tank" and challenge == "lean":
			count = 2
		for unit in _units(human, role).slice(0, count):
			guard_ids.append(unit.get_instance_id())
			if role == "Infantry":
				unit.issue_manual_order(
					moving.new(game.map.DEPLOYMENT + Vector3(-1.8, 0, 0.6 * (unit.get_index() % 2)))
				)
			else:
				_assign(unit, game.map.DEPLOYMENT)
	var barracks = _units(human, "Barracks")[0].get_node("ProductionQueue")
	for index in 4:
		_check(barracks.produce(_infantry_scene()) != null, "Could not buy replacement infantry")
	var factory = _units(human, "VehicleFactory")[0].get_node("ProductionQueue")
	var repair_scene = load("res://source/match/units/RepairRobot.tscn")
	var tank_scene = load("res://source/match/units/Tank.tscn")
	_check(factory.produce(repair_scene) != null, "Could not buy replacement repair support")
	for index in 2:
		var purchase_start = game.simulation_time
		var job = factory.produce(tank_scene)
		while job == null and not game.finished and game.simulation_time - purchase_start < 60:
			_reinforce_guard()
			_keep_capturers()
			await _frames(30)
			job = factory.produce(tank_scene)
		_check(job != null, "Could not fund replacement armor through actual harvesting")
	if challenge == "lean":
		var extra_tanks = 0
		var build_start = game.simulation_time
		while not game.finished and game.simulation_time - build_start < 180:
			_track_air()
			_reinforce_guard()
			_keep_capturers()
			if extra_tanks < 2 and factory.produce(tank_scene) != null:
				extra_tanks += 1
			if extra_tanks == 2 and factory.size() == 0 and game.waves_sent == 4:
				break
			await _frames(60)
		_check(
			extra_tanks == 2 and factory.size() == 0,
			"Lean economy could not finish the paid assault force"
		)
	var pass_point = game.map.NORTH if game.alternate_route else game.map.SOUTH
	var stage = pass_point + Vector3(10, 0, 0)
	_move_strike(stage)
	start = game.simulation_time
	while not game.finished and game.simulation_time - start < 100:
		_track_air()
		_reinforce_guard()
		_keep_capturers()
		if _strike_units().filter(func(unit): return unit.position.x > 123).size() >= 5:
			break
		await _frames(30)
	_check(
		_strike_units().any(func(unit): return unit.position.x > 123),
		"Strike force could not cross the ridge"
	)
	await _stage_capture("horizon-pass", pass_point)
	stage = Vector3(143, 0, 42 if game.alternate_route else 92)
	_move_strike(stage)
	await _frames(1800)
	for unit in _strike_units():
		if unit.type == "Infantry":
			unit.issue_manual_order(attack_move.new(game.map.TARGET))
		else:
			_assign(unit, game.map.TARGET + Vector3(-6, 0, 0))
	start = game.simulation_time
	var assault_support_sent = false
	while not game.finished and game.simulation_time - start < 300:
		_track_air()
		_reinforce_guard()
		_keep_capturers()
		if game.command_destroyed and game.opposition.boss_defeated and game.campaign_hero.alive():
			var hero = game.campaign_hero.unit
			if _idle(hero):
				hero.issue_manual_order(moving.new(game.map.TARGET + Vector3(-10, 0, 0)))
		if game.waves_sent == 4 and not assault_support_sent:
			assault_support_sent = true
			if challenge == "lean":
				_check(
					await _buy_assault_support(factory, repair_scene),
					"Lean force could not pay for second field repair support"
				)
			for plane in _units(human, "Helicopter"):
				plane.issue_manual_order(attack_move.new(game.map.TARGET + Vector3(-4, 0, 6)))
			for scout in _units(human, "Drone"):
				scout.issue_manual_order(moving.new(game.map.TARGET + Vector3(-6, 0, 5)))
		var target = (
			game.target_command if game._alive(game.target_command) else game.opposition.boss
		)
		for unit in _strike_units():
			if unit.position.x < 50 and _idle(unit):
				_assign(unit, game.map.TARGET + Vector3(-6, 0, 0))
			if (
				game.simulation_time - start > 90
				and game._alive(target)
				and unit.attack_range != null
			):
				if unit.stance == unit.Stance.HOLD_POSITION or _idle(unit):
					if game.battlefield.is_observed(human, target):
						unit.issue_manual_order(
							load("res://source/match/units/actions/AutoAttacking.gd").new(target)
						)
					else:
						unit.issue_manual_order(attack_move.new(game.map.TARGET))
		await _frames(30)
	_check(game.finished and game.result == "Victory", "Final HQ assault did not reach victory")
	_check(game.opposition.boss_defeated, "Finale siege commander was not defeated")
	_check(air_shots, "Mixed force did not fire an air weapon")
	_report()
	await _stage_capture("horizon-live-result", game.map.TARGET)
	return true


# Vehicles defend a spread position around the point with bounded pursuit; repair robots
# hold a native Guard post behind it and service damaged allies nearby.
func _assign(unit, point):
	if unit.type not in ["Tank", "AdvancedTank", "CombatRobot", "RepairRobot"]:
		unit.issue_manual_order(attack_move.new(point))
		return
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	if unit.type == "RepairRobot":
		behavior.guard(unit, point + Vector3(-9, 0, 0))
		return
	var offset = Vector3(4, 0, (unit.get_index() % 4 - 1.5) * 3)
	if unit.type == "AdvancedTank":
		offset = Vector3(-6, 0, -5 if unit.get_index() % 2 == 0 else 5)
	behavior.set_stance(unit, "defensive")
	unit.issue_manual_order(attack_move.new(point + offset))


func _idle(unit):
	return unit.action == null or (unit.action.has_method("is_idle") and unit.action.is_idle())


func _strike_units():
	return game._get_human_player().get_children().filter(
		func(unit):
			return (
				unit.is_in_group("units")
				and game._alive(unit)
				and unit.movement_speed > 0
				and unit.type not in ["Worker", "Drone", "Helicopter", "Hero"]
				and unit.get_instance_id() not in guard_ids
			)
	)


func _move_strike(point):
	for unit in _strike_units():
		unit.issue_manual_order(
			(
				attack_move.new(point)
				if unit.attack_range != null
				else moving.new(point + Vector3(-4, 0, 0))
			)
		)


func _reinforce_guard():
	load("res://source/match/campaign/CampaignPosts.gd").service(game._get_human_player())
	var infantry = _units(game._get_human_player(), "Infantry")
	var holding = infantry.filter(func(unit): return unit.get_instance_id() in guard_ids)
	for unit in infantry:
		if holding.size() >= 3:
			break
		if unit.get_instance_id() not in guard_ids and unit.position.x < 50:
			guard_ids.append(unit.get_instance_id())
			holding.append(unit)
			unit.issue_manual_order(moving.new(game.map.DEPLOYMENT + Vector3(-1.8, 0, 0.6)))
	var barracks = _units(game._get_human_player(), "Barracks")
	if not barracks.is_empty() and holding.size() < 3:
		var queue = barracks[0].get_node("ProductionQueue")
		if queue.size() < 2:
			queue.produce(_infantry_scene())


func _infantry_scene():
	return load("res://source/match/units/Infantry.tscn")


func _keep_capturers():
	var infantry = _units(game._get_human_player(), "Infantry")
	if game.deployed:
		infantry = infantry.filter(func(unit): return unit.get_instance_id() in guard_ids)
	for unit in infantry.slice(0, 3):
		if (
			unit.position.distance_to(game.map.DEPLOYMENT) > 2.5
			and unit.action != null
			and (
				unit.action.get_script()
				== load("res://source/match/units/actions/WaitingForTargets.gd")
			)
		):
			unit.issue_manual_order(
				moving.new(
					game.map.DEPLOYMENT + Vector3(-1.7, 0, -0.8 + (unit.get_index() % 3) * 0.8)
				)
			)


func _track_air():
	for plane in _units(game._get_human_player(), "Helicopter"):
		if plane.get_meta("next_attack_availability_time", 0) > 0:
			air_shots = true


func _report():
	print(
		"HORIZON result=",
		game.result,
		" time=",
		game.simulation_time,
		" deployed=",
		game.deployed,
		" HQdown=",
		game.command_destroyed,
		" held=",
		game.zone_held(),
		" waves=",
		game.waves_sent,
		" route=",
		game.alternate_route,
		" challenge=",
		challenge
	)
	if game._alive(game.target_command):
		print("HORIZON target HP=", game.target_command.hp)
	for side in [game._get_human_player(), game._enemy]:
		var counts = {}
		for unit in side.get_children():
			if unit.is_in_group("units") and game._alive(unit):
				counts[unit.type] = counts.get(unit.type, 0) + 1
		print(
			"HORIZON survivors ",
			side.faction,
			" ",
			counts,
			" funds=",
			side.resource_a,
			"/",
			side.resource_b
		)
		for unit in _units(side, "Infantry"):
			print("HORIZON infantry ", side.faction, " ", unit.position, " action=", unit.action)
		if side == game._get_human_player():
			for unit in _strike_units():
				print(
					"HORIZON strike ",
					unit.type,
					" ",
					unit.position,
					" hp=",
					unit.hp,
					" action=",
					unit.action
				)
			for plane in _units(side, "Helicopter"):
				print("HORIZON aircraft ", plane.position, " hp=", plane.hp, " action=", plane.action)
			for unit in side.get_children():
				if unit.get_instance_id() in guard_ids:
					print(
						"HORIZON guard ",
						unit.type,
						" ",
						unit.position,
						" hp=",
						unit.hp,
						" behavior=",
						(
							load("res://source/match/orders/UnitBehavior.gd").current(unit)
							if unit.manual_orders != null
							else "structure"
						)
					)


func _stage_capture(_title, _point):
	pass


func _buy_assault_support(factory, repair_scene):
	return factory.produce(repair_scene) != null
