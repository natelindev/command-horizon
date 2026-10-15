extends Node

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

const MotionProfile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
var motion
var _wheel_motion = null
var _infantry_motion = null
var _turret = null
var _barrel = null
var _muzzle = null
var _legs = []
var _rotors = []
var _tools = []
var _rests = {}
var _previous_position = Vector3.ZERO
var _phase = 0.0
var _clock = 0.0
var _quiet_time = 0.0
var _idle_blend = 0.0
var _gesture = 0.0
var _gesture_strength = 1.0
var _recoil = 0.0
var _hit_kick = 0.0
var _hit_axis = Vector3.ZERO
var _barrel_rest = Vector3.ZERO
var _geometry_rest = Transform3D.IDENTITY
var _dust_elapsed = 0.0
var _damage_elapsed = 0.0
var _airborne = false
var _mobile = false
var _heavy = false
var _suspension_pitch = 0.0
var _suspension_velocity = 0.0
var _movement = null
var _leg_data = []
var _muzzle_dirty = true
var _settled = false
@onready var _geometry = get_parent().get_node("Geometry")
@onready var _unit = get_parent()
@onready var _projectile_origin = _unit.find_child("ProjectileOrigin", true, false)


func _ready():
	var match_node = _unit.find_parent("Match")
	if not _unit.has_meta("visual_seed"):
		_unit.set_meta("visual_seed", match_node.allocate_visual_seed())
	motion = MotionProfile.new(_unit.get_meta("visual_seed"))
	_phase = motion.phase
	_clock = motion.phase
	_gesture = motion.idle_period
	_turret = _unit.find_child("*TurretPivot", true, false)
	_barrel = _unit.find_child("*BarrelPivot", true, false)
	_muzzle = _unit.find_child("*Muzzle", true, false)
	_legs = _unit.find_children("*LegLeft*", "Node3D", true, false)
	_legs += _unit.find_children("*LegRight*", "Node3D", true, false)
	_rotors = _unit.find_children("*RotorLeft", "Node3D", true, false)
	_rotors += _unit.find_children("*RotorRight", "Node3D", true, false)
	_rotors += _unit.find_children("*Rotor?", "Node3D", true, false)
	for pattern in ["*ToolArm*", "*ServiceArm*", "*RepairArm*", "*SensorPivot"]:
		_tools += _unit.find_children(pattern, "Node3D", true, false)
	for part in _legs + _rotors + _tools + [_turret, _barrel]:
		if part != null:
			_rests[part] = part.rotation
	for leg in _legs:
		var sign_value = -1.0 if "Left" in leg.name else 1.0
		if "Rear" in leg.name:
			sign_value *= -1.0
		_leg_data.append({"node": leg, "rest_x": _rests[leg].x, "sign": sign_value})
	for rotor in _rotors:
		rotor.rotation.y += motion.phase
	_previous_position = _unit.global_position
	_geometry_rest = _geometry.transform
	if _barrel != null:
		_barrel_rest = _barrel.position
	_movement = _unit.get_node_or_null("Movement")
	_mobile = _movement != null
	_airborne = _unit.movement_domain == Constants.Match.Navigation.Domain.AIR
	_heavy = _unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	if _unit.player.faction == "frontier" and _mobile and not _airborne:
		_wheel_motion = load("res://source/match/units/traits/WheelMotion.gd").new()
		_wheel_motion.setup(_unit)
	if InfantryRoster.is_infantry(_unit.type):
		_infantry_motion = load("res://source/match/units/traits/InfantryMotion.gd").new()
		_infantry_motion.setup(_unit, motion.phase)
	_unit.action_changed.connect(_on_order)
	_sync_muzzle()


func _on_order(_action):
	_quiet_time = 0.0
	_settled = false


func fire_recoil():
	# Remove any idle scan before the weapon samples its actual muzzle transform.
	_quiet_time = 0.0
	_idle_blend = 0.0
	_settled = false
	_muzzle_dirty = true
	_geometry.transform = _geometry_rest
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
	_hit_axis = Vector3(direction.z, 0, -direction.x) * motion.random.randf_range(0.035, 0.065)


func death_motion():
	return motion.death_motion(InfantryRoster.is_infantry(_unit.type), _airborne, _mobile)


