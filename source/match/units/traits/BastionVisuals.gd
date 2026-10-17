extends Node

# Visual-only animation for every unit and structure. Poses Geometry and its
# articulated parts from the unit's authoritative state; the unit root, its
# collision, orders and weapon timing are never modified here.

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const MotionProfile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
const Chassis = preload("res://source/match/units/traits/ChassisMotion.gd")
const WalkerGait = preload("res://source/match/units/traits/WalkerGait.gd")
const ROTOR_SPEED = 25.0
const WORK_PERIOD = .9
const FIDGETS = 4

static var _frustum_frame = -1
static var _frustum = []
static var _headless = DisplayServer.get_name() == "headless"

var motion
var chassis
var _wheel_motion = null
var _infantry_motion = null
var _walker = null
var _turret = null
var _barrel = null
var _muzzle = null
var _legs = []
var _rotors = []
var _rotor_angles = []
var _tools = []
var _stabilizers = []
var _rests = {}
var _previous_position = Vector3.ZERO
var _clock = 0.0
var _quiet_time = 0.0
var _idle_blend = 0.0
var _gesture = 0.0
var _gesture_strength = 1.0
var _gesture_value = 0.0
var _fidget = 0
var _recoil = 0.0
var _hit_kick = 0.0
var _hit_axis = Vector3.ZERO
var _hit_push = Vector3.ZERO
var _hit_clock = -INF
var _barrel_rest = Vector3.ZERO
var _geometry_rest = Transform3D.IDENTITY
var _dust_elapsed = 0.0
var _damage_elapsed = 0.0
var _airborne = false
var _mobile = false
var _heavy = false
var _movement = null
var _settled = false
var _aiming = false
var _turret_yaw = 0.0
var _turret_velocity = 0.0
var _turret_rate = 3.0
var _barrel_pitch = 0.0
var _rotor_speed = ROTOR_SPEED
var _tools_posed = false
var _work = 0.0
var _work_clock = 0.0
var _deploys = false
var _deploy = 1.0
var _cull_radius = 3.0
var _rest_is_identity = true
var _barrel_scale = 1.0
var _constructible = false
var _action_reports_idle = false
var _repairs = false
var _sparkling = null
var _culled = false
# Suspension pitch lives in the chassis spring; these aliases keep the impulse API.
var _suspension_pitch:
	get:
		return chassis.pitch
	set(value):
		chassis.pitch = value
var _suspension_velocity:
	get:
		return chassis.pitch_velocity
	set(value):
		chassis.pitch_velocity = value
@onready var _geometry = get_parent().get_node("Geometry")
@onready var _unit = get_parent()
@onready var _projectile_origin = _unit.find_child("ProjectileOrigin", true, false)


func _init():
	chassis = Chassis.new()


