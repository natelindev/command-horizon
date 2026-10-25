extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
var _errors = []
var _game
var _human
var _enemy
var _test_units = []
var _shooting
var _attacking


func _initialize():
	call_deferred("_run")


func _run():
	_attacking = load("res://source/match/units/actions/AutoAttacking.gd")
	_shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in range(2):
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
	_enemy = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	await _test_observation_and_fire()
	await _clear()
	await _test_firing_orientation()
	await _clear()
	await _test_dynamic_spotters()
	await _clear()
	await _test_target_candidates()
	await _clear()
	await _test_damage()
	await _clear()
	await _test_projectiles()
	await _clear()
	await _test_repair()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: occluded/allied/elevated vision, legal firing, hidden-target loss, armor counters, "
				+ "fractional damage, repair cap/service slots/power/combat suppression/pause"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_test_units.append(unit)
	return unit


func _test_firing_orientation():
	var shooter = _spawn("Infantry", _human, Vector3(18, 0, 10))
	var target = _spawn("Infantry", _enemy, Vector3(22, 0, 10))
	await _frames(4)
	var attack = _shooting.new(target)
	shooter.action = attack
	var movement = shooter.get_node("Movement")
	movement._has_destination = false
	var facing = shooter.global_basis
	# Alternating crowd nudges must not turn a planted shooter away from its target.
	for index in 24:
		movement._rotate_in_direction(Vector3(0, 0, .2 if index % 2 == 0 else -.2))
		_check(
			shooter.global_basis.is_equal_approx(facing), "Crowd nudge turned a firing infantryman"
		)
	# A moving enemy must still be tracked between shots.
	target.global_position = Vector3(21, 0, 13)
	attack._physics_process(1.0 / 60.0)
	var desired = (target.global_position - shooter.global_position).normalized()
	_check(
		(-shooter.global_basis.z).dot(desired) > .999,
		"Stationary shooter stopped tracking its target"
	)
	# An explicit move takes facing back, even while an aim target is still present.
	movement._has_destination = true
	movement._rotate_in_direction(Vector3(0, 0, 2))
	_check(
		(-shooter.global_basis.z).dot(Vector3.BACK) > .999, "Attack facing blocked an explicit move"
	)
	shooter.aim_target = null
	facing = shooter.global_basis
	movement._rotate_in_direction(Vector3(.0001, 0, 0))
	_check(shooter.global_basis.is_equal_approx(facing), "Settling motion changed unit heading")


func _test_observation_and_fire():
	var field = _game.battlefield
	var shooter = _spawn("Tank", _human, Vector3(18, 0, 10))
	var target = _spawn("Tank", _enemy, Vector3(24, 0, 10))
	var blocker = _spawn("Barracks", _human, Vector3(21, 0, 10))
	await _frames(45)
	_check(not field.can_observe(shooter, target), "Building failed to block ground sight")
	_check(not field.can_observe(target, shooter), "AI sight bypasses opaque building")
	var scout = _spawn("Worker", _human, Vector3(24, 0, 14))
	await _frames(4)
	_check(field.is_observed(_human, target), "Allied scout did not reveal target")
	_check(
		not field.can_fire(shooter, target), "Allied sight incorrectly grants shot through building"
	)
	var before = target.hp
	shooter.action = _shooting.new(target)
	await _frames(4)
	_check(target.hp == before, "Direct attack damaged target through building")
	# A foundation does not hide units; completion immediately makes it opaque.
	blocker._construction_progress = 0.0
	_check(field.can_fire(shooter, target), "Foundation incorrectly blocks firing")
	blocker._construction_progress = 1.0
	_check(not field.can_fire(shooter, target), "Completed building remains transparent")
	blocker.queue_free()
	await _frames(4)
	_check(field.can_fire(shooter, target), "Destroyed building kept blocking shots")
	shooter.process_mode = Node.PROCESS_MODE_PAUSABLE
	shooter.action = _shooting.new(target)
	await _frames(20)
	_check(target.hp < before, "Clear legal shot did not damage target")
	# A visible target can be outside the shooter's own sensor range.
	shooter.sight_range = 1.0
	_check(field.can_fire(shooter, target), "Allied spotting was not shared")
	scout.global_position = Vector3(60, 0, 60)
	_check(not field.can_fire(shooter, target), "Lost allied vision permits firing")
	shooter.action = _attacking.new(target)
	await _frames(4)
	_check(not shooter.get_node("Movement")._has_destination, "Attack follows hidden target")
	_check(
		not field.line_clear(Vector3(23, 0.8, 30), Vector3(31, 0.8, 30)),
		"Desert rock fails to block sight"
	)
	_check(
		field.line_clear(Vector3(23, 5, 30), Vector3(31, 5, 30)),
		"Elevated ray cannot see above rock"
	)
	_check(
		not field.line_clear(Vector3(23, 5, 30), Vector3(29, 0.8, 30)),
		"Sloping air ray passed through rock"
	)
	_check(
		not field.segment_hits_cylinder(Vector3(0, 4, 0), Vector3(0, 5, 0), Vector3.ZERO, 2, 3),
		"Vertical ray above blocker"
	)
	_check(
		field.segment_hits_cylinder(Vector3(0, 4, 0), Vector3(0, 1, 0), Vector3.ZERO, 2, 3),
		"Vertical ray misses cylinder"
	)


