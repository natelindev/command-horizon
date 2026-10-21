extends SceneTree

# Animation overhaul regressions: stride matches ground speed (no skating), squads
# and convoys stay desynchronized, animation never alters gameplay state, eased
# turning/turret traverse, aircraft banking, braced and kneeling shooters, wheel
# roll for every wheeled model, and animation work stopping when hidden, settled
# or destroyed.
const Catalog = preload("res://source/match/BastionCatalog.gd")
const InfantryMotionScript = preload("res://source/match/units/traits/InfantryMotion.gd")
const STEP = 1.0 / 60.0
const MOBILE_ROLES = [
	"Infantry",
	"RocketInfantry",
	"SniperInfantry",
	"AssaultInfantry",
	"Hero",
	"Worker",
	"Tank",
	"AdvancedTank",
	"RepairRobot",
	"CombatRobot",
	"Drone",
	"Helicopter",
]
var _errors = []
var _game
var _players = []
var _moving
var _attacking


func _initialize():
	call_deferred("_run")


func _run():
	_moving = load("res://source/match/units/actions/Moving.gd")
	_attacking = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		_test_authored_body_transform()
		_test_render_cadence()
		_test_no_skating()
		_test_walker_stance()
		_test_eased_heading()
		_test_turret_traverse()
		_test_aircraft_banking()
		_test_shooting_stances()
		_test_wheels()
		await _test_hidden_and_settled()
		await _test_gameplay_invariance()
		await _test_squad_desync()
		await _test_destruction()
		await _close()
	for message in _errors:
		push_error(message)
	print("Unit animation regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _test_authored_body_transform():
	var unit = _spawn("Tank", 0, Vector3(30, 0, 12))
	var visual = unit.get_node("BastionVisuals")
	var reference = Node3D.new()
	# Imported models may carry both an authored rotation and nonuniform scale.
	# Compare the in-memory composition against Node3D's rotation/position setters.
	var rest = Transform3D(
		Basis.from_euler(Vector3(.2, -.3, .4)) * Basis.from_scale(Vector3(1.2, .8, 1.1)),
		Vector3(.1, .3, -.2)
	)
	var rotation = Vector3(-.04, .15, .08)
	var offset = Vector3(.01, -.02, .03)
	reference.transform = rest
	reference.rotation += rotation
	reference.position += offset
	visual._geometry_rest = rest
	visual._rest_is_identity = false
	visual._pose_geometry(rotation, offset)
	_check(
		visual._geometry_pose.is_equal_approx(reference.transform),
		"Batched pose changed authored rotation or nonuniform scale"
	)
	reference.free()
	unit.queue_free()


func _fixture(faction):
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction if side == 0 else "bastion"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	await _frames(30)
	_players = get_nodes_in_group("players")
	for side in _players:
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	await _frames(2)


func _close():
	_game.queue_free()
	await _frames(6)


func _frames(count):
	for frame in range(count):
		await process_frame


func _spawn(role, side, point, frozen = true):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), _players[side], false)
	if frozen:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.action = null
	return unit


func _drive(unit, velocity, frames, turn_rate = 0.0):
	# Manually move a frozen unit like Movement would and animate one frame each.
	var visual = unit.get_node("BastionVisuals")
	for frame in range(frames):
		unit.global_position += velocity * STEP
		if turn_rate != 0.0:
			unit.rotate_y(turn_rate * STEP)
			velocity = velocity.rotated(Vector3.UP, turn_rate * STEP)
		visual._process(STEP)