func _ready():
	# Unit roots interpolate their physics motion; these local poses are
	# already evaluated at display rate and must not be interpolated twice.
	_geometry.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not _unit.has_meta("visual_seed"):
		_unit.set_meta("visual_seed", _unit.find_parent("Match").allocate_visual_seed())
	motion = MotionProfile.new(_unit.get_meta("visual_seed"))
	_clock = motion.phase
	_gesture = motion.idle_period
	_turret = _unit.find_child("*TurretPivot", true, false)
	_barrel = _unit.find_child("*BarrelPivot", true, false)
	_muzzle = _unit.find_child("*Muzzle", true, false)
	_legs = _unit.find_children("*LegLeft*", "Node3D", true, false).filter(_is_pivot)
	_legs += _unit.find_children("*LegRight*", "Node3D", true, false).filter(_is_pivot)
	_rotors = _unit.find_children("*RotorLeft", "Node3D", true, false)
	_rotors += _unit.find_children("*RotorRight", "Node3D", true, false)
	_rotors += _unit.find_children("*Rotor?", "Node3D", true, false)
	for pattern in ["*ToolArm*", "*ServiceArm*", "*RepairArm*", "*SensorPivot"]:
		_tools += _unit.find_children(pattern, "Node3D", true, false).filter(_is_pivot)
	_stabilizers = _unit.find_children("*Stabilizer_*", "Node3D", true, false).filter(_is_pivot)
	for part in _legs + _rotors + _tools + _stabilizers + [_turret, _barrel]:
		if part != null:
			_rests[part] = part.rotation
	for rotor in _rotors:
		_rests[rotor] = rotor.basis
		_rotor_angles.append(motion.phase)
	if _turret != null:
		_turret_yaw = _rests[_turret].y
	if _barrel != null:
		_barrel_pitch = _rests[_barrel].x
		_barrel_rest = _barrel.position
		_barrel_scale = maxf(0.05, _barrel.global_basis.get_scale().z)
	_previous_position = _unit.global_position
	_geometry_rest = _geometry.transform
	_rest_is_identity = _geometry_rest.basis.is_equal_approx(Basis.IDENTITY)
	_movement = _unit.get_node_or_null("Movement")
	_mobile = _movement != null
	_airborne = _unit.movement_domain == Constants.Match.Navigation.Domain.AIR
	_heavy = _unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	_turret_rate = 2.2 if _heavy else 3.4
	_constructible = _unit.has_method("is_under_construction")
	_deploys = "deployment_left" in _unit
	_repairs = _unit.type == "RepairRobot"
	if _unit.type == "Worker":
		_sparkling = _unit.get_node_or_null("Sparkling")
	var infantry = InfantryRoster.is_infantry(_unit.type)
	if _mobile and not _airborne and not infantry:
		_wheel_motion = load("res://source/match/units/traits/WheelMotion.gd").new()
		_wheel_motion.setup(_unit)
		if _wheel_motion.wheels.is_empty():
			_wheel_motion = null
	if infantry:
		_infantry_motion = load("res://source/match/units/traits/InfantryMotion.gd").new()
		_infantry_motion.setup(_unit, motion.phase, _unit.type)
		_infantry_motion.stride_scale *= motion.stride_scale
		_infantry_motion.lead_foot = motion.lead_foot
	elif not _legs.is_empty() and _mobile:
		_walker = WalkerGait.new()
		_walker.setup(_unit, _legs, motion.phase)
	chassis.configure(_motion_kind(infantry), motion, _speed_limit(), _body_length())
	chassis.reset(_unit.global_transform)
	# Generous bound: tall walkers, rotor discs and hover drift stay inside it.
	_cull_radius = _body_length() + 2.0
	_deploy = _deploy_target()
	_unit.action_changed.connect(_on_order)
	_on_order(_unit.action)
	_sync_muzzle()


static func _is_pivot(node):
	return not node is MeshInstance3D


func _motion_kind(infantry):
	if infantry:
		return Chassis.Kind.INFANTRY
	if _airborne:
		return Chassis.Kind.AIR
	if _walker != null:
		return Chassis.Kind.WALKER
	if _unit.type == "Tank" and _unit.player != null and _unit.player.faction == "helix":
		return Chassis.Kind.HOVER
	if _wheel_motion != null:
		return Chassis.Kind.WHEELED
	return Chassis.Kind.TRACKED


func _speed_limit():
	return _movement.speed if _movement != null else 4.0


func _body_length():
	var reach = _unit.get("radius")
	return reach * 2.0 if reach != null else 2.0


func _on_screen(center):
	# Off-screen units keep their timers but skip posing. One frustum per rendered
	# frame is shared by every unit; headless runs have nothing to cull.
	if _headless:
		return true
	var frame = Engine.get_process_frames()
	if frame != _frustum_frame:
		_frustum_frame = frame
		var camera = get_viewport().get_camera_3d()
		_frustum = camera.get_frustum() if camera != null else []
	for plane in _frustum:
		if plane.distance_to(center) > _cull_radius:
			return false
	return true