func _test_dynamic_spotters():
	var field = _game.battlefield
	var target = _spawn("Tank", _enemy, Vector3(44, 0, 48))
	var scout = _spawn("Worker", _human, Vector3(40, 0, 48))
	await _frames(5)
	_check(field.is_observed(_human, target), "Spotter did not acquire target")
	# Change live state repeatedly without advancing a physics frame or invalidating the field.
	target.position = Vector3(62, 0, 3)
	_check(not field.is_observed(_human, target), "Observer hint retained moved target visibility")
	target.position = Vector3(44, 0, 48)
	_check(field.is_observed(_human, target), "No-observation result was incorrectly retained")
	scout.sight_range = 1.0
	_check(not field.is_observed(_human, target), "Observer hint ignored changed sensor range")
	scout.sight_range = 10.0
	_check(field.is_observed(_human, target), "Sensor recovery did not restore observation")
	scout.reparent(_enemy)
	_check(not field.is_observed(_human, target), "Changed spotter ownership leaked enemy vision")
	scout.reparent(_human)
	_check(field.is_observed(_human, target), "Returned spotter was not usable")
	scout.position = Vector3(5, 0, 60)
	_check(not field.is_observed(_human, target), "Moving spotter retained old range")
	scout.position = Vector3(40, 0, 48)
	_check(field.is_observed(_human, target), "Moved-back spotter was not found")
	var alternate = _spawn("Worker", _human, Vector3(44, 0, 53))
	await _frames(4)
	_check(field.is_observed(_human, target), "Alternate spotter fixture is invisible")
	scout.hp = 0
	_check(field.is_observed(_human, target), "Lost first spotter did not fall back to ally")
	alternate.hp = 0
	_check(not field.is_observed(_human, target), "Dead spotter continued revealing")
	await _frames(5)
	var building = _spawn("Barracks", _human, Vector3(40, 0, 48))
	await _frames(40)
	_check(field.is_observed(_human, target), "Completed structure did not reveal target")
	building._construction_progress = 0.0
	_check(not field.is_observed(_human, target), "Unfinished hinted structure revealed target")
	building._construction_progress = 1.0
	_check(field.is_observed(_human, target), "Completed structure did not reacquire target")
	building.position = Vector3(36, 0, 48)
	var blocker = _spawn("Barracks", _enemy, Vector3(40, 0, 48))
	await _frames(40)
	# The witness was moved without rebaking its old navmesh hole. Establish the
	# intended optical fixture after async spawn alignment, before same-frame checks.
	blocker.global_position = Vector3(40, 0, 48)
	field.invalidate()
	var obstacle = blocker.get_node("MovementObstacle")
	_check(
		field.segment_hits_cylinder(
			building.global_position + Vector3.UP * 0.8,
			target.global_position + Vector3.UP * 0.8,
			blocker.global_position,
			obstacle.radius,
			obstacle.sight_height
		),
		"Completed-obstruction fixture misses the observation segment"
	)
	blocker._construction_progress = 0.0
	_check(field.is_observed(_human, target), "Foundation obstructed hinted observer")
	blocker._construction_progress = 1.0
	_check(
		not field.is_observed(_human, target), "Observer hint ignored newly completed obstruction"
	)
	blocker._construction_progress = 0.0
	_check(field.is_observed(_human, target), "Removed obstruction did not reacquire target")
	target.queue_free()
	_check(not field.is_observed(_human, target), "Queued target retained observation")


