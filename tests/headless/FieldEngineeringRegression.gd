extends "res://tests/headless/CombatRegression.gd"

var _manager
var _rules


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
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
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_manager = _game.engineering
	_manager.set_physics_process(false)
	_game.repair_service.set_physics_process(false)
	_rules = load("res://source/match/combat/CombatRules.gd")
	await _barricades()
	await _reset()
	await _barricade_right_click()
	await _reset()
	await _mines()
	await _reset()
	await _sweeping()
	await _reset()
	await _persistence()
	await _reset()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Field engineering: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _barricades():
	var engineering_action = load("res://source/match/units/actions/EngineeringAction.gd")
	_human.faction = "bastion"
	_human.resource_a = 1000
	var worker = _spawn("Worker", _human, Vector3(40, 0, 8))
	await _frames(3)
	var point = _find_position(worker, "barricade")
	_check(point.is_finite(), "No legal barricade position found in open test map")
	if not point.is_finite():
		return
	var resources = _human.resource_a
	_check(_manager.request(worker, "barricade", point), "Legal barricade request rejected")
	worker.action._physics_process(0.01)
	var barriers = get_nodes_in_group("engineering_entities")
	_check(barriers.size() == 1, "Instant barrier was not deployed")
	_check(_human.resource_a == resources - 10, "Barricade payment not atomic")
	_check(_manager.cooldown_left(worker) == 15.0, "Barricade cooldown not committed")
	if barriers.is_empty():
		return
	var barrier = barriers[0]
	_check(
		barrier.hp == 80.0 and not barrier.force_attack_only(),
		"Owned barricade combat properties wrong"
	)
	_check(
		barrier.get_node("MovementObstacle").footprint.size() == 4,
		"Barricade has no rectangle footprint"
	)
	_check(
		not _manager.request(worker, "barricade", point + Vector3(4, 0, 0)),
		"Barricade cooldown bypassed"
	)
	var orders = load("res://source/match/players/human/UnitActionsController.gd")
	barrier.hp = 60.0
	_check(
		orders.context_kind(worker, barrier) == "repair_barrier",
		"Owner worker cannot repair barricade"
	)
	var repair = engineering_action.new("repair_barrier")
	repair._target = barrier
	worker.action = repair
	repair._physics_process(1.0)
	_check(barrier.hp == 70.0, "Barricade worker repair failed")
	var dismantle = engineering_action.new("dismantle")
	dismantle._target = barrier
	worker.action = dismantle
	dismantle._physics_process(1.99)
	_check(barrier.hp > 0.0, "Barricade dismantled too early")
	dismantle._physics_process(0.01)
	_check(
		barrier.hp == 0.0 and _human.resource_a == resources - 11,
		"Dismantle refund or completion incorrect"
	)
	_manager._physics_process(15.0)
	_check(_manager.cooldown_left(worker) == 0.0, "Barricade cooldown did not expire")