func _on_order(action):
	_quiet_time = 0.0
	_settled = false
	_action_reports_idle = action != null and action.has_method("is_idle")


func fire_recoil():
	# Remove any idle scan before the weapon samples its actual muzzle transform,
	# and bring a lagging body onto the firing line.
	_quiet_time = 0.0
	_idle_blend = 0.0
	_settled = false
	var before = chassis.yaw_lag
	chassis.clamp_lag(.2)
	if _mobile:
		_geometry.rotate_y(chassis.yaw_lag - before)
	if _infantry_motion != null:
		_infantry_motion.raise_for_shot()
	_aim(1.0)
	_sync_muzzle()
	motion.next_shot()
	_recoil = 1.0
	if _heavy:
		_suspension_velocity = -0.36
	elif _mobile and _infantry_motion == null:
		_suspension_velocity = -0.16


func hit_reaction(source_position = Vector3.INF):
	_quiet_time = 0.0
	_hit_kick = 1.0
	_settled = false
	var direction = Vector3.RIGHT.rotated(Vector3.UP, motion.phase)
	if source_position.is_finite():
		direction = (
			_unit.global_basis.inverse() * source_position.direction_to(_unit.global_position)
		)
	direction = (direction * Vector3(1, 0, 1)).normalized()
	if direction.is_zero_approx():
		direction = Vector3.BACK
	_hit_axis = Vector3(direction.z, 0, -direction.x) * motion.random.randf_range(0.035, 0.065)
	_hit_push = direction
	_hit_clock = _clock
	if _mobile and _infantry_motion == null:
		chassis.impulse(direction, motion.random.randf_range(.45, .7) * (.6 if _heavy else 1.0))


func death_motion():
	var away = _hit_push if _clock - _hit_clock < 1.5 else Vector3.ZERO
	return motion.death_motion(
		InfantryRoster.is_infantry(_unit.type), _airborne, _mobile, away, _unit.global_basis
	)


# Pose once per rendered frame. Simulation can catch up with several physics
# steps without repeatedly dirtying the same model hierarchy. fire_recoil()
# synchronizes the muzzle immediately when gameplay actually fires a shot.
func _process(delta: float):
	var root: Transform3D = (
		_unit.get_global_transform_interpolated()
		if get_tree().physics_interpolation and _unit.can_process()
		else _unit.global_transform
	)
	_damage_elapsed += delta
	if _damage_elapsed > 0.8:
		_damage_elapsed = 0.0
		if _unit.hp != null and _unit.hp_max != null and _unit.hp <= _unit.hp_max * 0.3:
			_unit._match.combat_effects.damage_smoke(_unit)
	var travel: Vector3 = root.origin - _previous_position
	var distance := travel.length()
	_previous_position = root.origin
	var moving = distance > maxf(.000001, delta * .02)
	if moving:
		_settled = false
	_recoil = maxf(0.0, _recoil - delta / motion.recoil_duration)
	_hit_kick = maxf(0.0, _hit_kick - delta * 6.0)
	_aiming = is_instance_valid(_unit.aim_target)
	if _aiming:
		_settled = false

	# Idle timing continues while hidden or settled, so gestures resume in step.
	_update_idle(delta, moving)
	_update_work(delta, moving)
	if not _unit.is_visible_in_tree() or not _on_screen(root.origin):
		# Hidden and off-screen units skip all body dynamics; restart them cleanly.
		_culled = true
		return
	if _culled:
		_culled = false
		chassis.reset(root)
	elif _settled and chassis.is_settled() and chassis._previous == root:
		chassis.clock += delta
	else:
		chassis.advance(delta, root)
	# Wheels also roll through pivot turns, which have no root translation.
	if _wheel_motion != null:
		_wheel_motion.advance(delta)

	if (
		_settled
		and not moving
		and not _aiming
		and _idle_blend <= 0.001
		and _work <= 0.0
		and _rotors.is_empty()
		and chassis.is_settled()
	):
		return

	_clock += delta * motion.cadence
	_gesture_value = _idle_gesture()
	_update_parts(delta)
	_apply_geometry(delta, (travel * Vector3(1, 0, 1)).length())
	if moving and not _airborne and _mobile:
		_dust_elapsed += delta
		if _dust_elapsed > 0.22 * motion.cadence:
			_dust_elapsed = 0.0
			_unit._match.combat_effects.movement_dust(_unit)
	_aim(delta)
	# The projectile origin only matters while a weapon is engaged or recoiling.
	if _aiming or _recoil > 0.0:
		_sync_muzzle()

	if (
		not moving
		and not _aiming
		and _recoil <= 0.0001
		and _hit_kick <= 0.0001
		and _idle_blend <= 0.001
		and _work <= 0.0
		and _rotors.is_empty()
		and chassis.is_settled()
		and _pose_at_rest()
	):
		_settled = true
		chassis.settle()
		_geometry.transform = _geometry_rest
		if _barrel != null:
			_barrel.position = _barrel_rest