# A fast renderer may draw several frames between simulation ticks. Test the
# sampled-root path too: those zero-travel frames must not restart the stride.
func _test_render_cadence():
	for role in ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"]:
		for fps in [30, 60, 144, 240, 1000]:
			var unit = _spawn(role, 0, Vector3(30, 0, 12))
			var motion = unit.get_node("BastionVisuals")._infantry_motion
			var delta = 1.0 / fps
			var previous_tick = 0
			var restarts = 0
			var started = false
			for frame in range(fps * 2):
				var tick = floori(float(frame + 1) * 30.0 / fps)
				var distance = (tick - previous_tick) * 2.5 / 30.0
				previous_tick = tick
				var was_moving = motion._moving
				motion.advance(delta, distance, frame * delta, 0.0, 0.0, 0.0)
				if started and not was_moving and motion._moving:
					restarts += 1
				started = started or motion._moving
			_check(
				restarts == 0,
				(
					"%s %s stride restarted %d times at %d render / 30 physics Hz"
					% [_players[0].faction, role, restarts, fps]
				)
			)
			# Tiny but continuous travel at high FPS must still count as walking.
			for frame in range(fps):
				motion.advance(delta, .1 * delta, frame * delta, 0.0, 0.0, 0.0)
			_check(motion._moving, "%s slow walk frozen at %d FPS" % [role, fps])
			for frame in range(fps):
				motion.advance(delta, 0.0, frame * delta, 0.0, 0.0, 0.0)
			_check(motion.is_at_rest(), "%s did not stop at %d FPS" % [role, fps])
			unit.queue_free()


func _test_no_skating():
	for role in ["Infantry", "SniperInfantry", "Hero"]:
		for speed in [0.7, 1.6, 3.5]:
			var unit = _spawn(role, 0, Vector3(30, 0, 12))
			var motion = unit.get_node("BastionVisuals")._infantry_motion
			_drive(unit, Vector3.FORWARD * speed, 30)
			var previous = []
			for leg in motion.legs:
				previous.append(leg[2].global_position)
			var slip = 0.0
			var planted = 0
			var cycles_before = motion.phase
			var ground = (.045 + .0003) * motion.rig.scale.y
			for frame in range(120):
				_drive(unit, Vector3.FORWARD * speed, 1)
				for index in range(2):
					var foot = motion.legs[index][2].global_position
					var stance = (
						foot.y < unit.global_position.y + ground
						and previous[index].y < unit.global_position.y + ground
					)
					if stance:
						slip = maxf(slip, (foot - previous[index]).length())
						planted += 1
					previous[index] = foot
			_check(planted > 60, "%s never plants a foot at %.1f m/s" % [role, speed])
			# A planted boot may roll by solver precision, never by stride distance.
			_check(
				slip < speed * STEP * .12,
				"%s skates %.4f m/frame at %.1f m/s" % [role, slip, speed]
			)
			_check(cycles_before != motion.phase, "%s gait frozen while moving" % role)
			var stride = motion.stride_length()
			_check(stride > .5 and stride < 1.12, "%s stride %.2f m implausible" % [role, stride])
			unit.queue_free()
	# Faster ground speed means faster footfalls and longer strides.
	var unit = _spawn("Infantry", 0, Vector3(30, 0, 12))
	var motion = unit.get_node("BastionVisuals")._infantry_motion
	var rates = []
	for speed in [0.8, 3.5]:
		_drive(unit, Vector3.FORWARD * speed, 60)
		var start = motion.phase
		var turned = 0.0
		for frame in range(60):
			_drive(unit, Vector3.FORWARD * speed, 1)
			turned += fposmod(motion.phase - start, TAU)
			start = motion.phase
		rates.append(turned)
	_check(rates[1] > rates[0] * 1.8, "Step cadence does not track ground speed")
	# Stopping takes recovery steps, then both boots rest planted.
	_drive(unit, Vector3.ZERO, 90)
	for leg in motion.legs:
		_check(
			absf(leg[2].global_position.y - unit.global_position.y - .045) < .003,
			"Boot left hanging after stop"
		)
	_check(motion.is_at_rest(), "Infantry never settles after stopping")
	unit.queue_free()


