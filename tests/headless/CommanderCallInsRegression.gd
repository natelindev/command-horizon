extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	var support = _game.commander_support
	support.set_physics_process(false)
	var owner = _players[0]
	owner.resource_a = 1000
	owner.resource_b = 1000
	var point = Vector3(40, 0, 26)
	_check(not support.activate(owner, point), "Call-in accepted without a lab")
	var lab = _spawn("CommandLab", 0, Vector3(16, 0, 16))
	_spawn("PowerPlant", 0, Vector3(22, 0, 16))
	support._physics_process(59.0)
	_check(not support.activate(owner, point), "Initial charge completed before sixty seconds")
	support._physics_process(1.0)
	await _targeting_cancel_and_pause(support, owner, point)
	var enemy = _spawn("CommandCenter", 1, point)
	var ally = _spawn("Tank", 0, point + Vector3(1.2, 0, 0))
	var before = Vector2i(owner.resource_a, owner.resource_b)
	_check(support.activate(owner, point), "Ready barrage rejected")
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b) == before - Vector2i(50, 30)
			and support.pending.size() == 1
		),
		"Call-in payment was not atomic"
	)
	_check(not support.activate(owner, point), "Cooldown allowed a second call-in")
	var pattern = support.pending[0].pattern.duplicate()
	lab.queue_free()
	await _frames(1)
	support._physics_process(3.49)
	_check(enemy.hp == enemy.hp_max, "Barrage hit before its warning")
	support._physics_process(.01)
	for index in range(1, 6):
		var hp_before_shell = enemy.hp
		support._physics_process(.601)
		_check(enemy.hp < hp_before_shell, "Barrage shell %d missed the HQ footprint" % index)
	_check(support.pending.is_empty(), "Committed barrage stopped after losing its lab")
	_check(
		enemy.hp > 0 and enemy.hp < enemy.hp_max,
		"Barrage failed to soften a healthy headquarters without killing it"
	)
	_check(
		ally.hp == ally.hp_max and pattern.size() == 6,
		"Barrage damaged an ally or omitted frozen pattern"
	)
	_check(
		is_equal_approx(enemy.hp_max - enemy.hp, 189.0),
		"Centered barrage changed falloff or damaged a headquarters twice per shell"
	)
	await _barrage_structure_edges(support, owner)
	lab = _spawn("CommandLab", 0, Vector3(16, 0, 16))
	_check(support.state(owner).left > 140, "Rebuilt lab refreshed commander charge")
	owner.faction = "helix"
	support.state(owner).left = 0.0
	var tank = _spawn("Tank", 1, point + Vector3(0, 0, 2))
	var infantry = _spawn("Infantry", 1, point + Vector3(0, 0, 3))
	var turret = _spawn("AntiGroundTurret", 1, point + Vector3(6, 0, 0))
	var fire_target = _spawn("Tank", 0, point + Vector3(11, 0, 0))
	var reload_at = int(_game.simulation_time * 1000.0) + 150
	turret.set_meta("next_attack_availability_time", reload_at)
	turret.stance = turret.Stance.HOLD_POSITION
	var waiting = turret.action
	waiting._attack_unit(fire_target)
	var attack = waiting._sub_action
	turret.process_mode = Node.PROCESS_MODE_INHERIT
	_check(
		turret.action == waiting and not attack.is_queued_for_deletion(),
		"EMP fixture has no live turret attack to preserve"
	)
	tank.shields_max = 50
	tank.shields = 50
	var hp = tank.hp
	var before_emp = Vector2i(owner.resource_a, owner.resource_b)
	_check(support.activate(owner, point), "Ready EMP rejected")
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == before_emp - Vector2i(50, 30),
		"EMP price changed with the airdrop tuning"
	)
	support._physics_process(2.5)
	_check(tank.shields == 0 and tank.hp == hp, "EMP did not strip shields without hull damage")
	_check(
		support.speed_factor(tank) == .6 and support.speed_factor(infantry) == 1.0,
		"EMP slow affected wrong class"
	)
	_check(support.disabled(turret), "EMP did not disable a turret")
	_check(
		not load("res://source/match/combat/CombatRules.gd").can_target(turret, ally),
		"Disabled turret could still fire"
	)
	for frame in 24:
		await physics_frame
	_check(
		is_instance_valid(attack) and waiting._sub_action == attack and attack._shots == 0,
		"EMP discarded a live turret order or allowed it to fire during disablement"
	)
	_check(
		turret.get_meta("next_attack_availability_time") == reload_at,
		"EMP restarted or consumed the turret's existing reload"
	)
	support._physics_process(5.99)
	_check(support.disabled(turret), "EMP expired early")
	support._physics_process(.02)
	_check(
		not support.disabled(turret) and support.speed_factor(tank) == 1.0,
		"EMP status did not expire"
	)
	var fired = _game.projectile_system.rounds_fired
	for frame in 18:
		await physics_frame
	_check(
		(
			is_instance_valid(attack)
			and turret.action == waiting
			and waiting._sub_action == attack
			and attack._shots > 0
			and _game.projectile_system.rounds_fired > fired
		),
		"Preserved turret order did not resume physical fire after EMP expiry"
	)
	turret.process_mode = Node.PROCESS_MODE_DISABLED
	turret.action = null
	turret.queue_free()
	fire_target.queue_free()
	await _frames(2)
	owner.faction = "frontier"
	support.state(owner).left = 0.0
	var landing = Vector3(35, 0, 40)
	_check(support.landing_positions(landing).size() == 2, "Fixture has no legal landing positions")
	var population = owner.population(true)
	await _population_reservation(support, owner, landing)
	var resources_before_drop = Vector2i(owner.resource_a, owner.resource_b)
	for insufficient in [Vector2i(44, 15), Vector2i(45, 14)]:
		owner.resource_a = insufficient.x
		owner.resource_b = insufficient.y
		_check(not support.activate(owner, landing), "Airdrop accepted insufficient resources")
		_check(
			(
				Vector2i(owner.resource_a, owner.resource_b) == insufficient
				and support.pending.is_empty()
				and support.reserved(owner) == 0
				and support.state(owner).left == 0.0
			),
			"Rejected airdrop changed resources, population or charge"
		)
	owner.resource_a = 45
	owner.resource_b = 15
	_check(support.activate(owner, landing), "Ready airdrop rejected")
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == Vector2i.ZERO,
		"Airdrop did not spend its faction-specific 45 Materials / 15 Electronics price"
	)
	owner.resource_a = resources_before_drop.x - 45
	owner.resource_b = resources_before_drop.y - 15
	_check(
		owner.population(true) == population + 2 and support.reserved(owner) == 2,
		"Airdrop did not reserve population"
	)
	support._physics_process(4.0)
	var carrier = support.pending[0].carrier
	_check(
		carrier != null and carrier.combat_domain() == 0 and carrier.hp == 120.0,
		"Airdrop carrier lost its 120 HP air-target profile"
	)
	var defenders = []
	for index in 3:
		defenders.append(
			_spawn("AntiAirVehicle", 1, landing + Vector3(-3 + index * 3, 0, 5), false)
		)
	var contexts = load("res://source/match/players/human/UnitActionsController.gd")
	_check(
		contexts.context_kind(defenders[0], carrier) == "attack",
		"Right-click could not attack an enemy carrier"
	)
	var before_rounds = _game.projectile_system.rounds_fired
	for frame in 179:
		await physics_frame
		support._physics_process(1.0 / 60.0)
		if support.pending.is_empty():
			break
	_check(
		support.pending.is_empty() and support.reserved(owner) == 0,
		"Real AA could not intercept within the three-second descent"
	)
	_check(
		_game.projectile_system.rounds_fired > before_rounds,
		"AA interception never used a physical projectile"
	)
	_check(owner.population(true) == population, "Intercepted carrier spawned its payload")
	for defender in defenders:
		defender.queue_free()
	await _frames(1)
	support.state(owner).left = 0.0
	_check(support.activate(owner, landing), "Second test airdrop rejected")
	support._physics_process(7.0)
	_check(
		support.pending.is_empty() and support.crates.size() == 1,
		"Airdrop did not land its payload"
	)
	_check(
		support.reserved(owner) == 0 and owner.population(true) == population + 2,
		"Landed units duplicated population reservation"
	)
	var crate = support.crates[0].node
	var tanks = owner.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	var receiver = tanks[-1]
	receiver.hp -= 50
	var damaged = receiver.hp
	_check(not support.collect(crate, receiver, 1.99), "Repair crate completed its channel early")
	_check(
		support.collect(crate, receiver, 2.0) and receiver.hp > damaged,
		"Repair crate failed to heal"
	)
	_check(not support.collect(crate, receiver, 2.0), "Repair crate could be consumed twice")
	_check(
		receiver.permanent_scrap_rank == 0 and receiver.scrap_hardened_tiers == 0,
		"Airdrop granted salvage bonuses"
	)
	_game.settings.visibility = _game.settings.Visibility.PER_PLAYER
	var hidden = Vector3(75, 0, 75)
	_check(not support.was_explored(owner, hidden), "Unknown terrain became explored")
	owner.faction = "bastion"
	support.state(owner).left = 0
	_check(not support.activate(owner, hidden), "Offensive call-in accepted unobserved ground")
	await _public_cargo_order(support, ally, hidden)
	await _explored_map_edges(support, owner)
	await _close()
	for message in _errors:
		push_error(message)
	print("Commander call-ins regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _targeting_cancel_and_pause(support, owner, point):
	var controls = _game.hud.direct_orders
	var balance = Vector2i(owner.resource_a, owner.resource_b)
	var count = _game.find_children("TacticalRangeRing*", "MeshInstance3D", false, false).size()
	_check(controls.arm_commander(), "Could not arm ready commander targeting")
	_check(controls.arm_commander(), "Could not re-arm commander targeting")
	var rings = _game.find_children("TacticalRangeRing*", "MeshInstance3D", false, false).filter(
		func(ring): return not ring.is_queued_for_deletion()
	)
	_check(rings.size() == count + 1, "Repeated commander targeting leaked range indicators")
	controls.cancel()
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b) == balance
			and support.state(owner).left == 0.0
		),
		"Canceling targeting spent resources or charge"
	)
	paused = true
	_check(controls.arm_commander(), "Paused battle could not prepare commander targeting")
	_check(
		not controls.commit(point, null, false), "Paused commander targeting committed an effect"
	)
	controls.cancel()
	support.state(owner).left = 7.0
	support.set_physics_process(true)
	for frame in 3:
		await physics_frame
	_check(support.state(owner).left == 7.0, "Commander charge advanced during pause")
	support.set_physics_process(false)
	paused = false
	support.state(owner).left = 0.0
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == balance, "Paused targeting spent resources"
	)


