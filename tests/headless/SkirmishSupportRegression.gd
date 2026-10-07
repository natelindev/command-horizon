extends "res://tests/headless/SaveRestoreEdges.gd"

var support_orders


func _run():
	support_orders = load("res://source/match/units/actions/Repairing.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
		enemy.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		var infantry = _support_unit("Infantry", enemy, Vector3(52, 0, 47))
		var tank = _support_unit("Tank", enemy, Vector3(56, 0, 48))
		var robot = _support_unit("RepairRobot", enemy, Vector3(58, 0, 48))
		tank.hp = tank.hp_max * 0.4
		await _frames(20)
		var actors = [infantry, tank, robot]
		enemy._command_army(actors)
		_check(
			is_instance_of(robot.action, support_orders) and robot.action.repair_target() == tank,
			"AI repair robot followed unrepairable infantry instead of wounded armor"
		)
		var hp_before = tank.hp
		await _frames(180)
		_check(tank.hp > hp_before + 2, "AI-assigned repair never restored actual tank health")
		print("SUPPORT ", enemy.faction, " before=", hp_before, " after=", tank.hp)
		await _allocation_rules(enemy, actors, tank, robot)
		await _archive_support(enemy, tank, robot)
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Skirmish support: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _support_unit(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, true)
	return unit


func _allocation_rules(enemy, actors, tank, robot):
	var second = _support_unit("Tank", enemy, Vector3(61, 0, 52))
	var other = _support_unit("RepairRobot", enemy, Vector3(59, 0, 52))
	second.hp = second.hp_max * 0.4
	actors.append_array([second, other])
	await _frames(15)
	enemy._command_support(actors)
	_check(robot.action.repair_target() == tank, "AI abandoned an unfinished legal repair")
	_check(other.action.repair_target() == second, "Two AI robots claimed the same repair channel")
	var before = Vector2(tank.hp, second.hp)
	await _frames(120)
	_check(tank.hp > before.x and second.hp > before.y, "Split support did not heal both vehicles")
	paused = true
	before = Vector2(tank.hp, second.hp)
	var point = robot.position
	await _frames(30)
	_check(
		Vector2(tank.hp, second.hp) == before and robot.position == point,
		"AI support advanced while paused"
	)
	paused = false
	tank.hp = tank.hp_max
	second.hp = second.hp_max
	var worker = _support_unit("Worker", enemy, Vector3(57, 0, 46))
	worker.hp = worker.hp_max * 0.5
	var aircraft = _support_unit("Helicopter", enemy, Vector3(58, 1.5, 47))
	aircraft.hp = aircraft.hp_max * 0.1
	actors.append_array([worker, aircraft])
	await _frames(10)
	enemy._command_support(actors)
	_check(
		robot.action.repair_target() == worker,
		"Healthy escort outranked a damaged repairable worker"
	)
	_check(other.action.repair_target() != aircraft, "Ground support targeted an aircraft")
	var engineer_hp = worker.hp
	await _frames(120)
	_check(worker.hp > engineer_hp, "AI worker repair did not run")
	worker.queue_free()
	await _frames(5)
	enemy._command_support(actors.filter(func(unit): return is_instance_valid(unit)))
	_check(is_instance_of(robot.action, support_orders), "AI did not recover after target death")
	_check(robot.action.repair_target() in [tank, second], "AI escort fallback is not ground armor")
	# Existing invalid archives/orders must be replaced as well as new idle orders.
	robot.action = support_orders.new(actors[0])
	tank.hp = tank.hp_max * 0.4
	enemy._command_support([actors[0], tank, robot])
	_check(robot.action.repair_target() == tank, "Existing invalid infantry repair was retained")
	other.queue_free()
	second.queue_free()
	aircraft.queue_free()
	await _frames(5)
	print(
		"PASS: distinct repair targets, wounded-machine priority, pause and dead/invalid target recovery"
	)


func _archive_support(enemy, tank, robot):
	tank.global_position = Vector3(76, 0, 48)
	game.battlefield.invalidate()
	await _frames(35)
	_check(robot.get_node("Movement")._has_destination, "Support archive did not capture travel")
	var robot_point = robot.global_position
	var target_point = tank.global_position
	paused = true
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "AI support snapshot capture failed")
	if snapshot == null:
		return
	var store = FileStore.new()
	var path = "user://support-%d.json" % OS.get_process_id()
	_check(store.write_file(path, snapshot), "AI support archive write failed")
	var loaded = await Restore.new().restore(self, store.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "AI support restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	enemy = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	enemy.set_process(false)
	var robots = _units(enemy, "RepairRobot")
	robots.sort_custom(
		func(a, b):
			return (
				a.position.distance_squared_to(robot_point)
				< b.position.distance_squared_to(robot_point)
			)
	)
	robot = robots[0]
	_check(is_instance_of(robot.action, support_orders), "Loaded AI support lost its repair action")
	if not is_instance_of(robot.action, support_orders):
		return
	tank = robot.action.repair_target()
	_check(
		tank.player == enemy and tank.position.is_equal_approx(target_point),
		"Loaded repair target changed"
	)
	var before = tank.hp
	game.hud._toggle_pause()
	await _frames(600)
	_check(tank.hp > before + 2, "Restored support did not travel and resume actual healing")
	enemy._command_support([robot])
	_check(
		robot.action == null and not robot.get_node("Movement")._has_destination,
		"No-target support retained stale travel"
	)
	print("PASS: moving support disk archive, resumed healing and no-target cleanup")
