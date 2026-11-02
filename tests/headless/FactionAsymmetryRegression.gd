extends "res://tests/headless/StructureActivityRegression.gd"

var technologies
var weapons
var enemy


class RuntimeErrorLog:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	technologies = load("res://source/match/research/TechnologyCatalog.gd")
	weapons = load("res://source/match/combat/WeaponCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		human.coordination_unlocked = true
		human.technology.completed.clear()
		await _roster_contracts(faction)
		_doctrines(faction)
		if faction == "bastion":
			await _siege_and_shield()
			await _fortifications()
		elif faction == "helix":
			await _refraction_and_ion()
			await _shield_flash()
		else:
			await _batch_and_rig()
			await _insurgency_and_claymores()
		game.queue_free()
		await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Faction asymmetry signatures, exclusion and batch production: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _dedicated(role, point, owner = null):
	var side = human if owner == null else owner
	var unit = load(factions.scene_path(side.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _roster_contracts(faction):
	var roster = factions.roster(faction)
	_check(roster.faction_id == faction, "Wrong modular roster identity")
	for role in ["AdvancedTank", "CombatRobot", "AntiAirVehicle"]:
		var scene = factions.scene_path(faction, role)
		_check("/faction/" in scene, "Signature uses mirrored fallback scene")
		var signature = _dedicated(role, Vector3(48, 0, 38))
		await _frames(2)
		_check(signature.type == role, "Bespoke scene lost stable role ID: " + scene)
		_check(signature.base_hp_max == factions.base_health(faction, role), "Roster HP disagrees with persistence formula")
		_check(factions.portrait(faction, role) != null, "Signature portrait missing")
		if faction == "helix":
			_check(signature.shields_max > signature.hp_max, "Helix shields are not its majority durability")
			var fraction = signature.shields_max / (signature.hp_max + signature.shields_max)
			_check(fraction >= 0.5 and fraction <= 0.6, "Helix shield envelope outside 50–60%")
		else:
			_check(signature.shields_max == 0.0, "Non-Helix gained plasma shield envelope")
		signature.queue_free()
		await _frames(2)
	_check(not technologies.available("weapons_1", faction), "Mirrored weapon ladder remains available")
	_check(not technologies.available("armor_1", faction), "Mirrored armor ladder remains available")
	for other in factions.IDS:
		if other == faction:
			continue
		for id in technologies.FACTION_TECHNOLOGIES[other]:
			_check(not technologies.available(id, faction), "Faction can research an excluded branch: " + id)
	if faction == "frontier":
		_check(not factions.available(human, "AircraftFactory", true), "Frontier can build aerospace facility")
		_check(not factions.available(human, "Fighter"), "Frontier can train heavy aerospace")


func _doctrines(faction):
	var pair = technologies.EXCLUSIVE_PAIRS[factions.IDS.find(faction)]
	var lab = _units(human, "CommandLab")[0]
	_check(human.technology.enqueue(pair[0], lab), "Could not reserve doctrine")
	_check(not human.technology.enqueue(pair[1], lab), "Queued opposing doctrines simultaneously")
	_check("excluded" in human.technology.queue_reason(pair[1], lab), "Mutual exclusion lacks clear reason")
	human.technology.cancel()
	human.technology.completed.append(pair[0])
	_check(not human.technology.enqueue(pair[1], lab), "Completed doctrine did not permanently exclude its rival")
	human.technology.completed.clear()


func _siege_and_shield():
	var siege = _dedicated("AdvancedTank", Vector3(44, 0, 42))
	await _frames(2)
	_check(siege.attack_range == 16.0 and siege.weapon_delay() == 2.0, "Siege starts ready without 2 s deployment")
	siege._physics_process(2.0)
	_check(siege.weapon_delay() == 0.0, "Siege did not finish hydraulic deployment")
	siege.get_node("Movement")._has_destination = true
	_check(siege.weapon_delay() == 2.0, "Siege can fire on the move")
	var arc = game.projectile_system.high_arc_direction(Vector3(0, 1, 0), Vector3(16, 1, 0), 19.0, 9.8)
	_check(arc.y > 0.8 and weapons.SIEGE_SHELL.splash >= 3.5, "Siege lost high arc or broad splash")
	var walker = _dedicated("CombatRobot", Vector3(40, 0, 30))
	var protected = _dedicated("Infantry", Vector3(40, 0, 32))
	var shooter = _dedicated("Tank", Vector3(40, 0, 23), enemy)
	await _frames(2)
	game.battlefield.invalidate()
	var round = game.projectile_system.launch(shooter, protected, weapons.TANK_SHELL)
	var contact = game.projectile_system._sweep(round, Vector3(40, 0.9, 23), Vector3(40, 0.9, 33))
	_check(contact.get("shield", false) and contact.get("body") == walker, "Bulwark failed to intercept its forward corridor")
	shooter.global_position.z = 37.0
	game.battlefield.invalidate()
	var rear = game.projectile_system.launch(shooter, walker, weapons.TANK_SHELL)
	contact = game.projectile_system._sweep(rear, Vector3(40, 0.9, 37), Vector3(40, 0.9, 29))
	_check(not contact.get("shield", false), "Bulwark blocked rear fire outside its 60-degree arc")
	game.projectile_system.clear()
	for unit in [siege, walker, protected, shooter]:
		unit.queue_free()
	await _frames(2)
	var flak = _dedicated("AntiAirVehicle", Vector3(45, 0, 35))
	var aircraft = _dedicated("Helicopter", Vector3(45, 0, 38), enemy)
	await _frames(2)
	aircraft.global_position.y = 4.0
	var shell = game.projectile_system.launch(flak, aircraft)
	game.projectile_system._detonate(shell, game.projectile_system.center_of(aircraft), aircraft, false)
	var clouds = game.projectile_system._rounds.filter(func(value): return value.kind == "cloud")
	_check(clouds.size() == 1 and clouds[0].life == 2.0, "Flak did not leave a persistent denial cloud")
	var health = aircraft.hp + aircraft.shields
	game.battlefield.invalidate()
	if not clouds.is_empty():
		game.projectile_system._step(clouds[0], 0.25)
	_check(aircraft.hp + aircraft.shields < health, "Lingering flak cloud failed to damage aircraft")
	game.projectile_system.clear()


func _refraction_and_ion():
	var prism = _dedicated("AdvancedTank", Vector3(40, 0, 28))
	var targets = []
	for index in 4:
		var target = _dedicated("Tank", Vector3(44, 0, 28 + index * 2.0), enemy)
		target.hp_max = 1000.0
		target.hp = 1000.0
		targets.append(target)
	await _frames(2)
	prism.global_position = Vector3(40, 0, 28)
	for index in targets.size():
		targets[index].global_position = Vector3(44, 0, 28 + index * 2.0)
	game.battlefield.invalidate()
	game.projectile_system.launch(prism, targets[0])
	_check(targets[0].hp < 1000 and targets[1].hp < 1000 and targets[2].hp < 1000, "Prism failed primary + two refractions")
	_check(targets[3].hp == 1000, "Base Prism chained beyond two additional targets")
	human.technology.completed.append("continuous_coherence")
	game.projectile_system.launch(prism, targets[0])
	_check(targets[3].hp < 1000, "Coherence doctrine did not extend refraction")
	human.technology.completed.clear()
	var ion = _dedicated("AntiAirVehicle", Vector3(40, 0, 38))
	var aircraft = _dedicated("Helicopter", Vector3(44, 3, 38), enemy)
	await _frames(2)
	var round = game.projectile_system.launch(ion, aircraft)
	game.projectile_system._detonate(round, game.projectile_system.center_of(aircraft), aircraft, false)
	_check(aircraft.get_node("Movement").ion_stall_left > 2.0, "Guided ion hit failed to stall aircraft thrust")
	game.projectile_system.clear()


func _batch_and_rig():
	var pool = _units(human, "VehicleFactory")[0]
	_check("Drone" in factions.production_options("frontier", "VehicleFactory"), "Frontier Drone lacks a Motor Pool roster entry")
	_check("Drone" not in factions.production_options("bastion", "VehicleFactory"), "Frontier Drone production leaked to Bastion factories")
	var drone = pool.production_queue.produce(load(factions.scene_path("frontier", "Drone")))
	_check(drone != null, "Motor Pool rejected its bespoke Frontier Drone option")
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(snapshot != null and schema.validate(snapshot), "Faction-specific Motor Pool queue cannot be saved: " + builder.error + " " + schema.error)
	paused = false
	pool.production_queue.cancel(drone)
	var factory = _units(human, "Barracks")[0]
	var old_population = human.population(true)
	var before = human.resource_a
	var job = factory.production_queue.produce(load(factions.scene_path("frontier", "Infantry")))
	_check(job != null and job.batch_count == 3, "Frontier militia are not trained in triplets")
	_check(before - human.resource_a == factions.cost(human, "Infantry").resource_a * 3, "Militia batch did not reserve all costs")
	_check(human.population(true) == old_population + 3, "Population does not reserve the whole batch")
	factory.production_queue.cancel(job)
	_check(human.resource_a == before and human.population(true) == old_population, "Batch cancellation leaked resources or population")
	var producer = _dedicated("Barracks", Vector3(28, 0, 28))
	await _frames(2)
	var count_before = _units(human, "Infantry").size()
	var batch = producer.production_queue.produce(load(factions.scene_path("frontier", "Infantry")))
	producer.production_queue._process(100.0)
	await _frames(2)
	_check(producer.production_queue.size() == 0 and _units(human, "Infantry").size() == count_before + 3, "Paid militia cycle failed to release three distinct units")
	var rig = _dedicated("AdvancedTank", Vector3(45, 0, 35))
	var soldiers = []
	for index in 4:
		soldiers.append(_dedicated("Infantry", Vector3(45 + index * 0.2, 0, 35)))
	await _frames(2)
	for soldier in soldiers:
		_check(rig.garrison_mount.enter(soldier), "Battle Rig could not fill an open firing port")
		_check(not soldier.visible, "Garrisoned infantry remained visible")
	_check(rig.garrison_mount.occupants.size() == 4, "Battle Rig does not hold four independent shooters")
	_check(weapons.profile(rig).id == "twin_autocannon", "Battle Rig still fires a generic heavy cannon")
	var gun_target = _dedicated("Tank", Vector3(49, 0, 35), enemy)
	await _frames(2)
	game.projectile_system.clear()
	game.projectile_system.launch(rig, gun_target)
	var twin_rounds = game.projectile_system.rounds_at(gun_target)
	_check(twin_rounds.size() == 2, "Battle Rig did not fire both autocannons")
	if twin_rounds.size() == 2:
		_check(twin_rounds[0].position.distance_to(twin_rounds[1].position) > 0.3, "Twin autocannons shared one muzzle position")
	game.projectile_system.clear()
	var buggy = _dedicated("CombatRobot", Vector3(52, 0, 40))
	var target = _dedicated("Tank", Vector3(52, 0, 41), enemy)
	await _frames(2)
	var health = target.hp + target.shields
	game.battlefield.invalidate()
	game.projectile_system.launch(buggy, target)
	_check(buggy.hp == 0.0, "Demolition buggy survived its impact charge")
	_check(target.hp + target.shields < health, "Demolition charge dealt no point-blank burst")


func _fortifications():
	var bunker = game.engineering._spawn_emplacement(human, "bunker", Vector3(24, 0, 42), 0.0, "engineering-bunker-test")
	await _frames(2)
	_check(bunker.garrison_mount.capacity == 6 and bunker.hp_max == 320.0, "Bunker lacks six protected ports or concrete durability")
	for index in 6:
		var soldier = _dedicated("Infantry", bunker.global_position)
		await _frames(1)
		soldier.global_position = bunker.global_position
		_check(bunker.enter(soldier), "Bunker could not fill all six ports")
		_check(not soldier.visible, "Bunker exposed an embarked infantry model")
	human.technology.completed.append_array(["bunker_reinforcements", "fortress_doctrine"])
	bunker.refresh_doctrine()
	_check(bunker.hp_max == 624.0, "Bunker reinforcements and Fortress did not compose")
	bunker.hp -= 20.0
	bunker._physics_process(1.0)
	_check(bunker.hp == 608.0, "Fortress bunker did not auto-repair")
	var trap = game.engineering._spawn_emplacement(human, "tank_trap", Vector3(30, 0, 42), 0.0, "engineering-trap-test")
	var tank = _dedicated("Tank", Vector3(30, 0, 41))
	await _frames(2)
	_check(not trap.crush_by(tank), "Heavy tank crushed an exclusionary Bastion tank trap")
	var barrier = game.engineering._spawn_barricade(human, Vector3(34, 0, 42), 0.0, "engineering-barrier-test")
	_check(barrier.hp_max == 160.0, "Fortress did not double sandbag durability")
	human.technology.completed.clear()


func _shield_flash():
	human.technology.completed.append("phase_overload")
	var source = _dedicated("Tank", Vector3(24, 0, 42))
	var target = _dedicated("Helicopter", Vector3(25, 0, 42), enemy)
	await _frames(2)
	source.global_position = Vector3(24, 0, 42)
	target.global_position = Vector3(25, 0, 42)
	game.battlefield.invalidate()
	source.shield_component.drain(source.shields, game.simulation_time)
	_check(target.get_node("Movement").ion_stall_left > 0.0, "Phase Overload shield break did not emit an EMP flash")
	human.technology.completed.clear()


func _insurgency_and_claymores():
	human.technology.completed.append("guerrilla_insurgency")
	var building = _dedicated("PowerPlant", Vector3(24, 0, 44))
	await _frames(2)
	var before = _units(human, "Infantry").size()
	building.hp = 0.0
	await _frames(2)
	_check(_units(human, "Infantry").size() == before + 3, "Destroyed Frontier structure did not release its militia triplet")
	_check(game.engineering.limit_for(human, "mine") == 24, "Guerrilla doctrine did not double mine count")
	human.technology.completed.append("concealed_claymores")
	var mine = game.engineering._spawn_mine(human, Vector3(32, 0, 44), "engineering-mine-test")
	var target = _dedicated("Tank", Vector3(36, 0, 44), enemy)
	await _frames(2)
	target.global_position = Vector3(36, 0, 44)
	var total = target.hp + target.shields
	game.battlefield.invalidate()
	game.engineering.detonate(mine)
	_check(target.hp + target.shields < total, "Concealed Claymores did not double blast radius")
	human.technology.completed.clear()