func _test_walker_stance():
	for role in ["CombatRobot", "RepairRobot"]:
		var unit = _spawn(role, 0, Vector3(30, 0, 16))
		var walker = unit.get_node("BastionVisuals")._walker
		var faction = _players[0].faction
		var legged = faction == "helix" or (faction == "bastion" and role == "CombatRobot")
		if not legged:
			_check(walker == null, "%s %s vehicle treated as a walker" % [faction, role])
			unit.queue_free()
			continue
		_check(walker != null and walker.legs.size() == 4, "Articulated walker legs missing")
		if walker == null:
			unit.queue_free()
			continue
		var worst_slide = 0.0
		var worst_target = 0.0
		var lift = 0.0
		var knees = {}
		for velocity in [
			Vector3.FORWARD * .15, Vector3.FORWARD * 1.5, Vector3.FORWARD * unit.movement_speed
		]:
			_drive(unit, velocity, 30)
			for frame in range(120):
				var before = walker.legs.map(func(leg): return leg.ankle.global_position)
				var swinging = walker.legs.map(func(leg): return leg.swing)
				_drive(unit, velocity, 1)
				var supports = 0
				for index in range(4):
					var leg = walker.legs[index]
					if not leg.swing:
						supports += 1
						if not swinging[index]:
							worst_slide = maxf(
								worst_slide, before[index].distance_to(leg.ankle.global_position)
							)
					worst_target = maxf(
						worst_target,
						leg.ankle.global_position.distance_to(unit.global_transform * leg.foot)
					)
					lift = maxf(lift, leg.foot.y - leg.home.y)
					_check(
						leg.ankle.global_basis.y.normalized().dot(Vector3.UP) > .999,
						"Walker sole tilts with its shin"
					)
					knees[snappedf(leg.knee.rotation.length(), .03)] = true
				_check(supports >= 2, "Walker lost both support pairs")
		_check(
			worst_slide < .001,
			"%s %s planted ankle skates %.4f m/frame" % [faction, role, worst_slide]
		)
		_check(
			worst_target < .003,
			"%s %s IK misses foot target by %.4f m" % [faction, role, worst_target]
		)
		_check(lift > walker.legs[0].length * .15, "Robot feet never clearly lift")
		_check(knees.size() >= 5, "Robot knees remain rigid")
		_drive(unit, Vector3.ZERO, 150)
		_check(walker.is_at_rest(), "Walker never re-plants its legs after stopping")
		for leg in walker.legs:
			_check(
				leg.ankle.global_position.distance_to(unit.global_transform * leg.home) < .003,
				"Walker foot does not return home"
			)
		_test_walker_turns_and_stops(unit)
		_test_walker_cadence(unit)
		unit.queue_free()


func _test_walker_turns_and_stops(unit):
	var visual = unit.get_node("BastionVisuals")
	var walker = visual._walker
	var worst_target = 0.0
	var worst_slide = 0.0
	for speed in [1.5, 0.0, -1.5]:
		for frame in range(120):
			var before = walker.legs.map(func(leg): return leg.ankle.global_position)
			var swinging = walker.legs.map(func(leg): return leg.swing)
			unit.rotate_y(STEP * .6)
			_drive(unit, -unit.basis.z * speed, 1)
			for index in range(4):
				var leg = walker.legs[index]
				worst_target = maxf(
					worst_target,
					leg.ankle.global_position.distance_to(unit.global_transform * leg.foot)
				)
				if not leg.swing and not swinging[index]:
					worst_slide = maxf(
						worst_slide, before[index].distance_to(leg.ankle.global_position)
					)
		_drive(unit, Vector3.ZERO, 150)
		_check(walker.is_at_rest(), "Walker cannot settle after turning/reversing")
	_check(worst_target < .003, "Turning walker exceeds joint reach: %.4f m" % worst_target)
	_check(worst_slide < .001, "Turning walker slides a planted ankle: %.4f m" % worst_slide)
	# Stop at several points in the stride, including while either pair is lifted.
	for frames in [3, 7, 11, 17, 23]:
		_drive(unit, -unit.basis.z * 1.5, frames)
		for frame in range(150):
			_drive(unit, Vector3.ZERO, 1)
			for leg in walker.legs:
				var ankle = unit.to_local(leg.ankle.global_position)
				_check(ankle.y >= leg.home.y - .003, "Stopping robot pushes a sole below ground")
		_check(walker.is_at_rest(), "Walker stop leaves a foot hanging")
	# Bracing and body suspension must bend joints without moving planted feet.
	for frame in range(60):
		walker.advance(STEP, 0.0, 1.0, unit.global_transform)
		var body = Transform3D(
			Basis.from_euler(Vector3(.035, 0, -.025)), Vector3(0, walker.heave, 0)
		)
		body = walker.support_body(body)
		unit.get_node("Geometry").transform = body
		walker.pose(body)
		for leg in walker.legs:
			_check(
				leg.ankle.global_position.distance_to(unit.global_transform * leg.home) < .003,
				"Bracing lifts a planted robot foot"
			)
	_drive(unit, Vector3.ZERO, 150)


