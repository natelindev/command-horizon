extends SceneTree

# Physical rounds: gravity arcs, led hits on a steady mover, misses on a target
# that changes course, blocker absorption, splash falloff, guided turn limits,
# instant rail lines and deterministic dispersion.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Weapons = preload("res://source/match/combat/WeaponCatalog.gd")
var _errors = []
var _game
var _human
var _enemy
var _system
var _rules
var _shooting
var _units = []
var _driven = {}


func _initialize():
	call_deferred("_run")


func _run():
	_rules = load("res://source/match/combat/CombatRules.gd")
	_shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.match_seed = 4242
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
	await _ticks(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	_system = _game.projectile_system
	physics_frame.connect(_drive)
	await _test_gravity_arc()
	await _test_lead_and_dodge()
	await _test_blocker()
	await _test_capture_site_blocker()
	await _test_splash()
	await _test_guidance()
	await _test_rail_and_determinism()
	for faction in ["bastion", "helix", "frontier"]:
		_human.faction = faction
		await _test_infantry_anti_air()
		await _test_mobile_anti_air()
		await _test_anti_air_ground("AntiAirVehicle")
		await _test_anti_air_ground("AntiAirTurret")
		await _test_bomb_building_damage()
	_game.queue_free()
	await _ticks(5)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: gravity arcs, led hits, dodged rounds, blockers, splash falloff, "
				+ "guided turn limits, rail lines, deterministic dispersion, "
				+ "all-faction anti-air and bomb building damage"
			)
		)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _test_gravity_arc():
	var shooter = _spawn("Tank", _human, Vector3(30, 0, 16))
	var target = _spawn("Tank", _enemy, Vector3(38, 0, 16))
	await _ticks(5)
	_face(shooter, target)
	var round = _system.launch(shooter, target)
	var vertical = round.velocity.y
	await _ticks(1)
	var drop = vertical - round.velocity.y
	var tick = 1.0 / Engine.physics_ticks_per_second
	_check(
		is_equal_approx(snappedf(drop, 0.001), snappedf(Weapons.GRAVITY * tick, 0.001)),
		"Shell did not accelerate downward under gravity: %s" % drop
	)
	_check(vertical > 0.0, "Shell was not launched above the line to compensate for drop")
	await _clear()


func _test_lead_and_dodge():
	var shooter = _spawn("RocketInfantry", _human, Vector3(30, 0, 20))
	var target = _spawn("Tank", _enemy, Vector3(39, 0, 20))
	await _ticks(5)
	# A steady crossing target is led and hit.
	var crossing = Vector3(0, 0, 2.5)
	_drive_unit(target, crossing, crossing)
	var before = target.hp
	_face(shooter, target)
	_system.launch(shooter, target)
	await _ticks(45)
	_check(target.hp < before, "Rocket failed to lead a steadily crossing target")
	# The same shot misses when the target reverses right after launch.
	target.global_position = Vector3(39, 0, 20)
	await _ticks(2)
	before = target.hp
	_drive_unit(target, crossing, -crossing * 1.6)
	_face(shooter, target)
	_system.launch(shooter, target)
	await _ticks(45)
	_check(target.hp == before, "Unguided rocket hit a target that reversed course")
	_driven.clear()
	await _clear()


func _test_blocker():
	var shooter = _spawn("Tank", _human, Vector3(30, 0, 24))
	var wall = _spawn("Barracks", _human, Vector3(35, 0, 24))
	var target = _spawn("Tank", _enemy, Vector3(40, 0, 24))
	await _ticks(10)
	_game.battlefield.invalidate()
	var before = target.hp
	var wall_hp = wall.hp
	_face(shooter, target)
	_system.launch(shooter, target)
	await _ticks(30)
	_check(target.hp == before, "Round passed through a building")
	_check(wall.hp == wall_hp, "Round damaged the shooter's own building")
	await _clear()


func _test_splash():
	var shooter = _spawn("Tank", _human, Vector3(31, 0, 27))
	var target = _spawn("Tank", _enemy, Vector3(39, 0, 27))
	# Beside the shell's impact point on the hull, clear of its flight line.
	var neighbor = _spawn("Infantry", _enemy, Vector3(38.4, 0, 27.8))
	var distant = _spawn("Infantry", _enemy, Vector3(39, 0, 24.5))
	await _ticks(5)
	var direct = _rules.damage(shooter, target)
	var near_full = _rules.damage(shooter, neighbor)
	var hp = [target.hp, neighbor.hp, distant.hp]
	_face(shooter, target)
	_system.launch(shooter, target)
	await _ticks(20)
	_check(is_equal_approx(hp[0] - target.hp, direct), "Direct hit damage changed")
	var dealt = hp[1] - neighbor.hp
	_check(
		dealt > 0.0 and dealt < near_full * _system.SPLASH_SHARE,
		"Near miss splash did not fall off: %s of %s" % [dealt, near_full]
	)
	_check(distant.hp == hp[2], "Splash reached beyond its radius")
	await _clear()


