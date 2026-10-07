extends "res://tests/headless/FrontierGameplayRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)
	var shoot = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	for target_role in ["Tank", "Infantry"]:
		var cannon = _spawn_frontier("AdvancedTank", human, Vector3(22, 0, 22))
		var target = _spawn_frontier(target_role, enemy, Vector3(25, 0, 22))
		target.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(8)
		_check(game.battlefield.can_fire(cannon, target), "Cannon fixture has no firing line")
		var hp = target.hp
		var attack = shoot.new(target, 1)
		cannon.issue_manual_order(attack)
		await _frames(35)
		var expected = 23.4 if target_role == "Tank" else 6.3
		_check(
			is_equal_approx(hp - target.hp, expected),
			"Real heavy cannon hit differs vs " + target_role
		)
		_check(cannon.weapon_charge_progress < 0, "Heavy cannon started precision preparation")
		cannon.queue_free()
		target.queue_free()
		await _frames(3)
	var jackal = _spawn_frontier("CombatRobot", human, Vector3(22, 0, 22))
	var drone = _spawn_frontier("Drone", enemy, Vector3(25, 3, 22))
	drone.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(8)
	_check(not jackal.can_switch_weapon(), "Jackal inherited Helix weapon switching")
	_check(game.battlefield.can_fire(jackal, drone), "Jackal cannot acquire nearby aircraft")
	var hp = drone.hp
	jackal.issue_manual_order(shoot.new(drone, 1))
	await _frames(45)
	_check(is_equal_approx(hp - drone.hp, jackal.attack_damage), "Real Jackal AA hit differs")
	drone.position = Vector3(27.2, 3, 22)
	_check(not game.battlefield.can_fire(jackal, drone), "Jackal exceeds 4.5 m AA range")
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier combat: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