func _test_walker_cadence(unit):
	var visual = unit.get_node("BastionVisuals")
	var walker = visual._walker
	for fps in [30, 60, 144, 240, 1000]:
		var accumulator = 0.0
		var interruptions = 0
		for frame in range(fps):
			accumulator += 1.0 / fps
			while accumulator >= 1.0 / 30.0 - .000001:
				unit.position.z -= 1.5 / 30.0
				accumulator -= 1.0 / 30.0
			visual._process(1.0 / fps)
			if frame > fps / 5 and not walker._moving:
				interruptions += 1
		_check(
			interruptions == 0, "Walker gait interrupted %d times at %d FPS" % [interruptions, fps]
		)
		for frame in range(fps / 2):
			unit.position.z -= .025 / fps
			visual._process(1.0 / fps)
		_check(walker._moving, "Walker creep gait frozen at %d FPS" % fps)
	_drive(unit, Vector3.ZERO, 150)
	_check(walker.is_at_rest(), "Walker cadence grace prevents stopping")


func _test_eased_heading():
	for role in ["Infantry", "Tank", "Helicopter"]:
		var unit = _spawn(role, 0, Vector3(32, 0, 20))
		var visual = unit.get_node("BastionVisuals")
		var geometry = unit.get_node("Geometry")
		_drive(unit, Vector3.ZERO, 10)
		unit.rotate_y(PI / 2)
		var authority = unit.transform
		_drive(unit, Vector3.ZERO, 1)
		var lag = absf(visual.chassis.yaw_lag)
		_check(lag > .3, role + ": heading snaps instantly")
		_check(lag <= visual.chassis._tuning[1] + .001, role + ": heading lag unbounded")
		var maximum = 0.0
		for frame in range(120):
			var before = geometry.global_rotation.y
			_drive(unit, Vector3.ZERO, 1)
			maximum = maxf(maximum, absf(angle_difference(before, geometry.global_rotation.y)))
		_check(maximum < .2, role + ": eased turn still jumps %.3f rad/frame" % maximum)
		_check(absf(visual.chassis.yaw_lag) < .01, role + ": heading never converges")
		_check(unit.transform == authority, role + ": heading easing altered unit root")
		unit.queue_free()


func _test_turret_traverse():
	var tank = _spawn("Tank", 0, Vector3(36, 0, 24))
	var target = _spawn("Tank", 1, Vector3(36, 0, 30))
	var visual = tank.get_node("BastionVisuals")
	_drive(tank, Vector3.ZERO, 5)
	tank.aim_target = target
	var turret = visual._turret
	var steps = []
	for frame in range(120):
		var before = turret.rotation.y
		_drive(tank, Vector3.ZERO, 1)
		steps.append(absf(angle_difference(before, turret.rotation.y)))
	_check(steps.max() <= visual._turret_rate * STEP + .001, "Turret traverse snaps to target")
	_check(steps[0] < steps[10], "Turret traverse does not ease in")
	var local = turret.get_parent().to_local(target.global_position + Vector3.UP * .45)
	local -= turret.position
	_check(
		absf(angle_difference(turret.rotation.y, atan2(-local.x, -local.z))) < .01,
		"Turret never settles on target"
	)
	# A shot still aligns the barrel with its target immediately.
	tank.aim_target = null
	_drive(tank, Vector3.ZERO, 30)
	tank.aim_target = target
	visual.fire_recoil()
	_check(
		absf(angle_difference(turret.rotation.y, atan2(-local.x, -local.z))) < .01,
		"Shot fired before the turret faced its target"
	)
	tank.aim_target = null
	tank.queue_free()
	target.queue_free()