func _test_guidance():
	var battery = _spawn("AntiAirTurret", _human, Vector3(30, 0, 40))
	var straight = _spawn("Helicopter", _enemy, Vector3(38, 0, 40))
	var agile = _spawn("Helicopter", _enemy, Vector3(30, 0, 46))
	await _ticks(10)
	for craft in [straight, agile]:
		craft.global_position.y = 2.0
	var before = straight.hp
	_drive_unit(straight, Vector3(4, 0, 0), Vector3(4, 0, 0))
	_face(battery, straight)
	_system.launch(battery, straight)
	await _ticks(60)
	_check(straight.hp < before, "Missile failed to intercept a straight-flying aircraft")
	_driven.clear()
	# A target that breaks away faster than the missile can turn or fly escapes.
	before = agile.hp
	_drive_unit(agile, Vector3.ZERO, Vector3.ZERO)
	_face(battery, agile)
	var missile = _system.launch(battery, agile)
	_drive_unit(agile, Vector3(34, 0, 0), Vector3(34, 0, 0))
	for _tick in range(90):
		await _ticks(1)
		if not _system._rounds.has(missile):
			break
	_check(agile.hp == before, "Missile caught a target beyond its turn and speed limits")
	await _clear()


func _test_rail_and_determinism():
	_check(_human.faction == "bastion", "Fixture expected the Bastion rail tank")
	var rail = _spawn("AdvancedTank", _human, Vector3(30, 0, 43))
	var target = _spawn("Tank", _enemy, Vector3(39, 0, 43))
	await _ticks(5)
	var before = target.hp
	_face(rail, target)
	var slug = _system.launch(rail, target)
	_check(target.hp < before, "Rail slug did not resolve along its line in one tick")
	_check(not _system._rounds.has(slug), "Rail slug stayed in flight")
	var rifle = _spawn("Infantry", _human, Vector3(30, 0, 48))
	await _ticks(2)
	var serial = _system.rounds_fired
	_face(rifle, target)
	var first = _system.launch(rifle, target)
	_system.rounds_fired = serial
	_face(rifle, target)
	var second = _system.launch(rifle, target)
	_check(first.velocity == second.velocity, "Dispersion is not deterministic for the same serial")
	_face(rifle, target)
	var third = _system.launch(rifle, target)
	_check(first.velocity != third.velocity, "Dispersion did not vary between shots")
	await _clear()


# Shooters turn toward their target before firing, as AttackingWhileInRange does.
func _face(unit, target):
	var flat = Vector3(target.global_position.x, unit.global_position.y, target.global_position.z)
	if unit.global_position.distance_to(flat) > 0.01:
		unit.global_transform = unit.global_transform.looking_at(flat, Vector3.UP)


func _test_infantry_anti_air():
	var soldier = _spawn("RocketInfantry", _human, Vector3(31, 0, 20))
	var craft = _spawn("Helicopter", _enemy, Vector3(37, 0, 20))
	await _ticks(10)
	craft.global_position.y = 1.6
	_check(_rules.can_target(soldier, craft), "Rocket infantry cannot target aircraft")
	_check(
		(
			_rules.preparation_for(soldier, craft) > 0.0
			and _rules.preparation_for(soldier, null) == 0.0
		),
		"Infantry missile lock is not limited to aircraft"
	)
	var before = craft.hp
	var fired = _system.rounds_fired
	soldier.process_mode = Node.PROCESS_MODE_PAUSABLE
	soldier.action = _shooting.new(craft)
	await _ticks(12)
	_check(_system.rounds_fired == fired, "Infantry missile launched before its lock completed")
	await _ticks(60)
	_check(_system.rounds_fired > fired, "Rocket infantry never launched at the aircraft")
	_check(craft.hp < before, "Infantry missile did not damage the aircraft")
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	await _clear()