func _apply_geometry(delta, ground_distance):
	var kick = _recoil * _recoil * motion.recoil_strength
	if _barrel != null and (kick > 0.0 or _barrel.position != _barrel_rest):
		_barrel.position = (
			_barrel_rest + Vector3.BACK * kick * (0.28 if _heavy else 0.12) / _barrel_scale
		)
	# Buildings keep their foundation fixed; their articulated parts still animate.
	if not _mobile:
		return
	if _infantry_motion != null:
		_pose_geometry(Vector3(0, chassis.yaw_lag, 0), Vector3.ZERO)
		var flinch = sin(_hit_kick * PI) * _hit_kick
		_infantry_motion.lean = Vector2(chassis.pitch, -chassis.roll)
		_infantry_motion.turn_lead = -chassis.yaw_lag * .7
		_infantry_motion.flinch = (
			Vector3(_hit_push.z * .22, -_hit_push.x * .12, -_hit_push.x * .18) * flinch
		)
		_infantry_motion.fidget = _fidget
		_infantry_motion.advance(
			delta, ground_distance, _clock, _gesture_value, kick, 1.0 if _aiming else 0.0
		)
		return
	var gesture = _gesture_value
	var lift = Vector3.ZERO
	var tilt = Vector3.ZERO
	if _walker != null:
		_walker.advance(delta, ground_distance, 1.0 if _unit.weapon_charge_progress >= 0 else 0.0)
		lift.y += _walker.heave
		# Hydraulic idle and an occasional servo weight shift while standing guard.
		lift.y += (sin(_clock * 1.7) + sin(_clock * 2.9) * .5) * .004 * _idle_blend
		tilt.z += gesture * .02
		lift.y -= absf(gesture) * .012
	else:
		# Crew shifting inside a parked vehicle.
		tilt.z += gesture * .006
	if _work > 0.0:
		# Tool-less rigs rock into the work face with their whole hull.
		var strike = _strike(_work_clock / WORK_PERIOD)
		tilt.x -= strike * (.015 if not _tools.is_empty() else .055) * _work
		tilt.z += sin(_work_clock * TAU / (WORK_PERIOD * 2.0)) * .012 * _work
		lift.y -= strike * .015 * _work
	chassis.idle = _idle_blend
	var rotation = chassis.offset_rotation(kick * (0.04 if _heavy else 0.06)) + tilt
	rotation.z += kick * motion.recoil_roll
	_pose_geometry(rotation, chassis.offset_position() + lift)


func _pose_geometry(rotation: Vector3, offset: Vector3):
	# One transform write per frame: each write re-dirties the whole model subtree.
	if _rest_is_identity:
		_geometry.transform = Transform3D(
			Basis.from_euler(rotation), _geometry_rest.origin + offset
		)
	else:
		_geometry.transform = _geometry_rest
		_geometry.rotation += rotation
		_geometry.position += offset