func _test_aircraft_banking():
	var craft = _spawn("Helicopter", 0, Vector3(40, 0, 20))
	var visual = craft.get_node("BastionVisuals")
	var geometry = craft.get_node("Geometry")
	_drive(craft, Vector3.ZERO, 30)
	_drive(craft, Vector3.FORWARD * 4.0, 12)
	_check(geometry.rotation.x < -.05, "Aircraft does not dip its nose to accelerate")
	_drive(craft, Vector3.FORWARD * 4.0, 60)
	# Turning left (positive yaw) banks into the turn: left side down.
	var banked = 0.0
	for frame in range(30):
		_drive(craft, -craft.global_basis.z * 4.0, 1, 2.0)
		banked = maxf(banked, geometry.rotation.z)
	_check(banked > .08, "Aircraft does not bank into turns (%.3f)" % banked)
	_drive(craft, Vector3.ZERO, 30)
	_check(geometry.rotation.x > -.12, "Aircraft keeps cruise attitude while hovering")
	_check(not visual._settled, "Hovering aircraft froze")
	craft.queue_free()


func _test_shooting_stances():
	var target = _spawn("Tank", 1, Vector3(44, 0, 26))
	for role in ["Infantry", "SniperInfantry", "RocketInfantry"]:
		var unit = _spawn(role, 0, Vector3(44, 0, 32))
		var motion = unit.get_node("BastionVisuals")._infantry_motion
		_drive(unit, Vector3.ZERO, 10)
		var standing = motion.hips.position.y
		var low = motion.weapon.rotation.x
		unit.aim_target = target
		_drive(unit, Vector3.ZERO, 90)
		_check(motion.aim > .99, role + ": weapon never raised")
		_check(
			absf(motion.weapon.rotation.x) < absf(low) - .05, role + ": weapon stays at low ready"
		)
		var kneeling = motion.hips.position.y < standing - .1
		_check(
			kneeling == (role != "Infantry"),
			role + (": kneels unexpectedly" if role == "Infantry" else ": never kneels to fire")
		)
		for leg in motion.legs:
			_check(
				absf(leg[2].global_position.y - unit.global_position.y - .045) < .004,
				role + ": firing stance lifts a boot"
			)
		unit.aim_target = null
		_drive(unit, Vector3.ZERO, 120)
		_check(absf(motion.hips.position.y - standing) < .01, role + ": never stands back up")
		unit.queue_free()
	target.queue_free()


func _test_wheels():
	var expected = {
		"bastion": {},
		"helix": {"Worker": 6, "AdvancedTank": 6},
		"frontier": {"Worker": 6, "Tank": 6, "RepairRobot": 4, "CombatRobot": 4, "AdvancedTank": 8},
	}[_players[0].faction]
	for role in expected:
		var unit = _spawn(role, 0, Vector3(30, 0, 34))
		var drive = unit.get_node("BastionVisuals")._wheel_motion
		_check(drive != null and drive.wheels.size() == expected[role], role + ": wheels missing")
		if drive != null and not drive.wheels.is_empty():
			var before = drive.wheels.map(func(wheel): return wheel.pivot.basis)
			var radius = drive.wheels[0].radius
			_drive(unit, Vector3.FORWARD * radius * PI / 2 / (10 * STEP), 10)
			for index in drive.wheels.size():
				var wheel = drive.wheels[index]
				_check(
					absf(absf(wheel.angle) - PI / 2) < .02,
					role + ": wheel roll does not match travel"
				)
				_check(
					not wheel.pivot.basis.is_equal_approx(before[index]), role + ": wheel static"
				)
		unit.queue_free()
	if _players[0].faction == "bastion":
		var truck = _spawn("SupplyTruck", 0, Vector3(30, 0, 34))
		var drive = truck.get_node("BastionVisuals")._wheel_motion
		_check(drive != null and drive.wheels.size() == 6, "Supply truck wheels do not roll")
		truck.queue_free()


