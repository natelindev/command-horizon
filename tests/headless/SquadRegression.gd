extends "res://tests/headless/ProgramRegression.gd"


func _run():
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
		_check(player.basic_programs_unlocked(), "Basic unlock fixture failed")
		await _membership(player)
		await _claims_and_state(player)
		await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: both-faction squads: research/membership/cap/transfers/death; "
				+ "state bounds/isolation; target/repair sharing/manual/pause/fog"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _membership(player):
	var roster = player.squad_roster
	var tank = _spawn("Tank", player, Vector3(26, 0, 25), true)
	var infantry = _spawn("Infantry", player, Vector3(27, 0, 25))
	var worker = _spawn("Worker", player, Vector3(28, 0, 25))
	_check(roster.create("Locked", [tank]) == null, "Squad bypassed Coordination")
	player.resource_a = 100
	player.resource_b = 100
	var labs = player.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandLab"
	)
	_check(player.start_coordination(labs[0]), "Squad research failed")
	player._physics_process(30.0)
	_check(player.coordination_unlocked, "Research did not unlock squads")
	var orders = load("res://source/match/orders/ManualOrders.gd")
	tank.manual_orders.submit(orders.point_order("move", Vector3(30, 0, 25)))
	var first = roster.create("Vanguard", [tank, infantry])
	_check(first != null and tank.program_squad == first, "Squad create failed")
	_check(first.ready_members().size() == 1, "Conventional member counted as program-ready")
	_check(tank.program.mode == "Manual", "Membership started a program")
	_check(tank.manual_orders.pending.size() == 1, "Membership discarded a manual queue")
	var second = roster.create("Support", [worker])
	_check(roster.assign(second, [tank]), "Explicit transfer failed")
	_check(tank not in first.members and tank in second.members, "Unit joined two squads")
	var opponent = _enemy if player == _human else _human
	var foreign = _spawn("Tank", opponent, Vector3(70, 0, 70))
	_check(not roster.assign(second, [infantry, foreign]), "Foreign member accepted")
	_check(infantry.program_squad == first, "Rejected transfer partially mutated membership")
	var building = _spawn("PowerPlant", player, Vector3(30, 0, 15))
	_check(roster.create("Building", [building]) == null, "Structure accepted as squad member")
	var many = []
	for index in range(25):
		many.append(_spawn("Infantry", player, Vector3(40 + index % 5, 0, 20 + index / 5)))
	_check(roster.create("Too many", many) == null, "Squad size cap bypassed")
	var full = roster.create("Full", many.slice(0, 24))
	_check(not roster.assign(full, [tank]), "Transfer exceeded member limit")
	_check(tank.program_squad == second, "Rejected cap transfer detached original membership")
	roster.rename(first, "  Line\nOne  ")
	_check(first.title == "Line One", "Squad name normalization failed")
	infantry.queue_free()
	await _frames(3)
	_check(not is_instance_valid(first), "Last member death retained empty squad")
	roster.disband(second)
	_check(
		tank.program_squad == null and worker.program_squad == null, "Disband retained membership"
	)
	_check(tank.program.mode == "Manual", "Disband changed orders")
	roster.disband(full)
	for unit in many + [tank, worker, foreign, building]:
		unit.queue_free()
	await _frames(3)


