extends "res://tests/headless/ProgramRegression.gd"

var orders


func _run():
	orders = load("res://source/match/orders/ManualOrders.gd")
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
	await _frames(40)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for player in [_human, _enemy]:
		_spawn("VehicleFactory", player, Vector3(15, 0, 12))
		_spawn("CommandLab", player, Vector3(20, 0, 12))
		_check(player.basic_programs_unlocked(), "Fixture unlock failed")
		await _movement_and_authority(player)
		await _targets(player)
		await _combat_and_build(player)
		await _clear()
	await _harvest()
	await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: both factions queued routes, pause, Shift input, replace/Stop/cap/resume; "
				+ "target loss/fog, repair, follow/skip, harvest, attack/attack-move/build handoffs"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _mobile(role, player, point):
	var unit = _spawn(role, player, point, true)
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	return unit


func _movement_and_authority(player):
	var tank = _mobile("Tank", player, Vector3(25, 0, 25))
	await _frames(30)
	tank.program.run()
	await _frames(3)
	paused = true
	var start = tank.global_position
	var first = Vector3(28, 0, 25)
	var last = Vector3(28, 0, 29)
	_check(tank.manual_orders.submit(orders.point_order("move", first)), "First order rejected")
	tank.manual_orders.submit(orders.point_order("move", last), true)
	await _frames(15)
	_check(
		tank.manual_orders.pending.size() == 2 and tank.global_position == start,
		"Paused queue advanced"
	)
	_check(tank.program.mode == "Manual", "Queued command did not suspend program")
	paused = false
	await _frames(500)
	_check(tank.global_position_yless.distance_to(last) < 0.8, "Queued waypoints did not finish")
	_check(
		tank.manual_orders.pending.is_empty() and not tank.manual_orders._engaged,
		"Queue failed to drain"
	)
	_check(tank.program.mode == "Manual", "Program resumed without consent")
	paused = true
	for index in range(orders.LIMIT):
		_check(
			tank.manual_orders.submit(orders.point_order("move", first), true),
			"Queue rejected before limit"
		)
	_check(
		not tank.manual_orders.submit(orders.point_order("move", last), true),
		"Unbounded order queue"
	)
	tank.manual_orders.submit(orders.point_order("move", last))
	_check(tank.manual_orders.pending.size() == 1, "Replacement retained stale orders")
	tank.issue_manual_order(null)
	_check(tank.manual_orders.pending.is_empty(), "Stop retained waiting orders")
	tank.manual_orders.auto_resume = true
	tank.manual_orders.submit(orders.point_order("move", last))
	paused = false
	await _frames(30)
	_check(tank.program.mode == "Running", "Explicit auto-resume did not run program")
	tank.manual_orders.submit(orders.point_order("move", first))
	tank.program.run()
	_check(tank.manual_orders.pending.is_empty(), "Explicit Resume retained manual queue")
	await _frames(3)
	if player == _human:
		root.get_node("MatchSignals").deselect_all_units.emit()
		tank.get_node("Selection").select()
		paused = true
		root.get_node("MatchSignals").terrain_targeted.emit(first)
		var held_key = InputMap.action_get_events("shift_selecting")[0].duplicate()
		held_key.keycode = held_key.physical_keycode
		held_key.pressed = true
		Input.parse_input_event(held_key)
		Input.flush_buffered_events()
		root.get_node("MatchSignals").terrain_targeted.emit(last)
		held_key = held_key.duplicate()
		held_key.pressed = false
		Input.parse_input_event(held_key)
		Input.flush_buffered_events()
		_check(tank.manual_orders.pending.size() == 2, "Human Shift terrain input did not append")
		tank.issue_manual_order(null)
		paused = false
	# Air and conventional infantry use the same manual queue without requiring a chip.
	for role in ["Drone", "Infantry"]:
		var unit = _mobile(role, player, Vector3(32, 0, 25))
		await _frames(20)
		unit.manual_orders.submit(orders.point_order("move", Vector3(34, 0, 25)))
		unit.manual_orders.submit(orders.point_order("move", Vector3(34, 0, 28)), true)
		await _frames(300)
		_check(
			unit.global_position_yless.distance_to(Vector3(34, 0, 28)) < 1,
			"Air/infantry queue failed: " + role
		)
		unit.queue_free()
	tank.queue_free()
	await _frames(3)