func _population_reservation(support, owner, point):
	var fillers = []
	while owner.population(true) < Catalog.POPULATION_LIMIT - 1:
		var body = Node3D.new()
		var movement = Node.new()
		movement.name = "Movement"
		body.add_child(movement)
		owner.add_child(body)
		fillers.append(body)
	var balance = Vector2i(owner.resource_a, owner.resource_b)
	_check(not support.activate(owner, point), "Airdrop accepted only one free population slot")
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == balance,
		"Rejected population reservation spent resources"
	)
	fillers.pop_back().free()
	_check(support.activate(owner, point), "Airdrop rejected exactly two free population slots")
	var headquarters = owner.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandCenter"
	)
	_check(
		headquarters[0].production_queue.produce(load(Catalog.scene_path("Worker"))) == null,
		"Production stole population reserved by a pending airdrop"
	)
	support._finish(support.pending[0])
	_check(support.reserved(owner) == 0, "Failed airdrop retained population reservation")
	for body in fillers:
		body.free()
	support.state(owner).left = 0.0
	await _frames(1)


func _barrage_structure_edges(support, owner):
	var record = {"owner": owner}
	var headquarters = _spawn("CommandCenter", 1, Vector3(20, 0, 44))
	var reach = headquarters.radius + 2.5
	var contact = headquarters.global_position + Vector3(reach - .02, 0, 0)
	var outside = headquarters.global_position + Vector3(reach + .02, 0, 0)
	var mobile = _spawn("Tank", 1, contact + Vector3(0, 0, 2.6))
	support._barrage_impact(record, outside)
	_check(headquarters.hp == headquarters.hp_max, "Barrage hit beyond a circular footprint")
	support._barrage_impact(record, contact)
	_check(
		is_equal_approx(headquarters.hp_max - headquarters.hp, 25.0),
		"Barrage missed or double-hit a headquarters at the footprint edge"
	)
	_check(mobile.hp == mobile.hp_max, "Structure fix extended the mobile blast radius")
	var runway = _spawn("AircraftFactory", 1, Vector3(42, 0, 44))
	runway.rotation.y = .37
	_game.battlefield.invalidate()
	var runway_outside = runway.to_global(Vector3(0, 0, 13.1 + 2.52))
	var runway_contact = runway.to_global(Vector3(0, 0, 13.1 + 2.48))
	support._barrage_impact(record, runway_outside)
	_check(runway.hp == runway.hp_max, "Barrage hit beyond a rotated runway footprint")
	support._barrage_impact(record, runway_contact)
	_check(
		is_equal_approx(runway.hp_max - runway.hp, 25.0),
		"Barrage missed or double-hit the far edge of a rotated runway"
	)
	for unit in [headquarters, mobile, runway]:
		unit.queue_free()
	await _frames(2)