func _claims_and_state(player):
	var opponent = _enemy if player == _human else _human
	var one = _spawn("Tank", player, Vector3(25, 0, 30), true)
	var two = _spawn("Tank", player, Vector3(26, 0, 30), true)
	var unchipped = _spawn("Tank", player, Vector3(24, 0, 29))
	var first = _spawn("Tank", opponent, Vector3(28, 0, 30))
	var second = _spawn("Tank", opponent, Vector3(28, 0, 32))
	var squad = player.squad_roster.create("Guard", [one, two, unchipped])
	for unit in [one, two]:
		unit.program.set_status("Running", "Test guard")
	_check(squad.write_state(one, "targets", {"ids": [1, 2]}), "Valid shared state rejected")
	var copy = squad.state_snapshot(two)
	copy.targets.ids[0] = 9
	_check(squad.state_snapshot(one).targets.ids[0] == 1, "Shared snapshot mutated stored state")
	_check(not squad.write_state(unchipped, "cheat", 1), "Unchipped member wrote shared state")
	_check(not squad.write_state(first, "cheat", 1), "Foreign unit wrote shared state")
	_check(not squad.write_state(one, "large", "é".repeat(5000)), "UTF-8 state byte limit bypassed")
	_check(not squad.write_state(one, "bad", INF), "Nonfinite state accepted")
	_check(not squad.write_state(one, "node", one), "Engine object accepted into shared state")
	_check(not squad.write_state(one, "deep", [[[[[[1]]]]]]), "Deep state accepted")
	_check(not squad.write_state(one, "list", range(65)), "Unbounded array accepted")
	_check(squad.state_snapshot(one).size() == 1, "Rejected writes changed shared state")
	squad.claim(one, first)
	_check(
		squad.target_bias(two, first) > squad.target_bias(two, second),
		"Spread ignored claimed target"
	)
	squad.set_policy("focus")
	squad.claim(one, first)
	_check(
		squad.target_bias(two, first) < squad.target_bias(two, second), "Focus ignored squad target"
	)
	_check(not squad.set_policy("unknown"), "Invalid policy accepted")
	squad.set_policy("independent")
	squad.claim(one, first)
	_check(squad.target_bias(two, first) == 0, "Independent retained sharing")
	squad.set_policy("spread")
	squad.claim(one, first)
	one.issue_manual_order(null)
	_check(squad.target_bias(two, first) == 0, "Manual order retained target claim")
	_check(squad.state_snapshot(one).is_empty(), "Manual override retained shared-state access")
	one.program.set_status("Running", "Test guard")
	squad.claim(one, first)
	paused = true
	await _frames(90)
	_check(squad.target_bias(two, first) > 0, "Paused claims expired on wall clock")
	paused = false
	await _frames(60)
	_check(squad.target_bias(two, first) == 0, "Stale claim did not expire")
	# Exercise real preset selection, with firing disabled only on the test action node.
	var action_script = load("res://source/match/programs/PresetAction.gd")
	var action = action_script.new(two.program)
	two.action = action
	two.program.set_status("Running", "Test guard")
	squad.claim(one, first)
	var chosen = action._pick_target(two.global_position_yless, 6.0)
	_check(chosen == second, "Preset did not apply spread policy")
	squad.set_policy("focus")
	squad.claim(one, first)
	_check(
		action._pick_target(two.global_position_yless, 6.0) == first,
		"Preset did not apply focus policy"
	)
	first.global_position = Vector3(80, 0, 80)
	_game.battlefield.invalidate()
	_check(
		action._pick_target(two.global_position_yless, 6.0) == second,
		"Squad claim exposed hidden target"
	)
	# Repair claims avoid two robots choosing the same damaged ally.
	var repair_one = _spawn("RepairRobot", player, Vector3(24, 0, 33))
	var repair_two = _spawn("RepairRobot", player, Vector3(25, 0, 32))
	player.squad_roster.assign(squad, [repair_one, repair_two])
	for unit in [repair_one, repair_two]:
		unit.program.set_status("Running", "Test service")
	one.hp = one.hp_max * 0.5
	two.hp = two.hp_max * 0.6
	squad.claim(repair_one, one, "repair")
	var service = action_script.new(repair_two.program)
	repair_two.action = service
	repair_two.program.set_status("Running", "Test service")
	service._service(Vector3(25, 0, 31), 6.0)
	_check(service.repair_target() == two, "Repair claim failed to spread service")
	player.squad_roster.remove(one)
	_check(not squad.can_share(one), "Removed unit retained shared capability")
	_check(squad.state_snapshot(two).has("targets"), "Removing one member erased squad state")
	player.squad_roster.disband(squad)
	_check(two.action == action, "Disband stopped an individual program")
	await _frames(3)
	_check(not is_instance_valid(squad), "Disband retained shared state container")