func _barricade_right_click():
	_human.faction = "bastion"
	_human.resource_a = 1000
	var worker = _spawn("Worker", _human, Vector3(40, 0, 8))
	worker.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	await _frames(3)
	var point = _find_position(worker, "barricade")
	_check(point.is_finite(), "No legal position for barricade input regression")
	if not point.is_finite():
		return
	var barrier = _manager._spawn_barricade(_human, point, 0.0, "engineering-barricade-input")
	worker.manual_orders.cancel()
	worker.action = null
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(point)
	_game.hud.select_units([worker])
	await _frames(8)
	var pointer = camera.unproject_position(point + Vector3.UP * .4)
	_check(_game.hud._pick_unit(pointer) == barrier, "Barricade click fixture picks another object")
	var targeted = []
	var record_target = func(target): targeted.append(target)
	root.get_node("MatchSignals").unit_targeted.connect(record_target)
	await _barrier_mouse(pointer, MOUSE_BUTTON_RIGHT)
	root.get_node("MatchSignals").unit_targeted.disconnect(record_target)
	_check(barrier in targeted, "Right-click did not traverse the actual barricade input route")
	_check(
		worker.manual_orders.current.get("kind", "") not in ["dismantle", "attack", "force_attack"],
		"Healthy barricade right-click issued a destructive order"
	)
	worker.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(ceili(2.2 * Engine.physics_ticks_per_second))
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	var survives = is_instance_valid(barrier) and barrier.hp == barrier.hp_max
	_check(survives, "Healthy owned barricade was destroyed by right-click after two seconds")
	if not survives:
		return
	_check(_human.resource_a == 1000, "Healthy barricade right-click spent or refunded resources")
	barrier.hp = 60.0
	await _barrier_mouse(pointer, MOUSE_BUTTON_RIGHT)
	_check(
		worker.manual_orders.current.get("kind", "") == "repair_barrier",
		"Damaged barricade right-click lost contextual repair"
	)
	worker.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(ceili(1.1 * Engine.physics_ticks_per_second))
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	_check(barrier.hp == 70.0, "Damaged barricade right-click did not perform paid repair")
	_check(_human.resource_a == 999, "Contextual barricade repair changed its resource cost")
	barrier.hp = barrier.hp_max
	for down in [true, false]:
		var key = InputEventKey.new()
		key.keycode = KEY_R
		key.physical_keycode = KEY_R
		key.pressed = down
		root.push_input(key, true)
		await _frames(3)
	_check(
		_game.hud.direct_orders.ability_id == "dismantle_barrier",
		"Explicit R did not arm barricade dismantling"
	)
	await _barrier_mouse(pointer, MOUSE_BUTTON_LEFT)
	_check(
		worker.manual_orders.current.get("kind", "") == "dismantle",
		"Explicit R plus target click did not issue dismantling"
	)
	worker.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(floori(1.9 * Engine.physics_ticks_per_second))
	_check(
		is_instance_valid(barrier) and barrier.hp > 0, "Explicit R dismantled before two seconds"
	)
	await _frames(ceili(.2 * Engine.physics_ticks_per_second))
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not is_instance_valid(barrier), "Explicit R failed to dismantle after two seconds")
	_check(_human.resource_a == 999, "Explicit dismantling unexpectedly refunded resources")


