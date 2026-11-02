extends "res://tests/headless/UnitAnimationRegression.gd"

var _references = {}
var _orders
var _restore


func _run():
	_orders = load("res://source/match/orders/ManualOrders.gd")
	_restore = load("res://source/match/saves/MatchRestore.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _bastion_slice()
	await _helix_slice()
	await _frontier_slice()
	for error in _errors:
		push_error(error)
	print("Gameplay depth save/restore: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _prepare():
	_game.settings.battlefield_events = false
	_game.grenade_system.set_physics_process(false)
	_game.commander_support.set_physics_process(false)
	_game.engineering.set_physics_process(false)
	_players[0].resource_a = 2000
	_players[0].resource_b = 2000
	_spawn("CommandLab", 0, Vector3(15, 0, 18))
	_spawn("PowerPlant", 0, Vector3(22, 0, 18))
	_spawn("PowerPlant", 0, Vector3(28, 0, 18))
	_game.commander_support.state(_players[0]).started = true
	_game.commander_support.state(_players[0]).left = 0.0


func _bastion_slice():
	await _fixture("bastion", "IndustrialCrossroads")
	_prepare()
	var soldier = _spawn("Infantry", 0, Vector3(40, 0, 8))
	var victim = _spawn("Infantry", 1, Vector3(46, 0, 8))
	var building = _game.get_node("NeutralWorld").buildings.filter(func(item): return item.habitable)[0]
	var fixture = load("res://tests/headless/GrenadeFixture.gd")
	_check(fixture.position_thrower(building, soldier), "No clear save fixture throw")
	victim.global_position = soldier.global_position
	_check(fixture.occupy(building, victim), "Save fixture garrison rejected")
	var hero = _spawn("Hero", 0, Vector3(40, 0, 12))
	var infantry = _spawn("Infantry", 1, Vector3(46, 0, 12))
	var worker = _spawn("Worker", 0, Vector3(35, 0, 42))
	var factory = _spawn("Barracks", 0, Vector3(15, 0, 24))
	await _frames(3)
	soldier.suppression.add_pressure(95.0)
	soldier.suppression._physics_process(0.4)
	soldier.regarrison_lock_left = 1.25
	soldier.damage_visual_band = 1
	_check(
		soldier.abilities.trigger("frag_grenade", building.global_position, building),
		"Save fixture grenade rejected"
	)
	soldier.abilities.get_ability("frag_grenade").cooldown_left = 12.0
	_game.grenade_system._physics_process(0.25)
	var round = _game.projectile_system.launch(hero, infantry)
	_game.projectile_system._suppress_nearby(
		round,
		infantry.global_position + Vector3(-2, 0.8, 0.9),
		infantry.global_position + Vector3(2, 0.8, 0.9)
	)
	_game.projectile_system.set_physics_process(false)
	var barrier = _game.engineering._spawn_barricade(
		_players[0], Vector3(38, 0, 42), 0.0, _game.engineering._allocate_id("barricade")
	)
	_game.engineering._cooldowns[worker] = 7.0
	worker.manual_orders.submit(_orders.target_order("repair_barrier", barrier), false, false)
	var job = factory.production_queue.produce(load("res://source/match/units/Infantry.tscn"))
	factory.production_queue.last_completed_role = "Infantry"
	factory.production_queue.completed_streak = 2
	job.assembly_started = true
	job.assembly_bonus = 0.16
	job.time_left = job.time_total - 1.25
	_check(
		_game.commander_support.activate(_players[0], Vector3(0.1, 0, 0.1)),
		"Save fixture barrage rejected"
	)
	_game.commander_support._physics_process(4.15)
	var pattern = _game.commander_support.pending[0].pattern.duplicate()
	for point in pattern:
		_check(
			(
				point.x >= 0
				and point.z >= 0
				and point.x <= _game.map.size.x
				and point.z <= _game.map.size.y
			),
			"Legal corner barrage generated an out-of-map frozen impact"
		)
	var index = _game.commander_support.pending[0].index
	var saved_pressure = soldier.suppression.capture()
	if not await _round_trip(
		{
			"soldier": soldier,
			"victim": victim,
			"worker": worker,
			"factory": factory,
			"barrier": barrier,
			"infantry": infantry
		}
	):
		await _close_paused()
		return
	soldier = _references.soldier
	victim = _references.victim
	_check(
		soldier.suppression.capture() == saved_pressure, "Suppression budget/timers changed on load"
	)
	_check(
		soldier.regarrison_lock_left == 1.25 and soldier.damage_visual_band == 1,
		"Unit tactical timers lost"
	)
	_check(
		not soldier.abilities.get_ability("frag_grenade").is_ready(),
		"Grenade cooldown reset on load"
	)
	_check(
		_references.worker.action._target == _references.barrier,
		"Engineering service reference lost"
	)
	_check(
		_game.engineering.cooldown_left(_references.worker) == 7.0, "Deployment cooldown changed"
	)
	var restored_job = _references.factory.production_queue.get_elements()[0]
	_check(
		(
			restored_job.assembly_bonus == 0.16
			and _references.factory.production_queue.completed_streak == 2
		),
		"Assembly streak or started bonus lost"
	)
	_check(
		_game.projectile_system._rounds[0].suppression.size() == 1,
		"Projectile contribution ledger lost"
	)
	_check(
		(
			_game.commander_support.pending[0].index == index
			and _game.commander_support.pending[0].pattern == pattern
		),
		"Barrage rerolled or reset impact index"
	)
	var hp = victim.hp
	_game.grenade_system._physics_process(0.34)
	_check(victim.hp == hp, "Restored grenade fired early")
	_game.grenade_system._physics_process(0.02)
	_check(
		victim.hp == hp - 15.0 and _game.grenade_system.pending.is_empty(),
		"Restored grenade did not resolve once"
	)
	_game.grenade_system._physics_process(1.0)
	_check(victim.hp == hp - 15.0, "Restored grenade resolved twice")
	_game.commander_support._physics_process(10.0)
	_check(_game.commander_support.pending.is_empty(), "Restored barrage did not complete")
	await _close_paused()


func _helix_slice():
	await _fixture("helix")
	_prepare()
	_players[0].coordination_unlocked = true
	_players[0].technology.completed.append("plasma_shields")
	var generator = _spawn("PowerPlant", 0, Vector3(25, 0, 35))
	var drone = _spawn("Drone", 0, Vector3(29, 0, 35))
	var enemy = _spawn("Tank", 1, Vector3(42, 0, 35))
	var turret = _spawn("AntiGroundTurret", 1, Vector3(43, 0, 37))
	_check(generator.abilities.trigger("power_overdrive"), "Save fixture overdrive rejected")
	_check(drone.abilities.trigger("drone_chaff"), "Save fixture chaff rejected")
	drone.abilities._physics_process(2.0)
	_check(
		_game.commander_support.activate(_players[0], enemy.global_position),
		"Save fixture EMP rejected"
	)
	_game.commander_support._physics_process(2.5)
	_game.commander_support._physics_process(1.25)
	if not await _round_trip(
		{"generator": generator, "drone": drone, "enemy": enemy, "turret": turret}
	):
		await _close_paused()
		return
	_check(_references.generator.abilities.is_active("power_overdrive"), "Overdrive request lost")
	_check(
		_references.drone.abilities.get_ability("drone_chaff").active_left == 6.0,
		"Chaff duration reset"
	)
	_check(_game.commander_support.emp[_references.enemy] == 4.75, "EMP timer changed")
	_check(_game.commander_support.disabled(_references.turret), "Restored EMP turret can fire")
	_game.commander_support._physics_process(4.76)
	_check(
		not _game.commander_support.disabled(_references.turret), "Restored EMP failed to expire"
	)
	await _close_paused()


func _frontier_slice():
	await _fixture("frontier")
	_prepare()
	var tank = _spawn("Tank", 0, Vector3(35, 0, 35))
	var worker = _spawn("Worker", 0, Vector3(35, 0, 42))
	tank.permanent_scrap_rank = 2
	tank.scrap_hardened_tiers = 1
	tank.scrap_hardened_left = 17.0
	var mine = _game.engineering._spawn_mine(
		_players[0], Vector3(39, 0, 42), _game.engineering._allocate_id("mine")
	)
	mine.deploy_left = 0.0
	mine.arm_left = 0.0
	mine.fuse_left = 0.2
	worker.manual_orders.submit({"kind": "sweep", "point": Vector3(40, 0, 42)}, false, false)
	worker.action.search_index = 2
	var landing = Vector3(45, 0, 45)
	_check(_game.commander_support.activate(_players[0], landing), "Save fixture airdrop rejected")
	_game.commander_support._physics_process(5.0)
	var carrier = _game.commander_support.pending[0].carrier
	carrier.hp = 77.0
	var anti_air = _spawn("AntiAirVehicle", 1, Vector3(42, 0, 45))
	anti_air.manual_orders.submit(_orders.target_order("attack", carrier), false, false)
	_game.commander_support.explored[_players[0]] = {0: true, 20: true, 45: true}
	if not await _round_trip(
		{"tank": tank, "worker": worker, "mine": mine, "carrier": carrier, "anti_air": anti_air}
	):
		await _close_paused()
		return
	_check(
		_references.tank.permanent_scrap_rank == 2 and _references.tank.scrap_hardened_left == 17.0,
		"Permanent and timed salvage states were conflated"
	)
	_check(_references.mine.fuse_left == 0.2, "Live mine fuse changed")
	_check(_references.worker.action.search_index == 2, "Area-clearance search restarted")
	_check(
		_references.carrier.hp == 77.0 and _references.carrier.hp_max == 120.0,
		"Carrier damage or max health changed"
	)
	_check(
		_references.anti_air.action._target_unit == _references.carrier,
		"Air-defense carrier target reference lost"
	)
	_check(_game.commander_support.reserved(_players[0]) == 2, "Airdrop reservation lost")
	_check(_game.commander_support.explored[_players[0]].size() == 3, "Exploration ledger changed")
	_game.commander_support._physics_process(2.0)
	_check(
		_game.commander_support.pending.is_empty() and _game.commander_support.crates.size() == 1,
		"Restored carrier did not land once"
	)
	var crate = _game.commander_support.crates[0].node
	var receiver = _references.tank
	receiver.hp -= 30.0
	receiver.position = crate.position + Vector3(1, 0, 0)
	var collecting = load("res://source/match/units/actions/CollectTacticalCargo.gd").new(crate)
	receiver.action = collecting
	collecting.elapsed = 1.25
	if await _round_trip({"receiver": receiver, "crate": crate}):
		_check(
			(
				_references.receiver.action._target_unit == _references.crate
				and _references.receiver.action.elapsed == 1.25
			),
			"Repair-crate interaction lost its target or progress"
		)
		var hp = _references.receiver.hp
		_references.receiver.action._process(0.76)
		_check(_references.receiver.hp > hp, "Restored repair-crate interaction did not complete")
	await _close_paused()


func _round_trip(objects: Dictionary) -> bool:
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = capture.capture(_game)
	if snapshot == null:
		_check(false, "Tactical snapshot capture failed: " + capture.error)
		return false
	var ids = {}
	for key in objects:
		ids[key] = capture._reference(objects[key])
	var loader = _restore.new()
	var prepared = loader.prepare(snapshot)
	_check(prepared, "Tactical snapshot rejected: " + loader.error)
	if not prepared:
		return false
	# Corrupt state is rejected without replacing the live battle.
	var corrupt = snapshot.duplicate(true)
	corrupt.units[0].permanent_scrap_rank = 3
	var validator = _restore.new()
	_check(not validator.prepare(corrupt), "Invalid permanent armor rank was accepted")
	corrupt = snapshot.duplicate(true)
	corrupt.grenades.pending.append({})
	_check(not validator.prepare(corrupt), "Malformed delayed grenade was accepted")
	var result = await loader.restore(self, snapshot)
	_check(result.ok, "Tactical restore failed: " + result.get("error", ""))
	if not result.ok:
		if result.has("game"):
			_game = result.game
		return false
	_game = result.game
	_players = [
		_game._get_human_player(),
		get_nodes_in_group("players").filter(func(player): return player != _game._get_human_player())[0]
	]
	_references.clear()
	for key in ids:
		_references[key] = loader.entities.get(ids[key])
		_check(is_instance_valid(_references[key]), "Restored tactical reference missing: " + key)
	for player in _players:
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.commander_support.set_physics_process(false)
	_game.engineering.set_physics_process(false)
	_game.grenade_system.set_physics_process(false)
	_game.projectile_system.set_physics_process(false)
	return true


func _close_paused():
	await _close()
	paused = false