func _test_target_candidates():
	var field = _game.battlefield
	var source = _spawn("CombatRobot", _human, Vector3(40, 0, 48))
	var ground = _spawn("Tank", _enemy, Vector3(44, 0, 48))
	var air = _spawn("Drone", _enemy, Vector3(45, 2, 48))
	var ally = _spawn("Tank", _human, Vector3(41, 0, 48))
	var blocker = _spawn("Barracks", _enemy, Vector3(42, 0, 48))
	await _frames(40)
	blocker._construction_progress = 0.0
	source.position = Vector3(40, 0, 48)
	ground.position = Vector3(44, 0, 48)
	air.position = Vector3(47, 2, 48)
	field.invalidate()
	_check(field.fireable_targets(source).has(ground), "Candidate query lost nearby ground target")
	_check(not field.fireable_targets(source).has(ally), "Candidate query included ally")
	_check(not field.fireable_targets(source).has(air), "Candidate query bypassed short Bastion AA")
	_check_target_candidates(source, "ground and shorter AA range")
	air.position.x = 46.5
	_check(field.fireable_targets(source).has(air), "Exact AA boundary excluded")
	_check_target_candidates(source, "same-frame air movement and altitude")
	ground.position.x = 63
	_check_target_candidates(source, "same-frame target exits range")
	ground.position.x = 40 + source.attack_range
	ground.sight_range = null
	_check(
		field.fireable_targets(source).has(ground), "Range boundary or sightless target excluded"
	)
	_check_target_candidates(source, "range boundary and sightless target")
	ground.position.x += 0.001
	_check(not field.fireable_targets(source).has(ground), "Out-of-range target included")
	ground.position.x = 44
	blocker._construction_progress = 1.0
	_check(not field.fireable_targets(source).has(ground), "Candidate query ignored obstruction")
	_check_target_candidates(source, "newly completed obstruction")
	blocker._construction_progress = 0.0
	source.sight_range = 0.0
	ally.sight_range = 0.0
	_check_target_candidates(source, "visibility loss")
	ground.reparent(_human, true)
	_check_target_candidates(source, "ownership change")
	air.queue_free()
	_check_target_candidates(source, "queued target")
	source.attack_range = null
	_check(field.fireable_targets(source).is_empty(), "Unarmed source acquired targets")


func _check_target_candidates(source, label):
	var expected = get_nodes_in_group("units").filter(
		func(candidate): return _game.battlefield.can_fire(source, candidate)
	)
	_check(
		_game.battlefield.fireable_targets(source) == expected,
		"Target candidates changed full-scan legality/order: " + label
	)