func _pose_at_rest():
	# Settling stops part easing, so every eased part must already be at rest.
	var turret_moving = (
		_turret != null
		and (
			absf(angle_difference(_turret_yaw, _rests[_turret].y)) > 0.001
			or absf(_turret_velocity) > 0.001
		)
	)
	var barrel_moving = (
		_barrel != null and absf(angle_difference(_barrel_pitch, _rests[_barrel].x)) > 0.001
	)
	var deploying = not _stabilizers.is_empty() and absf(_deploy - _deploy_target()) > 0.001
	return (
		not _tools_posed
		and not turret_moving
		and not barrel_moving
		and not deploying
		and (_walker == null or _walker.is_at_rest())
		and (_infantry_motion == null or _infantry_motion.is_at_rest())
	)


func _update_idle(delta, moving):
	var busy = moving or _aiming or _recoil > 0 or _hit_kick > 0
	busy = busy or (_movement != null and _movement._has_destination)
	var action = _unit.action
	if action != null:
		busy = busy or not _action_reports_idle or not action.is_idle()
	if _constructible:
		busy = busy or _unit.is_under_construction()
	_quiet_time = 0.0 if busy else _quiet_time + delta
	var resting = _quiet_time >= motion.idle_delay
	_idle_blend = move_toward(_idle_blend, 1.0 if resting else 0.0, delta * 3.0)
	if resting:
		_gesture += delta
		if _gesture >= motion.idle_period:
			_gesture = 0.0
			_gesture_strength = motion.random.randf_range(-1.0, 1.0)
			motion.idle_period = motion.random.randf_range(6.0, 10.0)
			if _infantry_motion != null:
				_fidget = motion.next_fidget(FIDGETS)


func _update_work(delta, moving):
	# Harvesting, building and field repairs get a purposeful tool rhythm.
	var working = not moving and _is_working()
	_work = move_toward(_work, 1.0 if working else 0.0, delta * 3.0)
	if _work > 0.0:
		_work_clock += delta
		_settled = false
	else:
		_work_clock = 0.0


func _is_working():
	if _sparkling != null:
		return _sparkling._animation != null
	if _repairs and _unit.action != null:
		return (
			_unit.action.has_method("repair_target")
			and _movement != null
			and not _movement._has_destination
		)
	return false


static func _strike(cycle):
	# Quick downward stroke, slower recovery.
	var progress = fposmod(cycle, 1.0)
	if progress < .25:
		return smoothstep(0.0, .25, progress)
	return 1.0 - smoothstep(.25, 1.0, progress)


func _idle_gesture():
	# A short smooth weight shift / scan followed by several seconds of rest.
	if _idle_blend <= 0.0:
		return 0.0
	var wave = sin(clampf(_gesture / 3.2, 0.0, 1.0) * PI)
	return wave * wave * _gesture_strength * _idle_blend


