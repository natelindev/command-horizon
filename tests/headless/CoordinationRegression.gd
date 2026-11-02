extends "res://tests/headless/MatchFixture.gd"

var _factions


func _run():
	_factions = load("res://source/match/FactionCatalog.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
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
	await _frames(30)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	for player in [_human, _enemy]:
		await _research_tests(player)
	await _ai_orders()
	await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: both-faction Coordination costs/cancel/power/pause/lab loss; "
				+ "production gate; AI orders"
			)
		)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _research_tests(player):
	var offset = 0 if player == _human else 45
	var factory = _spawn("VehicleFactory", player, Vector3(20 + offset, 0, 20))
	var lab = _spawn("CommandLab", player, Vector3(10 + offset, 0, 20))
	# The HQ alone cannot power a factory and lab; research starts at full power.
	_spawn("PowerPlant", player, Vector3(30 + offset, 0, 20))
	player.set_physics_process(false)
	player.resource_a = 100
	player.resource_b = 100
	lab._construction_progress = 0.5
	_check(not player.start_coordination(lab), "Unfinished lab started research")
	lab._construction_progress = 1.0
	_check(not _factions.available(player, "AdvancedTank"), "Lab alone unlocked long-range armor")
	_check(
		factory.production_queue.produce(load(Catalog.scene_path("AdvancedTank"))) == null,
		"Production bypassed Coordination"
	)
	_check(player.start_coordination(lab), "Valid Coordination rejected")
	_check(player.resource_a == 80 and player.resource_b == 80, "Research charged wrong fee")
	_check(not player.start_coordination(lab), "Duplicate research accepted")
	player._physics_process(10.0)
	_check(
		is_equal_approx(player.coordination_left, 20.0),
		(
			"Research timing incorrect: %.2f s left at power factor %.2f"
			% [player.coordination_left, player.production_factor()]
		)
	)
	_check(player.cancel_coordination(), "Research cancellation failed")
	_check(
		player.resource_a == 100 and player.resource_b == 100,
		"Research did not refund reserved cost"
	)
	_check(not player.cancel_coordination(), "Research double-refund permitted")
	player.resource_a = 19
	_check(not player.start_coordination(lab), "Unaffordable research accepted")
	player.resource_a = 100
	player.start_coordination(lab)
	var drains = []
	for index in range(2):
		drains.append(_spawn("AircraftFactory", player, Vector3(10 + offset + index * 7, 0, 38)))
	_check(player.production_factor() == 0.25, "Fixture failed to create low power")
	player._physics_process(10.0)
	_check(is_equal_approx(player.coordination_left, 27.5), "Low power did not slow research")
	player.set_physics_process(true)
	paused = true
	var before = player.coordination_left
	await _frames(20)
	_check(player.coordination_left == before, "Paused research advanced")
	paused = false
	await _frames(12)
	_check(player.coordination_left < before, "Research did not resume")
	player.set_physics_process(false)
	lab.queue_free()
	for drain in drains:
		drain.queue_free()
	await _frames(3)
	before = player.coordination_left
	player._physics_process(30.0)
	_check(
		player.coordination_left == before and "paused" in player.coordination_status(),
		"Lab loss discarded or advanced research"
	)
	lab = _spawn("CommandLab", player, Vector3(10 + offset, 0, 20))
	player._physics_process(before)
	_check(
		player.coordination_unlocked and player.coordination_left == 0,
		"Replacement lab did not finish preserved research"
	)
	_check(player.resource_a == 80 and player.resource_b == 80, "Resumed research charged again")
	_check(
		_factions.available(player, "AdvancedTank"),
		"Coordination failed to unlock long-range armor"
	)
	_check(
		not player.cancel_coordination() and not player.start_coordination(lab),
		"Completed tech charged/refunded again"
	)
	var job = factory.production_queue.produce(load(Catalog.scene_path("AdvancedTank")))
	_check(job != null, "Long-range armor remained unavailable")
	job.time_left = 1.0
	lab.queue_free()
	await _frames(3)
	factory.production_queue._process(5.0)
	_check(
		job.time_left == 1 and player.coordination_unlocked,
		"Lab loss failed production gate or erased tech"
	)
	_spawn("CommandLab", player, Vector3(10 + offset, 0, 20))
	factory.production_queue.cancel(job)


func _ai_orders():
	var drone = _spawn("Drone", _enemy, Vector3(70, 0, 70))
	var robot = _spawn("RepairRobot", _enemy, Vector3(73, 0, 70))
	var tank = _spawn("Tank", _enemy, Vector3(76, 0, 70))
	for unit in [drone, robot]:
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(35)
	# Make the target eligible after idle units settle. Healthy reserves do
	# not request escorts, and an active repair should retain control.
	tank.hp = tank.hp_max * .8
	_enemy._command_army([drone, robot, tank])
	_check(drone.get_node("Movement")._has_destination, "Idle drone ignored AI scouting")
	_check(robot.action.has_method("repair_target"), "Idle repair robot ignored AI support order")
	await _frames(40)
	_check(robot.action.has_method("repair_target"), "AI repair order did not persist")