func _barrier_mouse(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await _frames(2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)
		await _frames(3)


func _mines():
	_human.faction = "frontier"
	_human.resource_a = 1000
	var lab = _spawn("CommandLab", _human, Vector3(60, 0, 15))
	var worker = _spawn("Worker", _human, Vector3(40, 0, 8))
	await _frames(3)
	_check(lab.is_constructed(), "Workshop fixture incomplete")
	var point = _find_position(worker, "mine")
	_check(point.is_finite(), "No legal mine position found")
	if not point.is_finite():
		return
	var resources = _human.resource_a
	_check(_manager.request(worker, "mine", point), "Frontier mine request rejected")
	worker.action._physics_process(1.0)
	var mine = get_nodes_in_group("field_mines")[0]
	_check(
		mine.deploy_left == 2.0 and _human.resource_a == resources - 8, "Mine deploy/payment wrong"
	)
	worker.action._physics_process(2.0)
	_check(mine.deploy_left == 0.0 and mine.arm_left == 2.0, "Mine deployment skipped arming")
	mine.advance(2.0)
	var shooter = _spawn("Infantry", _enemy, point + Vector3(5, 0, 0))
	var detector = _spawn("Worker", _enemy, point + Vector3(11, 0, 0))
	await _frames(3)
	_check(mine.known_to(_enemy), "Mobile observer did not detect mine")
	_check(not _rules.can_target(shooter, mine), "Mine acquired automatically")
	_check(_rules.can_target(shooter, mine, true), "Explicit mine attack rejected")
	_check(_game.battlefield.is_observed(_enemy, mine), "Mine detection did not reach Battlefield")
	shooter.global_position = point + Vector3(8, 0, 0)
	_check(mine.known_to(_enemy), "Worker 12m detector failed")
	detector.global_position = point + Vector3(14, 0, 0)
	_check(not mine.known_to(_enemy), "Ordinary detector exceeded 6m")
	shooter.global_position = point + Vector3(6, 0, 0)
	_check(mine.known_to(_enemy), "Six-metre detector boundary rejected")
	_check(not _manager.can_trigger(detector, mine), "Worker triggers mines")
	shooter.global_position = point + Vector3(-4, 0, 0)
	mine.remember_positions()
	shooter.global_position = point + Vector3(4, 0, 0)
	mine.advance(0.016)
	_check(mine.fuse_left == 0.35, "Fast swept crossing tunneled through mine")
	mine.receive_shot(null, point, 0.001)
	_check(mine.hp == 0.0, "A successful small weapon hit failed to clear mine")
	var detonation = _manager._spawn_mine(_human, point, "engineering-mine-test")
	detonation.deploy_left = 0.0
	detonation.arm_left = 0.0
	detonation.fuse_left = 0.01
	shooter.global_position = point
	_game.battlefield.invalidate()
	var before = shooter.hp
	detonation.advance(0.01)
	_check(
		is_equal_approx(shooter.hp, maxf(0.0, before - 45.0 * 0.75)),
		"Mine damage/falloff armor wrong"
	)
	_check(detonation.hp == 0.0, "Mine did not clear after explosion")


func _sweeping():
	_human.faction = "helix"
	var worker = _spawn("Worker", _human, Vector3(40, 0, 8))
	var first = _manager._spawn_mine(_enemy, Vector3(42, 0, 8), "engineering-mine-sweep1")
	var second = _manager._spawn_mine(_enemy, Vector3(38, 0, 8), "engineering-mine-sweep2")
	for mine in [first, second]:
		mine.deploy_left = 0.0
		mine.arm_left = 0.0
	await _frames(3)
	_check(
		_manager.request(worker, "sweep", worker.global_position),
		"Non-Frontier worker cannot sweep"
	)
	var action = worker.action
	action._physics_process(0.01)
	action._physics_process(0.99)
	_check(first.hp + second.hp == 2.0, "Sweep cleared mine before 1s")
	action._physics_process(0.01)
	_check(first.hp + second.hp == 1.0, "Sweep failed its first mine")
	action._physics_process(0.01)
	action._physics_process(1.0)
	_check(first.hp + second.hp == 0.0, "Sweep did not continue to second mine")
	_check(action.search_path.size() > 1, "Sweep has no real traversal to discover obscured mines")
	worker.manual_orders.cancel()
	worker.action = null
	_check(not is_instance_valid(worker.action), "New order did not cancel sweep")


func _persistence():
	var worker = _spawn("Worker", _human, Vector3(40, 0, 8))
	var mine = _manager._spawn_mine(_enemy, Vector3(45, 0, 8), "engineering-mine-restore")
	mine.deploy_left = 0.0
	mine.arm_left = 0.0
	mine.fuse_left = 0.17
	_manager._cooldowns[worker] = 7.25
	var references = {_human: "player-0", _enemy: "player-1", worker: "unit-0"}
	var state = _manager.capture_state(func(entity): return references.get(entity, ""))
	_check(
		state.entities.size() == 1 and state.entities[0].fuse_left == 0.17,
		"Mine fuse was not saved"
	)
	mine.free()
	var entities = {"player-0": _human, "player-1": _enemy, "unit-0": worker}
	_manager.restore_state(state, entities)
	var restored = entities.get("engineering-mine-restore")
	_check(restored != null and restored.fuse_left == 0.17, "Mine identity/fuse not restored")
	_check(_manager.cooldown_left(worker) == 7.25, "Worker cooldown not restored")
	var idle = _manager._spawn_mine(_enemy, Vector3(48, 0, 8), "engineering-mine-cleanup")
	_manager.dispose_owner(_enemy)
	_check(
		idle.hp == 0 and restored.hp > 0,
		"Owner elimination failed untriggered/committed fuse split"
	)


func _find_position(worker, kind):
	for z in range(8, 56, 5):
		for x in range(8, 56, 5):
			var point = _game.map.ground_point(Vector2(x, z))
			worker.global_position = point + Vector3(0, 0, 2.8)
			_game.battlefield.invalidate()
			if _manager.placement_error(worker, kind, point) == "":
				return point
	return Vector3.INF


func _reset():
	for entity in get_nodes_in_group("engineering_entities"):
		entity.queue_free()
	_manager._cooldowns.clear()
	_manager._reservations.clear()
	await _clear()
