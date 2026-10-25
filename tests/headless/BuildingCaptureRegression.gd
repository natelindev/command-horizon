extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var human = game._get_human_player()
	var targets = [
		game.get_node("NeutralWorld").buildings.filter(func(building): return building.habitable)[0],
		game.map.points_of_interest[0]
	]
	for index in targets.size():
		var building = targets[index]
		var soldier = load("res://source/match/units/Infantry.tscn").instantiate()
		var point = building.global_position + Vector3(building.radius + 0.8, 0, 0)
		game._setup_and_spawn_unit(soldier, Transform3D(Basis(), point), human, false)
		soldier.stance = soldier.Stance.HOLD_FIRE
		await _frames(45)
		soldier.manual_orders.submit(
			load("res://source/match/orders/ManualOrders.gd").target_order("garrison", building)
		)
		await _frames(400)
		_check(building.player == null, "Ownership changed before 15 seconds")
		_check(building._capture_indicator.visible, "No capture progress indicator")
		_check(
			soldier.action != null and soldier.action._capture_elapsed >= 6,
			"Infantry did not operate at building"
		)
		soldier.hp -= 1.0
		await _frames(3)
		_check(
			not building._capture_indicator.visible and building.player == null,
			"Damage did not interrupt capture"
		)
		soldier.manual_orders.submit(
			load("res://source/match/orders/ManualOrders.gd").target_order("garrison", building)
		)
		await _frames(360)
		paused = true
		var builder = Snapshot.new()
		var snapshot = builder.capture(game)
		var soldier_id = builder._reference(soldier)
		var building_id = builder._reference(building)
		var loader = Restore.new()
		var loaded = await loader.restore(self, snapshot)
		_check(loaded.ok, "Capture archive failed: " + loaded.get("error", ""))
		if not loaded.ok:
			paused = false
			break
		game = loaded.game
		human = game._get_human_player()
		building = loader.entities[building_id]
		soldier = loader.entities[soldier_id]
		targets = [
			game.get_node("NeutralWorld").buildings.filter(func(other): return other.habitable)[0],
			game.map.points_of_interest[0]
		]
		_check(building._capture_indicator.visible, "Paused restore lost capture indicator")
		var elapsed = soldier.action._capture_elapsed
		await _frames(10)
		_check(soldier.action._capture_elapsed == elapsed, "Paused capture advanced")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = false
		await _frames(650)
		_check(building.player == human, "Building did not change ownership after capture")
		_check(not building._capture_indicator.visible, "Completed capture left progress visible")
		if soldier.has_meta("garrison_host"):
			soldier.issue_manual_order(null)
			await _frames(3)
		var tank = _units(human, "Tank")[0]
		tank.global_position = building.global_position + Vector3(building.radius + 4, 0, 0)
		tank.process_mode = Node.PROCESS_MODE_INHERIT
		game.battlefield.invalidate()
		var rules = load("res://source/match/combat/CombatRules.gd")
		_check(not rules.can_target(tank, building), "Empty building became an automatic target")
		_check(rules.can_force_target(tank, building), "Owned building rejected Force Attack")
		root.get_node("MatchSignals").deselect_all_units.emit()
		tank.get_node("Selection").select()
		var commands = game.hud.direct_orders
		commands.arm("attack")
		_check(
			commands.commit(tank.global_position + Vector3(3, 0, 0), null, false),
			"A-click ground rejected"
		)
		_check(
			(
				tank.manual_orders.current.get("kind") == "attack_move"
				or tank.manual_orders.pending.any(func(order): return order.kind == "attack_move")
			),
			"A-click empty ground did not attack move"
		)
		tank.manual_orders.cancel()
		commands.arm("force_attack")
		_check(
			commands.commit(building.global_position, building, false),
			"Force Attack command rejected building"
		)
		var hp_before = building.hp
		await _frames(200)
		_check(building.hp < hp_before, "Force Attack projectiles did not damage building")
		building.hp = 1.0
		await _frames(200)
		_check(
			building.hp <= 0 and building.player == null,
			"Force Attack did not destroy/release building"
		)
		tank.issue_manual_order(null)
		tank.process_mode = Node.PROCESS_MODE_DISABLED
		soldier.process_mode = Node.PROCESS_MODE_DISABLED
		print("CAPTURE PASS ", index, " elapsed=", elapsed)
	await _friendly_force_attack()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Building capture and contextual attack: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _friendly_force_attack():
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var target = _units(human, "CommandCenter")[0]
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	tank.global_position = target.global_position + Vector3(-5, 0, 3)
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	game.battlefield.invalidate()
	var commands = game.hud.direct_orders
	commands.arm("attack")
	_check(not commands.commit(target.global_position, target, false), "A accepted allied building")
	commands.cancel()
	commands.arm("force_attack")
	_check(
		commands.commit(target.global_position, target, false), "Ctrl+A rejected allied building"
	)
	await _frames(4)
	_check(tank.action.force_attack, "Force flag was lost before firing")
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var tank_id = builder._reference(tank)
	var target_id = builder._reference(target)
	var loader = Restore.new()
	var loaded = await loader.restore(self, snapshot)
	_check(loaded.ok, "Force attack save failed: " + loaded.get("error", ""))
	if not loaded.ok:
		paused = false
		return
	game = loaded.game
	tank = loader.entities[tank_id]
	target = loader.entities[target_id]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var hp_before = target.hp
	paused = false
	await _frames(120)
	print(
		"FORCE RESTORE hp=",
		hp_before,
		" -> ",
		target.hp,
		" action=",
		tank.action,
		" legal=",
		load("res://source/match/combat/CombatRules.gd").can_target(tank, target),
		" fireable=",
		game.battlefield.can_fire(tank, target)
	)
	_check(target.hp < hp_before, "Restored Ctrl+A failed to damage allied building")
	tank.issue_manual_order(null)
	var worker = _units(game._get_human_player(), "Worker")[0]
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	worker.global_position = tank.global_position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	tank.manual_orders.submit(
		load("res://source/match/orders/ManualOrders.gd").target_order("force_attack", worker)
	)
	hp_before = worker.hp
	await _frames(100)
	_check(
		not is_instance_valid(worker) or worker.hp < hp_before,
		"Ctrl+A failed to damage allied unit"
	)
	tank.issue_manual_order(null)
	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	_check(
		not load("res://source/match/combat/CombatRules.gd").can_force_target(tank, relay),
		"Force Attack accepted an invulnerable objective"
	)
	relay.free()
