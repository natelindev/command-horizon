extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Profile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
var _errors = []
var _game
var _units = []


func _initialize():
	call_deferred("_run")


func _run():
	_test_random_isolation()
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	# Fogged units skip pose updates; reveal both factions to animate them.
	settings.visibility = settings.Visibility.FULL
	var constants = root.get_node("Constants")
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	for frame in range(30):
		await process_frame
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	var roles = [
		"Infantry",
		"Worker",
		"Tank",
		"AdvancedTank",
		"CombatRobot",
		"RepairRobot",
		"Drone",
		"Helicopter"
	]
	var players = get_nodes_in_group("players")
	for side in range(2):
		for index in range(roles.size()):
			var unit = _spawn(
				roles[index], players[side], Vector3(15 + side * 35, 0, 10 + index * 3)
			)
			_test_idle(unit)
			_test_attack(unit)
		for role in ["AntiGroundTurret", "CommandLab", "VehicleFactory", "RepairDepot"]:
			var unit = _spawn(role, players[side], Vector3(15 + side * 35, 0, 40))
			var geometry = unit.get_node("Geometry")
			var rest = geometry.transform
			var visual = unit.get_node("BastionVisuals")
			for frame in range(900):
				visual._process(1.0 / 60)
			_check(geometry.transform.is_equal_approx(rest), "Structure foundation moved: " + role)
	_test_group_variation(players[0])
	_test_group_variation(players[1])
	# The same canonical Tank scene receives each faction's own visual profile.
	players[1].faction = "frontier"
	_test_group_variation(players[1])
	players[1].faction = "helix"
	await _test_pause(_units[0])
	_game.queue_free()
	for frame in range(8):
		await process_frame
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: all 16 faction/mobile roles idle; motion bounds/no drift; orders/aim interrupt; "
				+ "attack/death variety; RNG isolation; foundations fixed; pause"
			)
		)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.action = null
	_units.append(unit)
	return unit


func _test_random_isolation():
	seed(8123)
	var expected = randi()
	seed(8123)
	for index in range(100):
		var profile = Profile.new(index)
		profile.next_shot()
		profile.death_motion(true, false, true)
	_check(randi() == expected, "Cosmetic RNG changed simulation RNG")
	var first = Profile.new(44)
	var second = Profile.new(44)
	_check(
		first.phase == second.phase and first.idle_delay == second.idle_delay,
		"Seed not reproducible"
	)


func _test_idle(unit):
	var visual = unit.get_node("BastionVisuals")
	var geometry = unit.get_node("Geometry")
	var root_before = unit.transform
	var hp = unit.hp
	var interval = unit.attack_interval
	var action_before = unit.action
	for frame in range(180):
		visual._process(1.0 / 60)
	_check(visual._idle_blend == 0.0, "Long-idle gesture started before threshold")
	for frame in range(480):
		visual._process(1.0 / 60)
	var animated_body = (
		geometry.get_node("InfantryRig/Chest") if geometry.has_node("InfantryRig") else geometry
	)
	var pose = animated_body.transform
	for frame in range(30):
		visual._process(1.0 / 60)
	_check(
		not pose.is_equal_approx(animated_body.transform),
		"Frozen long idle: " + unit.player.faction + unit.type
	)
	_check(visual._idle_blend > 0.99, "Long idle never activated")
	for frame in range(3600):
		visual._process(1.0 / 60)
		if frame % 60 == 0:
			_check(
				(
					unit.to_local(geometry.global_position).distance_to(
						visual._geometry_rest.origin
					)
					< 0.08
				),
				"Idle translation drift"
			)
	_check(unit.transform == root_before and unit.hp == hp, "Animation altered unit authority")
	_check(
		unit.action == action_before and unit.attack_interval == interval,
		"Animation altered order/cooldown"
	)
	# A queued movement order suppresses gestures even when physically blocked.
	visual._movement._has_destination = true
	for frame in range(30):
		visual._process(1.0 / 60)
	_check(visual._idle_blend == 0.0 and visual._quiet_time == 0.0, "Blocked movement appears idle")
	visual._movement._has_destination = false


