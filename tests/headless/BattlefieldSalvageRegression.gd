extends "res://tests/headless/FrontierGameplayRegression.gd"

var salvage_trait


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	salvage_trait = load("res://source/match/units/traits/BattlefieldSalvage.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	for unit in get_nodes_in_group("units"):
		unit.stance = unit.Stance.HOLD_FIRE
	await _vehicle_reuse()
	await _engineer_dismantling()
	await _air_wrecks_and_doctrine()
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Battlefield salvage trait: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _vehicle_reuse():
	var tank = _units(human, "Tank")[0]
	tank.global_position = Vector3(20, 0, 15)
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	var worker = _units(human, "Worker")[0]
	worker.global_position = tank.global_position + Vector3(0.5, 0, 1)
	_check(tank.get_node_or_null("BattlefieldSalvage") != null, "Raider has no salvage component")
	_check(
		worker.get_node_or_null("BattlefieldSalvage") != null, "Engineer has no salvage component"
	)
	_check(not worker.can_scavenge(), "Engineer gained combat vehicle scavenging")
	var attacker = _spawn_frontier("Tank", enemy, Vector3(23, 0, 15))
	attacker.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	_check(
		attacker.get_node_or_null("BattlefieldSalvage") == null,
		"Other faction gained salvage trait"
	)
	var funds = human.resource_a
	for rank in [1, 2, 2]:
		var wreck = _wreck_at(tank.global_position + Vector3(0, 0, 1), 11)
		_check(wreck.can_harvest(worker), "Competing engineer cannot access the same wreck")
		tank.hp = tank.hp_max * 0.2
		var hp_before = tank.hp
		_check(tank.scavenge(wreck), "Vehicle could not cannibalize adjacent wreck")
		_check(is_equal_approx(tank.hp, hp_before + tank.hp_max * 0.35), "Wreck repair changed")
		_check(tank.permanent_scrap_rank == rank, "Permanent scrap armor did not cap at rank two")
		_check(tank.scrap_hardened_tiers == rank, "Timed hardening did not cap at rank two")
		_check(
			not wreck.dismantle(worker), "Engineer reused a wreck already cannibalized by vehicle"
		)
		_check(not tank.scavenge(wreck), "Vehicle consumed the same wreck twice")
	_check(human.resource_a == funds, "Combat scavenging also minted materials")
	tank.battlefield_salvage.tick(60.0)
	_check(
		tank.scrap_hardened_tiers == 0 and tank.scrap_hardened_left == 0.0,
		"Timed scrap did not expire"
	)
	_check(tank.permanent_scrap_rank == 2, "Timed expiry removed permanent armor")
	tank.hp = tank.hp_max * 0.7
	var hp_before = tank.hp
	tank.receive_damage(attacker, 10.0)
	_check(
		is_equal_approx(tank.hp, hp_before - 9.0),
		"Permanent armor reduction was lost or applied twice"
	)


func _engineer_dismantling():
	var worker = _units(human, "Worker")[0]
	worker.global_position = Vector3(20, 0, 20)
	worker.resource_a = 2
	var tank = _units(human, "Tank")[0]
	tank.global_position = Vector3(22, 0, 20)
	var infantry = _spawn_frontier("Infantry", human, Vector3(20, 0, 22))
	var far_vehicle = _spawn_frontier("AntiAirVehicle", human, Vector3(35, 0, 20))
	var hostile = _spawn_frontier("Tank", enemy, Vector3(23, 0, 20))
	for unit in [infantry, far_vehicle, hostile]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	var base_wreck = _wreck_at(worker.global_position + Vector3(0, 0, 0.9), 11)
	var funds = human.resource_a
	var controller = load("res://source/match/players/human/UnitActionsController.gd")
	_check(
		controller.context_kind(worker, base_wreck) == "gather",
		"Existing engineer wreck order became inaccessible"
	)
	worker.issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(base_wreck)
	)
	await _frames(30)
	_check(not is_instance_valid(base_wreck), "Engineer right-click order did not dismantle wreck")
	_check(human.resource_a == funds + 11, "Base dismantling did not award exact on-site materials")
	_check(worker.resource_a == 2, "On-site dismantling changed existing cargo")
	worker.issue_manual_order(null)
	human.technology.completed.append("scrap_cannibalization")
	for unit in [tank, infantry, far_vehicle, hostile]:
		unit.hp = unit.hp_max * 0.5
	var tank_hp = tank.hp
	var infantry_hp = infantry.hp
	var far_hp = far_vehicle.hp
	var hostile_hp = hostile.hp
	var wreck = _wreck_at(worker.global_position + Vector3(0, 0, 0.9), 11)
	funds = human.resource_a
	_check(wreck.dismantle(worker), "Upgraded engineer could not dismantle adjacent wreck")
	_check(human.resource_a == funds + 16, "Cannibalization did not give floor(11 * 1.5) materials")
	_check(
		is_equal_approx(tank.hp, minf(tank.hp_max, tank_hp + 25.0)),
		"Cannibalization did not repair nearby vehicle"
	)
	_check(infantry.hp == infantry_hp, "Vehicle repair healed infantry")
	_check(far_vehicle.hp == far_hp, "Cannibalization repaired a vehicle beyond eight metres")
	_check(hostile.hp == hostile_hp, "Cannibalization repaired hostile armor")
	_check(not wreck.dismantle(worker), "A second engineer dismantle minted materials twice")
	_check(human.resource_a == funds + 16, "Rejected dismantling changed player funds")


func _wreck_at(point, amount):
	var wreck = load("res://source/match/units/non-player/Wreck.tscn").instantiate()
	wreck.position = point
	wreck.resource_a = amount
	game.map.get_node("Resources").add_child(wreck)
	return wreck


func _air_wrecks_and_doctrine():
	var rules = load("res://source/match/economy/SalvageRules.gd")
	var worker = _units(human, "Worker")[0]
	worker.issue_manual_order(null)
	worker.get_node("Movement").relocate(Vector3(25, 0, 30))
	var existing = get_nodes_in_group("salvage_wrecks")
	for role in ["Drone", "Helicopter", "Fighter", "Bomber"]:
		var aircraft = _spawn_frontier(role, enemy, Vector3(26, 12, 30))
		aircraft.process_mode = Node.PROCESS_MODE_DISABLED
		aircraft.hp = 0
		game.wreck_salvage.flush()
		var fresh = get_nodes_in_group("salvage_wrecks").filter(
			func(wreck): return wreck not in existing and wreck.wreck_role == role
		)
		_check(fresh.size() == 1, role + " did not leave exactly one wreck")
		if fresh.size() == 1:
			var wreck = fresh[0]
			_check(wreck.resource_a == rules.amount(enemy.faction, role), role + " salvage yield")
			_check(
				is_equal_approx(wreck.position.y, game.map.height_at(Vector2(26, 30))),
				role + " wreck floated at aircraft altitude"
			)
			existing.append(wreck)
	await _frames(3)
	human.technology.completed.append("salvage_war_machine")
	var before = _units(human, "Tank").size()
	var funds = human.resource_a
	var wreck = _wreck_at(worker.global_position + Vector3(0, 0, .9), 12)
	_check(wreck.dismantle(worker), "Salvage War Machine rejected adjacent wreck")
	_check(_units(human, "Tank").size() == before + 1, "Wreck did not assemble one Outrider")
	_check(human.resource_a == funds + 18, "Doctrine lost upgraded salvage materials")
	_check(not wreck.dismantle(worker), "Doctrine consumed wreck twice")
	_check(_units(human, "Tank").size() == before + 1, "Duplicate salvage spawned another Outrider")