func _targets(player):
	var robot = _mobile("RepairRobot", player, Vector3(30, 0, 35))
	var ally = _spawn("Tank", player, Vector3(31, 0, 35))
	ally.hp -= 4
	await _frames(25)
	robot.manual_orders.submit(orders.target_order("repair", ally))
	robot.manual_orders.submit(orders.point_order("move", Vector3(34, 0, 35)), true)
	await _frames(300)
	_check(ally.hp == ally.hp_max, "Queued repair did not heal")
	_check(
		robot.global_position_yless.distance_to(Vector3(34, 0, 35)) < 1,
		"Repair did not release next order"
	)
	robot.manual_orders.submit(orders.target_order("follow", ally))
	robot.manual_orders.submit(orders.point_order("move", Vector3(34, 0, 38)), true)
	await _frames(60)
	_check(robot.manual_orders.pending.size() == 1, "Follow unexpectedly expired")
	robot.manual_orders.skip()
	await _frames(300)
	_check(
		robot.global_position_yless.distance_to(Vector3(34, 0, 38)) < 1,
		"Skip did not advance queue"
	)
	paused = true
	robot.manual_orders.submit(orders.target_order("repair", ally))
	robot.manual_orders.submit(orders.point_order("move", Vector3(32, 0, 38)), true)
	ally.queue_free()
	await _frames(2)
	paused = false
	await _frames(200)
	_check(
		robot.global_position_yless.distance_to(Vector3(32, 0, 38)) < 1, "Dead target wedged queue"
	)
	var opponent = _enemy if player == _human else _human
	var enemy = _spawn("Tank", opponent, Vector3(33, 0, 40))
	var attacker = _mobile("Tank", player, Vector3(30, 0, 40))
	await _frames(30)
	var order = orders.target_order("attack", enemy)
	enemy.global_position = Vector3(80, 0, 80)
	await _frames(20)
	attacker.manual_orders.submit(order)
	await _frames(2)
	_check(
		attacker.action.get_script().resource_path.ends_with("Moving.gd"),
		"Queued attack tracked hidden enemy"
	)
	_check(attacker.action._target_position == order.point, "Hidden target leaked updated position")
	enemy.queue_free()
	robot.queue_free()
	attacker.queue_free()
	await _frames(3)


func _harvest():
	var worker = _mobile("Worker", _human, Vector3(25, 0, 25))
	var hq = _spawn("CommandCenter", _human, Vector3(25, 0, 29))
	var resource = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
	resource.position = Vector3(26, 0, 25)
	_game.map.get_node("Resources").add_child(resource)
	_fixtures.append(resource)
	worker.resources_max = 2
	await _frames(40)
	var stock = _human.resource_a
	worker.manual_orders.submit(orders.target_order("gather", resource))
	worker.manual_orders.submit(orders.point_order("move", Vector3(30, 0, 25)), true)
	await _frames(1600)
	_check(_human.resource_a == stock + 2, "Queued harvest did not deliver exactly one load")
	_check(worker.resource_a == 0, "Harvest queue dropped carried cargo")
	_check(
		worker.global_position_yless.distance_to(Vector3(30, 0, 25)) < 1,
		"Harvest did not yield to next order"
	)
	_check(hq.is_constructed(), "Harvest HQ fixture incomplete")


func _combat_and_build(player):
	root.get_node("MatchSignals").deselect_all_units.emit()
	var opponent = _enemy if player == _human else _human
	for kind in ["attack", "attack_move"]:
		var tank = _spawn("Tank", player, Vector3(40, 0, 30), true)
		var victim = _spawn("Infantry", opponent, Vector3(42, 0, 30))
		victim.hp = 1
		await _frames(30)
		var order = (
			orders.target_order("attack", victim)
			if kind == "attack"
			else orders.point_order("attack_move", Vector3(42, 0, 31))
		)
		tank.process_mode = Node.PROCESS_MODE_INHERIT
		tank.manual_orders.submit(order)
		tank.manual_orders.submit(orders.point_order("move", Vector3(43, 0, 34)), true)
		await _frames(600)
		_check(
			not is_instance_valid(victim), "Queued combat failed to kill visible target: " + kind
		)
		_check(
			tank.global_position_yless.distance_to(Vector3(43, 0, 34)) < 1,
			"Combat failed to release next order: " + kind
		)
		tank.queue_free()
		await _frames(3)
	var worker = _mobile("Worker", player, Vector3(35, 0, 45))
	var building = _spawn("PowerPlant", player, Vector3(38, 0, 45))
	building.mark_as_under_construction()
	building.construct(0.95)
	await _frames(30)
	worker.manual_orders.submit(orders.target_order("construct", building))
	worker.manual_orders.submit(orders.point_order("move", Vector3(35, 0, 48)), true)
	await _frames(600)
	_check(building.is_constructed(), "Queued construction did not finish")
	_check(
		worker.global_position_yless.distance_to(Vector3(35, 0, 48)) < 1,
		"Construction failed to release next order"
	)
	worker.manual_orders.submit(orders.point_order("move", Vector3(32, 0, 48)))
	await _frames(3)
	worker.get_node("Movement").speed = 0.0
	await _frames(360)
	_check("blocked" in worker.manual_orders.status, "Blocked movement has no explanation")
	worker.manual_orders.skip()
	await _frames(3)
	_check(not worker.manual_orders._engaged, "Skip did not release blocked movement")
	worker.queue_free()
	building.queue_free()
	await _frames(3)