func _test_attack(unit):
	var visual = unit.get_node("BastionVisuals")
	var strengths = {}
	for shot in range(12):
		visual._idle_blend = 1.0
		visual.fire_recoil()
		_check(visual._idle_blend == 0.0, "Shot failed to cancel idle")
		strengths[snappedf(visual.motion.recoil_strength, 0.001)] = true
		for frame in range(60):
			visual._process(1.0 / 60)
		_check(visual._recoil == 0.0, "Recoil did not recover")
		if visual._barrel != null:
			_check(visual._barrel.position.is_equal_approx(visual._barrel_rest), "Barrel drift")
	_check(strengths.size() > 5, "Repeated identical attack animation")
	visual.hit_reaction(unit.global_position + Vector3.RIGHT)
	var right = visual._hit_axis
	visual.hit_reaction(unit.global_position + Vector3.LEFT)
	_check(right.dot(visual._hit_axis) < 0.0, "Hit reaction ignores impact side")


func _test_group_variation(player):
	var poses = {}
	var deaths = {}
	var timings = {}
	var strengths = {}
	var rolls = {}
	for index in range(24):
		var unit = _spawn("Tank", player, Vector3(20 + index, 0, 22))
		var visual = unit.get_node("BastionVisuals")
		for frame in range(660):
			visual._process(1.0 / 60)
		poses[str(unit.get_node("Geometry").transform)] = true
		visual.fire_recoil()
		timings[snappedf(visual.motion.recoil_duration, 0.001)] = true
		strengths[snappedf(visual.motion.recoil_strength, 0.001)] = true
		rolls[snappedf(visual.motion.recoil_roll, 0.0001)] = true
		var recipe = visual.death_motion()
		deaths[str(recipe.tilt)] = true
		_check(
			recipe.slide.length() <= 0.26 and recipe.tilt.length() < 0.3, "Unbounded vehicle death"
		)
		# Exercise the exact wreck interpolation on geometry only, including full cleanup age.
		var proxy = Node3D.new()
		root.add_child(proxy)
		var entry = {
			"node": proxy,
			"motion": recipe,
			"age": 0.0,
			"origin": Vector3(20, 0, 22),
			"rotation": Vector3.ZERO
		}
		for frame in range(480):
			entry.age = frame / 60.0
			_game.combat_effects._update_wreck(entry)
			_check(proxy.position.is_finite() and proxy.rotation.is_finite(), "Invalid wreck pose")
		proxy.queue_free()
	var faction = player.faction
	_check(poses.size() > 20, faction + " large group idle poses synchronized")
	_check(deaths.size() > 20, faction + " large group deaths synchronized")
	_check(
		strengths.size() > 10 and rolls.size() > 10,
		faction + " large group recoil strength/roll synchronized"
	)
	if faction == "bastion":
		_check(
			timings.size() == 1 and timings.has(0.4),
			"Bastion cannon recovery must remain exactly 0.4 seconds"
		)
	else:
		_check(timings.size() > 10, faction + " large group recoil timings synchronized")
	# Target acquisition wins over idle scanning immediately at shot time.
	var shooter = _units[-1]
	var visual = shooter.get_node("BastionVisuals")
	shooter.aim_target = _units[0]
	visual._idle_blend = 1.0
	visual.fire_recoil()
	var target_local = (
		visual._turret.get_parent().to_local(shooter.aim_target.global_position + Vector3.UP * 0.45)
		- visual._turret.position
	)
	_check(
		(
			absf(
				angle_difference(visual._turret.rotation.y, atan2(-target_local.x, -target_local.z))
			)
			< 0.001
		),
		"Idle scan spoiled shot aim"
	)
	shooter.aim_target = null


func _test_pause(unit):
	var visual = unit.get_node("BastionVisuals")
	visual.process_mode = Node.PROCESS_MODE_PAUSABLE
	var clock_running = visual._clock
	for frame in range(12):
		await process_frame
	_check(visual._clock > clock_running, "Pause test motion was not running")
	paused = true
	var before = unit.get_node("Geometry").transform
	var clock_before = visual._clock
	for frame in range(15):
		await process_frame
	_check(
		before == unit.get_node("Geometry").transform and visual._clock == clock_before,
		"Motion advanced during tactical pause"
	)
	paused = false


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