func _test_hidden_and_settled():
	var unit = _spawn("Infantry", 0, Vector3(34, 0, 36))
	var visual = unit.get_node("BastionVisuals")
	var geometry = unit.get_node("Geometry")
	_drive(unit, Vector3.FORWARD * 3.0, 20)
	unit.hide()
	var poses = _part_poses(unit)
	var clock = visual._infantry_motion.phase
	_drive(unit, Vector3.FORWARD * 3.0, 30)
	_check(_part_poses(unit) == poses, "Hidden unit kept posing its rig")
	_check(visual._infantry_motion.phase == clock, "Hidden unit advanced its gait")
	unit.show()
	_drive(unit, Vector3.ZERO, 120)
	_check(visual._settled, "Stopped infantry never settles")
	_check(geometry.transform.is_equal_approx(visual._geometry_rest), "Settled pose drifted")
	# Off-screen culling (rendered runs only): a unit outside the camera frustum
	# skips posing, and resumes as soon as the camera looks at it.
	var script = visual.get_script()
	script._headless = false
	var camera = Camera3D.new()
	_game.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.global_position = unit.global_position + Vector3(400, 30, 0)
	camera.look_at(unit.global_position + Vector3(400, 0, -1))
	camera.make_current()
	# The shared frustum refreshes once per physics tick.
	await physics_frame
	_drive(unit, Vector3.FORWARD * 3.0, 20)
	poses = _part_poses(unit)
	_drive(unit, Vector3.FORWARD * 3.0, 20)
	_check(_part_poses(unit) == poses, "Off-screen unit kept posing its rig")
	camera.global_position = unit.global_position + Vector3(0, 12, 12)
	camera.look_at(unit.global_position)
	await physics_frame
	_drive(unit, Vector3.FORWARD * 3.0, 4)
	_check(_part_poses(unit) != poses, "On-screen unit never resumed animating")
	script._headless = true
	camera.queue_free()
	unit.queue_free()
	for role in ["Tank", "CombatRobot", "Worker", "RepairRobot", "AdvancedTank"]:
		var vehicle = _spawn(role, 0, Vector3(34, 0, 36))
		var vehicle_visual = vehicle.get_node("BastionVisuals")
		_drive(vehicle, Vector3.FORWARD * 2.0, 40)
		_drive(vehicle, Vector3.ZERO, 180)
		# Helix skimmers hover, so they keep floating like aircraft.
		var hovering = vehicle_visual.chassis.kind == vehicle_visual.chassis.Kind.HOVER
		_check(
			vehicle_visual._settled != hovering,
			"%s %s settles incorrectly after stopping" % [_players[0].faction, role]
		)
		vehicle.queue_free()


func _part_poses(unit):
	var poses = []
	for node in unit.get_node("Geometry").find_children("*", "Node3D", true, false):
		if not node is MeshInstance3D:
			poses.append(node.transform)
	poses.append(unit.get_node("Geometry").transform)
	return poses


func _test_gameplay_invariance():
	# Run a real move-and-shoot exchange while stepping every unit's animation by
	# hand, and prove each animation step leaves all gameplay state untouched.
	var target = _spawn("Tank", 1, Vector3(52, 0, 14), false)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	target.hp_max = 100000
	target.hp = 100000
	var units = []
	for index in range(MOBILE_ROLES.size()):
		var unit = _spawn(
			MOBILE_ROLES[index], 0, Vector3(38 + index % 4 * 2.5, 0, 8 + index / 4 * 3)
		)
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.get_node("BastionVisuals").set_process(false)
		units.append(unit)
	await _frames(20)
	for unit in units:
		unit.action = _moving.new(unit.global_position + Vector3(3, 0, 1))
	for frame in range(240):
		if frame == 120:
			for unit in units:
				if (
					unit.attack_damage != null
					and unit.attack_damage > 0
					and _game.battlefield.can_fire(unit, target)
				):
					unit.action = _attacking.new(target)
		await physics_frame
		for unit in units:
			if not is_instance_valid(unit):
				continue
			var state = _gameplay_state(unit)
			unit.get_node("BastionVisuals")._process(STEP)
			_check(_gameplay_state(unit) == state, unit.type + ": animation changed gameplay state")
	_check(target.hp < 100000, "Invariance scenario never hit its target")
	for unit in units:
		unit.queue_free()
	target.queue_free()
	await _frames(3)