func _test_damage():
	var rifle = _spawn("Infantry", _human, Vector3(40, 0, 8))
	var heavy = _spawn("Tank", _enemy, Vector3(42, 0, 8))
	var light = _spawn("Worker", _enemy, Vector3(43, 0, 8))
	var air = _spawn("Drone", _enemy, Vector3(43, 2, 8))
	var rail = _spawn("AdvancedTank", _human, Vector3(40, 0, 10))
	var walker = _spawn("CombatRobot", _human, Vector3(40, 0, 12))
	var rules = load("res://source/match/combat/CombatRules.gd")
	var before = heavy.hp
	for _i in range(10):
		heavy.receive_weapon_hit(rifle)
	_check(
		is_equal_approx(before - heavy.hp, 4.5),
		"Fractional rifle damage rounded away or wrong heavy multiplier"
	)
	_check(
		is_equal_approx(rules.damage(rail, heavy), rail.attack_damage * 1.4), "Rail heavy counter"
	)
	_check(
		is_equal_approx(rules.damage(rifle, light), rifle.attack_damage * 0.6),
		"Rifle light counter"
	)
	before = air.hp
	air.receive_weapon_hit(rifle)
	_check(air.hp == before, "Rifle damaged unsupported air domain")
	air.receive_weapon_hit(walker)
	_check(is_equal_approx(before - air.hp, walker.attack_damage), "Walker anti-air damage profile")
	before = rifle.hp
	rifle.receive_weapon_hit(walker)
	_check(rifle.hp == before, "Friendly fire allowed")


func _test_projectiles():
	var system = _game.projectile_system
	var shooter = _spawn("Tank", _human, Vector3(40, 0, 8))
	var target = _spawn("Tank", _enemy, Vector3(44, 0, 8))
	await _frames(30)
	var before = target.hp
	var shell = system.launch(shooter, target)
	_check(target.hp == before, "Cannon hit before its flight completed")
	paused = true
	var remaining = shell.life - shell.age
	await _frames(20)
	_check(
		shell.life - shell.age == remaining and target.hp == before, "Projectile advanced in pause"
	)
	paused = false
	await _frames(30)
	_check(
		is_equal_approx(before - target.hp, shooter.attack_damage),
		(
			"Projectile hit twice or failed to resolve: %s of %s"
			% [before - target.hp, shooter.attack_damage]
		)
	)
	var rocket = system.launch(shooter, target)
	var impacts = _game.combat_effects.impacts_emitted
	target.queue_free()
	await _frames(50)
	_check(not system._rounds.has(rocket), "Missile retained a destroyed target")
	_check(
		_game.combat_effects.impacts_emitted == impacts, "Destroyed target produced a ghost impact"
	)
	# Rounds already flying keep their frozen weapon facts after the shooter dies.
	var gunner = _spawn("Tank", _human, Vector3(40, 0, 14))
	var mark = _spawn("Tank", _enemy, Vector3(44, 0, 14))
	await _frames(30)
	before = mark.hp
	var damage = load("res://source/match/combat/CombatRules.gd").damage(gunner, mark)
	system.launch(gunner, mark)
	gunner.queue_free()
	await _frames(30)
	_check(
		is_instance_valid(mark) and is_equal_approx(before - mark.hp, damage),
		"Round in flight was lost with its destroyed shooter"
	)
	var survivor = _spawn("Worker", _enemy, Vector3(47, 0, 8))
	shooter.process_mode = Node.PROCESS_MODE_PAUSABLE
	shooter.action = null
	await _frames(20)
	_check(
		not shooter.get_node("Movement")._has_destination,
		"Idle defense pursued outside weapon range"
	)
	shooter.sight_range = 9.0
	shooter.action = _attacking.new(survivor)
	var last_seen = survivor.global_position
	survivor.global_position = Vector3(60, 0, 8)
	await _frames(12)
	_check(
		shooter.get_node("Movement").target_position.distance_to(last_seen) < 0.01,
		"Attack followed hidden coordinates instead of last observed position"
	)