func _public_cargo_order(support, unit, point):
	var cargo = support._cargo("test-public-supply", "test-public", "supply", null, point, 1.0)
	cargo.public_marker = true
	_check(
		not _game.battlefield.is_observed(unit.player, cargo),
		"Public-cargo fixture unexpectedly observed"
	)
	var order = unit.manual_orders.target_order("collect_tactical", cargo)
	var action = unit.manual_orders._make_action(order)
	_check(
		action != null and action.get_script().resource_path.ends_with("CollectTacticalCargo.gd"),
		"Public cargo in fog lost its collection command"
	)
	if action != null:
		action.free()
	cargo.dismiss()
	await _frames(1)


func _explored_map_edges(support, owner):
	var size = _game.map.size
	var edge = Vector3(size.x, 0, size.y * .5)
	var corner = Vector3(size.x, 0, size.y)
	var scouts = [
		_spawn("Drone", 0, edge + Vector3(-1, 2, 0)),
		_spawn("Drone", 0, corner + Vector3(-1, 2, -1))
	]
	support.explored.clear()
	_check(support.observes(owner, edge), "Edge scout fixture has no boundary sight")
	_check(support.observes(owner, corner), "Corner scout fixture has no boundary sight")
	support._record_exploration()
	for scout in scouts:
		scout.queue_free()
	await _frames(2)
	_check(
		not support.observes(owner, edge) and not support.observes(owner, corner),
		"Edge exploration fixture retained live vision"
	)
	_check(
		support.was_explored(owner, edge) and support.was_explored(owner, corner),
		"Scouted map boundary became unexplored after its observer left"
	)
	var unrelated = Vector3(0, 0, edge.z + support.CELL)
	_check(
		not support.was_explored(owner, unrelated),
		"East-edge exploration leaked into an unrelated cell on the west edge"
	)
