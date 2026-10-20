extends "res://tests/headless/FrontierGameplayRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)
	await _check_role_balance()
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
		await _wait_for_hit(target, hp)
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
	await _wait_for_hit(drone, hp)
	_check(is_equal_approx(hp - drone.hp, jackal.attack_damage), "Real Jackal AA hit differs")
	drone.position = Vector3(29.2, 3, 22)
	_check(not game.battlefield.can_fire(jackal, drone), "Jackal exceeds 6.5 m AA range")
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier combat: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


# Frontier fields rough aircraft and hardened infantry: health, damage and speed
# factors must reach the spawned unit, and saved health must stay valid.
func _check_role_balance():
	var defaults = load("res://source/match/MatchConstants.gd").Units.DEFAULT_PROPERTIES
	var expected = {
		"Infantry": [1.1, 1.15, 1.2],
		"RocketInfantry": [1.1, 1.15, 1.2 * 0.82],
		"Tank": [0.85, 1.0, 1.1],
		"Worker": [0.85, 1.0, 1.1],
		"Drone": [0.7, 0.8, 1.0],
		"Helicopter": [0.7, 0.8, 1.0],
		"Fighter": [0.7, 0.8, 1.0],
		"Bomber": [0.7, 0.8, 1.0],
	}
	for role in expected:
		var path = factions.Bastion.scene_path(role)
		var base = defaults[path]
		var template = load(path).instantiate()
		var base_speed = template.get_node("Movement").speed
		template.free()
		var unit = _spawn_frontier(role, human, Vector3(40, 0, 40))
		var factors = expected[role]
		_check(unit.hp_max == roundi(base.hp_max * factors[0]), "Frontier %s health" % role)
		if base.has("attack_damage"):
			_check(
				is_equal_approx(unit.attack_damage, base.attack_damage * factors[1]),
				"Frontier %s damage" % role
			)
		_check(
			is_equal_approx(unit.get_node("Movement").speed, base_speed * factors[2]),
			"Frontier %s speed" % role
		)
		_check(
			factions.health_factor("frontier", role) == factors[0],
			"Frontier %s save health factor" % role
		)
		unit.queue_free()
	await _frames(3)


func _wait_for_hit(target, previous_hp):
	var deadline = game.simulation_time + 3.0
	while (
		is_instance_valid(target) and target.hp == previous_hp and game.simulation_time < deadline
	):
		await physics_frame