func _test_repair():
	var service = _game.repair_service
	var tank = _spawn("Tank", _human, Vector3(40, 0, 8))
	tank.hp = 20.0
	var robots = []
	for index in range(10):
		var robot = _spawn("RepairRobot", _human, Vector3(40 + (index % 2), 0, 9))
		robot.process_mode = Node.PROCESS_MODE_PAUSABLE
		robots.append(robot)
	await _frames(45)
	for robot in robots:
		robot.global_position = Vector3(40, 0, 9)
		robot.get_node("Movement").stop()
		robot.get_node("Movement").set_physics_process(false)
	service.service(1.0)
	_check(is_equal_approx(tank.hp, 22.0), "Ten robots stacked healing instead of one 2.5% channel")
	var depot = _spawn("RepairDepot", _human, Vector3(40, 0, 11))
	depot.process_mode = Node.PROCESS_MODE_PAUSABLE
	tank.global_position = depot.service_point(tank)
	for robot in robots:
		robot.global_position = tank.global_position + Vector3(0, 0, 1)
	service.service(1.0)
	_check(is_equal_approx(tank.hp, 25.2), "Depot and mobile channel stacked")
	# Under low power the stronger robot channel must win over a slowed depot.
	var power_consumer = _spawn("AircraftFactory", _human, Vector3(30, 0, 10))
	var power_consumer2 = _spawn("AircraftFactory", _human, Vector3(30, 0, 15))
	var power_consumer3 = _spawn("AircraftFactory", _human, Vector3(30, 0, 20))
	service.service(1.0)
	_check(is_equal_approx(tank.hp, 27.2), "Low-power service beat stronger mobile repair")
	for building in [power_consumer, power_consumer2, power_consumer3]:
		building.queue_free()
	var attacker = _spawn("Infantry", _enemy, Vector3(43, 0, 8))
	tank.receive_weapon_hit(attacker)
	var before = tank.hp
	service.service(1.0)
	_check(
		is_equal_approx(tank.hp - before, 0.8), "Recent enemy damage did not reduce repair to 25%"
	)
	_game.simulation_time += 3.01
	before = tank.hp
	service.service(1.0)
	_check(
		is_equal_approx(tank.hp - before, 3.2),
		"Repair suppression failed to expire on simulation time"
	)
	for robot in robots:
		robot.process_mode = Node.PROCESS_MODE_DISABLED
	var tanks = [tank]
	for index in range(2):
		var additional = _spawn("Tank", _human, Vector3(42 + index, 0, 11))
		additional.hp = 10.0
		tanks.append(additional)
	var initial = tanks.map(func(unit): return unit.hp)
	service.service(1.0)
	var healed = 0
	for index in range(tanks.size()):
		if tanks[index].hp > initial[index]:
			healed += 1
	_check(healed == 1, "Depot must repair only the vehicle on its platform")
	var infantry = _spawn("Infantry", _human, Vector3(40, 0, 9))
	infantry.hp = 5.0
	_check(not service.mobile_eligible(robots[0], infantry), "Robot allowed to repair infantry")
	_check(not service.mobile_eligible(robots[0], robots[0]), "Robot allowed self repair")
	var barracks = _spawn("Barracks", _human, Vector3(42, 0, 8))
	barracks.process_mode = Node.PROCESS_MODE_PAUSABLE
	service.service(1.0)
	_check(is_equal_approx(infantry.hp, 5.88), "Infantry producer does not recover infantry")
	var airfield = _spawn("AircraftFactory", _human, Vector3(48, 0, 14))
	airfield.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Rotorcraft are serviced on the airfield's helipads.
	var aircraft = _spawn("Drone", _human, airfield.pad_point(1) + Vector3.UP * 2)
	aircraft.hp = 5.0
	service.service(1.0)
	_check(aircraft.hp > 5.0, "Stationary aircraft did not recover")
	before = aircraft.hp
	aircraft.get_node("Movement").move(Vector3(55, 2, 17))
	service.service(1.0)
	_check(aircraft.hp == before, "Moving aircraft recovered")
	aircraft.get_node("Movement").stop()
	service.set_physics_process(true)
	paused = true
	before = tank.hp
	var time_before = _game.simulation_time
	await _frames(30)
	_check(
		tank.hp == before and _game.simulation_time == time_before,
		"Repair or suppression timer advanced while paused"
	)
	paused = false
	service.set_physics_process(false)


func _clear():
	for unit in _test_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_test_units.clear()
	await _frames(5)


func _frames(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