func _gameplay_state(unit):
	var movement = unit.get_node("Movement")
	return [
		unit.global_transform,
		unit.get_node("CollisionShape3D").global_transform,
		unit.hp,
		unit.action,
		unit.aim_target,
		unit.get_meta("next_attack_availability_time", -1),
		movement.velocity,
		movement.target_position,
		movement._has_destination,
		unit.get_node("Selection").global_transform,
	]


func _test_squad_desync():
	var squad = []
	for index in range(8):
		squad.append(_spawn("Infantry", 0, Vector3(36 + index % 4, 0, 40 + index / 4), false))
	await _frames(20)
	for unit in squad:
		unit.action = _moving.new(unit.global_position + Vector3(6, 0, 0))
	await _frames(45)
	var phases = {}
	var strides = {}
	for unit in squad:
		var motion = unit.get_node("BastionVisuals")._infantry_motion
		phases[snappedf(motion.phase, .15)] = true
		strides[snappedf(motion.stride_length(), .005)] = true
	_check(phases.size() >= 4, "Squad marches in lockstep (%d phases)" % phases.size())
	_check(strides.size() >= 4, "Squad shares one stride length")
	for unit in squad:
		unit.queue_free()
	await _frames(3)


func _test_destruction():
	var effects = _game.combat_effects
	var soldier = _spawn("Infantry", 0, Vector3(40, 0, 44), false)
	var craft = _spawn("Drone", 0, Vector3(44, 0, 44), false)
	await _frames(20)
	soldier.hp_max = 100000
	soldier.hp = 100000
	var source = _spawn("Tank", 1, Vector3(40, 0, 50))
	# Headless matches have no impact effects; drive the visual hit directly.
	soldier.get_node("BastionVisuals").hit_reaction(source.global_position)
	var recipe = soldier.get_node("BastionVisuals").death_motion()
	_check(recipe.infantry and recipe.duration > .8, "Infantry death lacks a collapse")
	# The hit came from +Z, so the soldier topples away from it (toward -Z).
	var fall = Vector3(
		-sin(atan2(recipe.tilt.z, recipe.tilt.x)), 0, cos(atan2(recipe.tilt.z, recipe.tilt.x))
	)
	_check(fall.z < 0.0, "Infantry falls toward the shooter")
	# Headless matches skip wreck visuals; build them directly as destruction() does.
	effects._wreck(soldier, true)
	effects._wreck(craft, false)
	var infantry_wreck = effects._wrecks[-2]
	var air_wreck = effects._wrecks[-1]
	# Secondary blasts need the rendered aftermath layer, absent in headless runs.
	air_wreck.secondary = true
	soldier.hp = 0
	craft.hp = 0
	await _frames(2)
	_check(not is_instance_valid(soldier) and not is_instance_valid(craft), "Dead units linger")
	_check(absf(air_wreck.motion.spin) > 2.0, "Aircraft wreck falls without spinning")
	var hips = infantry_wreck.node.get_node("InfantryRig/Hips")
	var standing = InfantryMotionScript.HIP_HEIGHT
	await _frames(int(infantry_wreck.motion.duration * 60) + 10)
	_check(hips.position.y < standing - .1, "Infantry wreck never buckles at the knees")
	_check(infantry_wreck.has("posed"), "Infantry wreck keeps re-posing after it landed")
	var tilted = infantry_wreck.node.rotation - infantry_wreck.rotation
	_check(Vector2(tilted.x, tilted.z).length() > 1.0, "Infantry wreck never reaches the ground")
	# Wrecks are inert copies: no animation script or processing survives.
	for node in [infantry_wreck.node, air_wreck.node]:
		_check(node.get_script() == null, "Wreck kept an animation script")
		_check(
			node.find_children("*", "Node", true, false).all(
				func(child): return child.get_script() == null
			),
			"Wreck kept animated children"
		)
	source.queue_free()


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
