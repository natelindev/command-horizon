extends "res://tests/headless/InfantryHeroesRegression.gd"

var measurements = []
var _attack_type
var _attack_move_type


func _run():
	_attack_type = load("res://source/match/units/actions/AutoAttacking.gd")
	_attack_move_type = load("res://source/match/units/actions/AttackMoving.gd")
	Factions = load("res://source/match/FactionCatalog.gd")
	Combat = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in Factions.IDS:
		await _fixture(faction)
		for role in Roster.INFANTRY_ROLES:
			var unit = _soldier(role, human, Vector3(40, 0, 10))
			_test_articulation(unit)
			unit.queue_free()
		await _frames(2)
		await _test_ranges()
		await _test_squad(false)
		await _test_squad(true)
		await _close()
	for message in errors:
		push_error(message)
	print("Engagement measurements: ", JSON.stringify(measurements))
	print("Infantry motion and ranges: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _fixture(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(45)
	_freeze_units()
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	game.repair_service.set_physics_process(false)


func _test_articulation(unit):
	var visual = unit.get_node("BastionVisuals")
	var motion = visual._infantry_motion
	_check(motion != null, "Missing human rig: " + unit.type)
	if motion == null:
		return
	var badge = unit.find_child("UnitMark", true, false)
	_check(
		badge.get_surface_override_material(0) == unit.player.get_color_material(),
		"Human model lost player color"
	)
	var authority = unit.transform
	var knee_poses = {}
	var chest_before = motion.chest.transform
	for frame in range(120):
		motion.advance(1.0 / 60.0, .025, frame / 60.0, 0.0, 0.0, 0.0)
		for leg in motion.legs:
			knee_poses[snappedf(leg[1].rotation.x, .01)] = true
			_check(leg[1].rotation.x < 0, "Knee bent backwards")
			var foot = motion.rig.to_local(leg[2].global_position)
			_check(foot.y >= .043 and foot.y <= .155, "Foot sinks or floats out of gait bounds")
			_check(absf(leg[2].global_rotation.x) < .001, "Foot sole is not level")
	_check(knee_poses.size() > 12, "Knees remain rigid while walking")
	_check(motion.chest.transform != chest_before, "Upper body remains frozen")
	var phase = motion.phase
	for frame in range(120):
		motion.advance(1.0 / 60.0, 0.0, frame / 60.0, .2, 0.0, 0.0)
	_check(motion.phase == phase and motion.blend == 0, "Stopped infantry runs in place")
	for leg in motion.legs:
		_check(
			absf(motion.rig.to_local(leg[2].global_position).y - .045) < .002,
			"Idle boot is not planted"
		)
	visual.fire_recoil()
	visual._process(1.0 / 60.0)
	_check(
		visual._projectile_origin.global_position.is_equal_approx(visual._muzzle.global_position),
		"Shot muzzle detached from held weapon"
	)
	_check(unit.transform == authority, "Cosmetic rig changed gameplay position")
	var gear = unit.get_node("Geometry/InfantryRig/Chest").get_node_or_null("ClassEquipment")
	_check(unit.type == "Infantry" or gear != null, "Class equipment does not follow chest")


func _test_ranges():
	for role in [
		"Infantry",
		"AssaultInfantry",
		"RocketInfantry",
		"SniperInfantry",
		"Hero",
		"Tank",
		"AdvancedTank",
		"CombatRobot",
		"Helicopter",
		"AntiGroundTurret",
		"AntiAirTurret"
	]:
		var unit = _soldier(role, human, Vector3(30, 0, 25))
		var target_role = "Drone" if role == "AntiAirTurret" else "Tank"
		var target = _soldier(target_role, opponent, Vector3(34, 0, 25))
		await _frames(3)
		# Spawn projection can move either actor away from incidental scenery.
		# Measure the actual firing ray from the settled source position.
		target.global_position.z = unit.global_position.z
		var reach = Combat.range_for(unit, target)
		_check(unit.sight_range >= reach, "Sight truncates range: " + role)
		target.global_position.x = unit.global_position.x + reach - .1
		game.battlefield.invalidate()
		if not game.battlefield.can_fire(unit, target):
			print(
				"RANGE DIAGNOSTIC ",
				human.faction,
				" ",
				role,
				" positions=",
				unit.global_position,
				"/",
				target.global_position,
				" reach=",
				reach,
				" targetable=",
				Combat.can_target(unit, target),
				" observed=",
				game.battlefield.is_observed(human, target),
				" line=",
				game.battlefield.has_line_of_fire(unit, target)
			)
		_check(game.battlefield.can_fire(unit, target), "Cannot fire near new range edge: " + role)
		_check(
			game.battlefield.fireable_targets(unit).has(target),
			"Target scan truncates new range: " + role
		)
		target.global_position.x += .2
		game.battlefield.invalidate()
		_check(not game.battlefield.can_fire(unit, target), "Can fire beyond range: " + role)
		unit.queue_free()
		target.queue_free()
		await _frames(3)


func _test_squad(attack_move):
	var target = _soldier("Tank", opponent, Vector3(54, 0, 10))
	target.hp_max = 10000
	target.hp = 10000
	var durability = target.hp + target.shields
	var spotter = _soldier("Drone", human, Vector3(53, 0, 13))
	var squad = []
	for index in range(8):
		var soldier = _soldier("Infantry", human, Vector3(40 - index / 4, 0, 8.5 + (index % 4)))
		squad.append(soldier)
	await _frames(10)
	for soldier in squad:
		soldier.process_mode = Node.PROCESS_MODE_PAUSABLE
		soldier.issue_manual_order(
			_attack_move_type.new(Vector3(58, 0, 10)) if attack_move else _attack_type.new(target)
		)
	await _frames(300)
	var closest = INF
	var firing = 0
	var holding_range = 0
	for soldier in squad:
		var distance = soldier.global_position_yless.distance_to(target.global_position_yless)
		closest = minf(closest, distance)
		if is_instance_valid(soldier.aim_target):
			firing += 1
		if distance > 6.0:
			holding_range += 1
		# Avoidance scheduling varies across native runners. Permit an outlying
		# soldier to be nudged inward, while rejecting the old 5.2-5.4 m collapse.
		_check(distance > 5.5, "Soldier compressed into the old short firing range")
	_check(holding_range >= 6, "Most of the squad compressed below its firing standoff")
	_check(firing >= 6, "Most of the squad cannot settle into firing positions")
	_check(target.hp + target.shields < durability, "Squad stopped without firing")
	measurements.append(
		{
			"faction": human.faction,
			"attack_move": attack_move,
			"closest": closest,
			"firing": firing,
			"holding_range": holding_range
		}
	)
	var move_order = load("res://source/match/units/actions/Moving.gd")
	for soldier in squad:
		if is_instance_valid(soldier.aim_target):
			_check(
				is_equal_approx(soldier.get_node("Movement").avoidance_priority, .8),
				"Settled shooter yields to incoming ranks"
			)
		soldier.issue_manual_order(move_order.new(Vector3(40, 0, 16)))
	await _frames(3)
	for soldier in squad:
		_check(
			is_equal_approx(soldier.get_node("Movement").avoidance_priority, .5),
			"Move order retains firing priority"
		)
		soldier.queue_free()
	target.queue_free()
	spotter.queue_free()
	await _frames(5)