func _test_mobile_anti_air():
	var vehicle = _spawn("AntiAirVehicle", _human, Vector3(31, 0, 20))
	var craft = _spawn("Helicopter", _enemy, Vector3(37, 0, 20))
	var tank = _spawn("Tank", _enemy, Vector3(37, 0, 24))
	await _ticks(10)
	craft.global_position.y = 2.5
	var faction = _human.faction
	_check(_rules.can_target(vehicle, craft), faction + " AA vehicle cannot target aircraft")
	_check(_rules.can_target(vehicle, tank), faction + " AA vehicle cannot target ground armor")
	var before = craft.hp
	var fired = _system.rounds_fired
	vehicle.process_mode = Node.PROCESS_MODE_PAUSABLE
	vehicle.action = _shooting.new(craft)
	for _tick in range(120):
		await _ticks(1)
		if not is_instance_valid(craft) or craft.hp < before:
			break
	_check(_system.rounds_fired > fired, faction + " AA vehicle never fired at aircraft")
	_check(
		not is_instance_valid(craft) or craft.hp < before,
		faction + " AA vehicle's physical projectiles never damaged aircraft"
	)
	vehicle.process_mode = Node.PROCESS_MODE_DISABLED
	await _clear()


func _test_anti_air_ground(role):
	var shooter = _spawn(role, _human, Vector3(31, 0, 20))
	var label = _human.faction + " " + role
	for target_role in ["Infantry", "RepairRobot", "Tank", "Barracks", "Fighter", "Helicopter"]:
		var target = _spawn(target_role, _enemy, Vector3(37, 0, 20))
		await _ticks(10)
		# A parked aircraft has light-machine armor but is a ground target.
		if target_role == "Fighter":
			var flight = target.get_node("Movement")
			flight.phase = flight.Phase.PARKED
		_check(_rules.can_target(shooter, target), label + " cannot target " + target_role)
		var expected = shooter.attack_damage * (1.0 if target_role == "Helicopter" else 0.33)
		_check(
			is_equal_approx(_rules.damage(shooter, target), expected),
			label + " damage has the wrong domain multiplier against " + target_role
		)
		var shot = load("res://source/match/combat/Shot.gd").from(shooter, shooter.global_position)
		_check(
			is_equal_approx(_rules.damage_from(shot, target), expected),
			label + " projectile damage differs against " + target_role
		)
		if target_role == "Tank":
			_check(_game.battlefield.can_fire(shooter, target), label + " cannot fire at ground")
			_check(
				_game.battlefield.fireable_targets(shooter).has(target),
				label + " ground target missing from automatic acquisition"
			)
			var before = target.hp
			shooter.process_mode = Node.PROCESS_MODE_PAUSABLE
			shooter.action = _shooting.new(target, 1)
			for _tick in range(120):
				await _ticks(1)
				if target.hp < before:
					break
			_check(
				is_equal_approx(before - target.hp, expected),
				label + " did not land one reduced-damage ground hit"
			)
			shooter.process_mode = Node.PROCESS_MODE_DISABLED
		target.queue_free()
		await _ticks(5)
	await _clear()


func _test_bomb_building_damage():
	var bomber = _spawn("Bomber", _human, Vector3(31, 0, 20))
	var building = _spawn("Barracks", _enemy, Vector3(37, 0, 20))
	await _ticks(10)
	bomber.global_position = building.global_position + Vector3.UP * 5.0
	var before = building.hp
	_system.launch(bomber, building, Weapons.GRAVITY_BOMB)
	for _tick in range(120):
		await _ticks(1)
		if building.hp < before:
			break
	_check(
		is_equal_approx(before - building.hp, bomber.attack_damage * 2.0),
		_human.faction + " bomb did not deal double damage to a building"
	)
	await _clear()


func _test_capture_site_blocker():
	var shooter = _spawn("Tank", _human, Vector3(30, 0, 20))
	var target = _spawn("Tank", _enemy, Vector3(38, 0, 20))
	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	_game.add_child(relay)
	relay.global_position = Vector3(34, 0, 20)
	relay.process_mode = Node.PROCESS_MODE_DISABLED
	await _ticks(5)
	_game.battlefield.invalidate()
	_check(not _rules.can_target(shooter, relay), "Capture relay became a damageable target")
	var before = target.hp
	_face(shooter, target)
	_system.launch(shooter, target)
	await _ticks(30)
	_check(target.hp == before, "Shell passed through the capture relay")
	_check(relay.hp == 1.0, "Shell damaged the indestructible capture relay")
	_check(_system.round_count() == 0, "Shell did not stop on the capture relay")
	relay.queue_free()
	await _clear()


func _drive_unit(unit, reported, actual):
	var movement = unit.get_node("Movement")
	movement._has_destination = true
	movement.velocity = reported
	_driven[unit] = actual


func _drive():
	var delta = 1.0 / Engine.physics_ticks_per_second
	for unit in _driven:
		if is_instance_valid(unit):
			unit.global_position += _driven[unit] * delta


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_units.append(unit)
	return unit


func _clear():
	_driven.clear()
	_system.clear()
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	await _ticks(5)


func _ticks(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
