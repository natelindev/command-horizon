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
		var hp = target.hp + target.shields
		var fired_at = game.simulation_time
		var attack = shoot.new(target, 1)
		cannon.issue_manual_order(attack)
		await _wait_for_hit(target, hp)
		var expected = 4.5 if target_role == "Tank" else 12.5
		_check(
			is_equal_approx(hp - target.hp - target.shields, expected),
			"Real twin Battle Rig hit differs vs " + target_role
		)
		_check(
			game.simulation_time - fired_at < 1.0, "Battle Rig inherited a long precision charge"
		)
		cannon.queue_free()
		target.queue_free()
		await _frames(3)
	var jackal = _spawn_frontier("AntiAirVehicle", human, Vector3(22, 0, 22))
	var drone = _spawn_frontier("Drone", enemy, Vector3(25, 3, 22))
	drone.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(8)
	_check(
		not jackal.has_method("can_switch_weapon"), "SAM Technical inherited Helix weapon switching"
	)
	_check(game.battlefield.can_fire(jackal, drone), "SAM Technical cannot acquire nearby aircraft")
	var hp = drone.hp + drone.shields
	jackal.issue_manual_order(shoot.new(drone, 1))
	await _wait_for_hit(drone, hp)
	_check(
		is_equal_approx(hp - drone.hp - drone.shields, jackal.attack_damage),
		"Real SAM Technical AA hit differs"
	)
	drone.position = jackal.position + Vector3(jackal.attack_range + 1.0, 3, 0)
	game.battlefield.invalidate()
	_check(
		not game.battlefield.can_fire(jackal, drone), "SAM Technical exceeds its authored AA range"
	)
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier combat: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


# Frontier fields rough aircraft and hardened infantry: health, damage and speed
# factors must reach the spawned unit, and saved health must stay valid.
func _check_role_balance():
	var defaults = load("res://source/match/MatchConstants.gd").Units.DEFAULT_PROPERTIES
	var expected = {
		"Infantry": [1.1, 1.15, 1.2],
		"RocketInfantry": [1.1, 1.15, 1.2 * 0.82],
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
	for role in ["Tank", "AdvancedTank", "CombatRobot"]:
		var unit = _spawn_frontier(role, human, Vector3(40, 0, 40))
		var authored = {
			"Tank": [75.0, 7.0, 4.8],
			"AdvancedTank": [120.0, 5.0, 4.2],
			"CombatRobot": [28.0, 125.0, 7.0]
		}[role]
		_check(
			(
				unit.hp_max == authored[0]
				and unit.attack_damage == authored[1]
				and is_equal_approx(unit.get_node("Movement").speed, authored[2])
			),
			"Dedicated Frontier role statistics differ: " + role
		)
		unit.queue_free()
	await _frames(3)


func _spawn_frontier(role, owner, point):
	var unit = load(factions.scene_path(owner.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, false)
	return unit


func _wait_for_hit(target, previous_hp):
	var deadline = game.simulation_time + 3.0
	while (
		is_instance_valid(target)
		and target.hp + target.shields == previous_hp
		and game.simulation_time < deadline
	):
		await physics_frame
	# Both independently travelling barrels must finish the one-shot event.
	for frame in 8:
		await physics_frame