func _update_parts(delta):
	var gesture = _gesture_value
	if not _rotors.is_empty():
		# Rotors spool up under load: speed and acceleration.
		var strain = clampf(
			absf(chassis.forward_speed) / chassis.max_speed * .5 + chassis.accel.length() * .04,
			0.0,
			1.0
		)
		_rotor_speed = lerpf(_rotor_speed, ROTOR_SPEED * (.85 + .45 * strain), delta * 2.5)
		for index in range(_rotors.size()):
			_rotor_angles[index] = wrapf(
				_rotor_angles[index] + delta * _rotor_speed * motion.cadence, -PI, PI
			)
			_rotors[index].basis = _rests[_rotors[index]] * Basis(Vector3.UP, _rotor_angles[index])
	if not _tools.is_empty() and (_tools_posed or gesture != 0.0 or _work > 0.0):
		_tools_posed = gesture != 0.0 or _work > 0.0
		for index in range(_tools.size()):
			var tool = _tools[index]
			var side = -1 if index % 2 == 0 else 1
			var target = _rests[tool] + Vector3(0, 0, gesture * 0.10 * side)
			if _work > 0.0:
				# Alternating tool strokes that also sweep across the work face.
				var strike = _strike(_work_clock / WORK_PERIOD + index * .5)
				var sweep = sin(_work_clock * TAU / (WORK_PERIOD * 3.0) + index * PI)
				target += Vector3(-strike * .7, sweep * .3, side * strike * .15) * _work
			tool.rotation = target
	if not _stabilizers.is_empty():
		var deploy = move_toward(_deploy, _deploy_target(), delta * 1.6)
		if deploy != _deploy:
			_deploy = deploy
			for stabilizer in _stabilizers:
				var side = signf(stabilizer.position.x)
				stabilizer.rotation = (
					_rests[stabilizer] + Vector3(0, 0, side * .3 * (1.0 - _deploy))
				)
	if not _aiming:
		if _turret != null:
			_traverse(_rests[_turret].y + gesture * 0.22, delta, 5.0, _turret_rate * .6)
		if _barrel != null:
			var pitch = lerp_angle(
				_barrel_pitch, _rests[_barrel].x + absf(gesture) * 0.055, minf(1.0, delta * 3.0)
			)
			if absf(angle_difference(pitch, _rests[_barrel].x)) <= 0.0005:
				pitch = _rests[_barrel].x
			_set_barrel_pitch(pitch)


func _deploy_target():
	# Helix artillery lowers its stabilizers over the gameplay deployment timer.
	if not _deploys:
		return 1.0
	return 1.0 - clampf(_unit.deployment_left / _unit.DEPLOY_SECONDS, 0.0, 1.0)


func _traverse(target, delta, omega, max_rate):
	# Critically damped traverse with rate and acceleration limits: the turret
	# spools up, slews and settles onto the target instead of snapping.
	var error = angle_difference(_turret_yaw, target)
	if absf(error) < .0005 and absf(_turret_velocity) < .002:
		_turret_velocity = 0.0
		_set_turret_yaw(target)
		return
	var desired = (omega * omega * error - 2.0 * omega * _turret_velocity) * delta
	var spool = max_rate * 4.0 * delta
	_turret_velocity = clampf(
		_turret_velocity + clampf(desired, -spool, spool), -max_rate, max_rate
	)
	_set_turret_yaw(_turret_yaw + _turret_velocity * delta)


func _set_turret_yaw(yaw):
	# Only this node animates the turret, so the cached yaw is authoritative.
	if yaw == _turret_yaw:
		return
	_turret_yaw = yaw
	var rest = _rests[_turret]
	_turret.rotation = Vector3(rest.x, yaw, rest.z)


func _set_barrel_pitch(pitch):
	if pitch == _barrel_pitch:
		return
	_barrel_pitch = pitch
	var rest = _rests[_barrel]
	_barrel.rotation = Vector3(pitch, rest.y, rest.z)


func _aim(delta):
	if not is_instance_valid(_unit.aim_target) or _turret == null:
		return
	var target_position = _unit.aim_target.global_position + Vector3.UP * 0.45
	var target_local = _turret.get_parent().to_local(target_position) - _turret.position
	var bearing = atan2(-target_local.x, -target_local.z)
	if delta >= 1.0:
		_turret_velocity = 0.0
		_set_turret_yaw(bearing)
	else:
		_traverse(bearing, delta, 11.0, _turret_rate)
	if _barrel != null:
		var direction = _barrel.get_parent().to_local(target_position) - _barrel.position
		var elevation = clamp(
			atan2(direction.y, Vector2(direction.x, direction.z).length()), -0.15, 0.65
		)
		_set_barrel_pitch(
			(
				elevation
				if delta >= 1.0
				else lerp_angle(_barrel_pitch, elevation, minf(1.0, delta * 9.0))
			)
		)


func _sync_muzzle():
	if _muzzle != null and _projectile_origin != null:
		_projectile_origin.global_transform = _muzzle.global_transform.orthonormalized()