func _physics_process(delta):
	_damage_elapsed += delta
	if _damage_elapsed > 0.8:
		_damage_elapsed = 0.0
		if _unit.hp != null and _unit.hp_max != null and _unit.hp <= _unit.hp_max * 0.3:
			_unit._match.combat_effects.damage_smoke(_unit)
	var distance = _unit.global_position.distance_to(_previous_position)
	_previous_position = _unit.global_position
	var moving = distance > 0.002
	if moving:
		_settled = false
	if _wheel_motion != null and moving:
		_wheel_motion.advance(delta)
	_recoil = maxf(0.0, _recoil - delta / motion.recoil_duration)
	_hit_kick = maxf(0.0, _hit_kick - delta * 6.0)
	if absf(_suspension_pitch) > 0.0001 or absf(_suspension_velocity) > 0.0001:
		_settled = false
		var spring_force = -32.0 * _suspension_pitch - 8.0 * _suspension_velocity
		_suspension_velocity += spring_force * delta
		_suspension_pitch += _suspension_velocity * delta
	else:
		_suspension_pitch = 0.0
		_suspension_velocity = 0.0

	var aiming = is_instance_valid(_unit.aim_target)
	if aiming:
		_settled = false

	if not _unit.is_visible_in_tree():
		return

	if _settled and not moving and not aiming and _rotors.is_empty():
		return

	_clock += delta * motion.cadence
	_phase += distance * 9.0 * motion.cadence
	_update_idle(delta, moving)
	_update_parts(delta, moving)

	var kick = _recoil * _recoil * motion.recoil_strength
	if _barrel != null:
		var model_scale = maxf(0.05, _barrel.global_basis.get_scale().z)
		_barrel.position = (
			_barrel_rest + Vector3.BACK * kick * (0.28 if _heavy else 0.12) / model_scale
		)
	_geometry.transform = _geometry_rest
	# Buildings keep their foundation fixed; their articulated parts still animate.
	if _mobile:
		_geometry.rotation += _hit_axis * sin(_hit_kick * PI)
		_geometry.rotation.x += (
			kick * (0.0 if _infantry_motion != null else (0.04 if _heavy else 0.06))
			+ (_suspension_pitch if _infantry_motion == null else 0.0)
		)
		_geometry.rotation.z += kick * motion.recoil_roll
		if _infantry_motion != null:
			_infantry_motion.advance(
				delta,
				distance,
				_clock,
				_idle_gesture(),
				kick,
				1.0 if aiming else 0.0
			)
		else:
			_update_body(moving)
	if moving and not _airborne and _mobile:
		_dust_elapsed += delta
		if _dust_elapsed > 0.22 * motion.cadence:
			_dust_elapsed = 0.0
			_unit._match.combat_effects.movement_dust(_unit)
	_aim(delta)
	_sync_muzzle()

	if (
		not moving
		and not aiming
		and _recoil <= 0.0001
		and _hit_kick <= 0.0001
		and _idle_blend <= 0.001
		and _rotors.is_empty()
	):
		_settled = true
		_geometry.transform = _geometry_rest
		if _barrel != null:
			_barrel.position = _barrel_rest


func _update_idle(delta, moving):
	var busy = moving or is_instance_valid(_unit.aim_target) or _recoil > 0 or _hit_kick > 0
	busy = busy or (_movement != null and _movement._has_destination)
	if _unit.action != null:
		busy = busy or not _unit.action.has_method("is_idle") or not _unit.action.is_idle()
	if _unit.has_method("is_under_construction"):
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


func _idle_gesture():
	# A short smooth weight shift / scan followed by several seconds of rest.
	var progress = clampf(_gesture / 3.2, 0.0, 1.0)
	return pow(sin(progress * PI), 2.0) * _gesture_strength * _idle_blend


func _update_parts(delta, moving):
	for item in _leg_data:
		var step = sin(_phase) * 0.35 * motion.amplitude * item.sign if moving else 0.0
		item.node.rotation.x = lerp_angle(
			item.node.rotation.x, item.rest_x + step, minf(1.0, delta * 18.0)
		)
	for rotor in _rotors:
		rotor.rotation.y = wrapf(rotor.rotation.y + delta * 25.0 * motion.cadence, -PI, PI)
	var gesture = _idle_gesture()
	for index in range(_tools.size()):
		var tool = _tools[index]
		tool.rotation = _rests[tool]
		tool.rotation.z += gesture * 0.10 * (-1 if index % 2 == 0 else 1)
	if not is_instance_valid(_unit.aim_target):
		if _turret != null:
			_turret.rotation.y = lerp_angle(
				_turret.rotation.y, _rests[_turret].y + gesture * 0.22, minf(1.0, delta * 3.0)
			)
		if _barrel != null:
			_barrel.rotation.x = lerp_angle(
				_barrel.rotation.x,
				_rests[_barrel].x + absf(gesture) * 0.055,
				minf(1.0, delta * 3.0)
			)


func _update_body(moving):
	var breath = sin(_clock * 1.7) * motion.amplitude * _idle_blend
	var gesture = _idle_gesture()
	var articulated = not _legs.is_empty()
	_geometry.position.y += breath * (0.013 if articulated else 0.004)
	_geometry.rotation.z += gesture * (0.032 if articulated else 0.008)
	_geometry.rotation.y += gesture * (0.045 if InfantryRoster.is_infantry(_unit.type) else 0.008)
	if moving:
		_geometry.position.y += absf(sin(_phase)) * (0.035 if articulated else 0.006)
		_geometry.rotation.z += sin(_phase) * (0.012 if articulated else 0.004)
	if _airborne:
		_geometry.rotation.x += -0.08 if moving else sin(_clock * 1.3) * 0.012
		_geometry.rotation.z += sin(_clock * 1.9) * 0.014
		_geometry.position.y += sin(_clock * 2.4) * 0.045 * motion.amplitude


func _aim(delta):
	if is_instance_valid(_unit.aim_target) and _turret != null:
		_muzzle_dirty = true
		var target_position = _unit.aim_target.global_position + Vector3.UP * 0.45
		var target_local = _turret.get_parent().to_local(target_position) - _turret.position
		_turret.rotation.y = lerp_angle(
			_turret.rotation.y, atan2(-target_local.x, -target_local.z), minf(1.0, delta * 12.0)
		)
		if _barrel != null:
			var direction = _barrel.get_parent().to_local(target_position) - _barrel.position
			_barrel.rotation.x = clamp(
				atan2(direction.y, Vector2(direction.x, direction.z).length()), -0.15, 0.65
			)


func _sync_muzzle():
	if _muzzle_dirty and _muzzle != null and _projectile_origin != null:
		_muzzle_dirty = false
		_projectile_origin.global_transform = _muzzle.global_transform.orthonormalized()
