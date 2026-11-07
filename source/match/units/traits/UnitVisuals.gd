# gdlint: disable=max-file-lines
extends Node

# Visual-only animation for every unit and structure. Poses Geometry and its
# articulated parts from the unit's authoritative state; the unit root, its
# collision, orders and weapon timing are never modified here.

const TurretAim = preload("res://source/match/units/traits/TurretAim.gd")

const Unit = preload("res://source/match/units/Unit.gd")
const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const MotionProfile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
const Chassis = preload("res://source/match/units/traits/ChassisMotion.gd")
const WalkerGait = preload("res://source/match/units/traits/WalkerGait.gd")
const DamageProfile = preload("res://source/match/units/traits/VehicleDamageProfile.gd")
const ROTOR_SPEED = 25.0
const WORK_PERIOD = .9
const FIDGETS = 4

const FrameBudget = preload("res://source/match/units/traits/VisualFrameBudget.gd")
const RuntimeCache = preload("res://source/utils/RuntimeCache.gd")
var motion: MotionProfile
var chassis: Chassis
var gpu_interpolated := false
var _shared: FrameBudget
var _track_motion = null
var _antennas := []
var _antenna_lean := Vector2.ZERO
var _antenna_velocity := Vector2.ZERO
var _wheel_motion = null
var _infantry_motion = null
var _walker = null
var _turret
var _barrel
var _muzzle: Node3D
var _paired_muzzles := []
var _next_muzzle := 0
var _legs := []
var _rotors := []
var _rotor_angles := []
var _tools := []
var _stabilizers := []
var _rests := {}
var _previous_position := Vector3.ZERO
var _clock := 0.0
var _quiet_time := 0.0
var _idle_blend := 0.0
var _gesture := 0.0
var _gesture_strength := 1.0
var _gesture_value := 0.0
var _fidget := 0
var _recoil := 0.0
var _hit_kick := 0.0
var _hit_axis := Vector3.ZERO
var _hit_push := Vector3.ZERO
var _hit_clock := -INF
var _hit_blast := false
var _barrel_rest := Vector3.ZERO
var _geometry_rest_rotation := Vector3.ZERO
var _geometry_rest_scale := Basis.IDENTITY
var _geometry_rest := Transform3D.IDENTITY:
	set(value):
		_geometry_rest = value
		_geometry_rest_rotation = value.basis.get_rotation_quaternion().get_euler()
		_geometry_rest_scale = Basis.from_scale(value.basis.get_scale())
		_rest_is_identity = value.basis.is_equal_approx(Basis.IDENTITY)
var _geometry_pose := Transform3D.IDENTITY
var _presentation_root := Transform3D.IDENTITY
var _dust_elapsed := 0.0
var _aircraft_fx_elapsed := 0.0
var _damage_elapsed := 0.0
var _backfire_left := 0.0
var _damage_audio_elapsed := 0.0
var _damage_profile := {}
var _damage_socket := Vector3.ZERO
var _ground_machine := false
var _scrap_plates := []
var _scrap_rank := -1
var _airborne := false
var _fixed_wing := false
var _mobile := false
var _heavy := false
var _movement = null
var _settled := false
var _aiming := false
var _turret_yaw := 0.0
var _turret_velocity := 0.0
var _turret_rate := 3.0
var _barrel_pitch := 0.0
var _rotor_speed = ROTOR_SPEED
var _tools_posed := false
var _work := 0.0
var _work_clock := 0.0
var _deploys := false
var _deploy := 1.0
var _cull_radius := 3.0
var _rest_is_identity := true
var _barrel_scale := 1.0
var _constructible := false
var _action_reports_idle := false
var _repairs := false
var _sparkling: Node3D
var _culled := false
var _native_presentation: RefCounted
var _presentation_handle := -1
var _pose_elapsed := 0.0:
	get:
		if _native_presentation != null:
			return _native_presentation.elapsed(_presentation_handle)
		return _pose_elapsed
	set(value):
		if _native_presentation != null:
			_native_presentation.set_elapsed(_presentation_handle, value)
		_pose_elapsed = value
var _pose_remaining := 0.0
var _reaction_remaining := 0.0
var _pose_job = preload("res://source/match/rendering/ParallelPoseBatch.gd").Job.new()
var _pose_travel := Vector3.ZERO
var _pose_moving := false
var _pose_worker: RefCounted
var _pose_hierarchy: RefCounted
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
@onready var _geometry: Node3D = get_parent().get_node("Geometry")
@onready var _unit: Unit = get_parent()
@onready var _projectile_origin = _unit.find_child("ProjectileOrigin", true, false)


func _init():
	chassis = Chassis.new()


func _ready():
	var cache = RuntimeCache.bucket("unit_visual_frame")
	var viewport_id = get_viewport().get_instance_id()
	if not cache.has(viewport_id):
		cache[viewport_id] = FrameBudget.new()
	_shared = cache[viewport_id]
	set_physics_process(false)
	# Disabling interpolation also disables inherited root interpolation.
	# Compose the interpolated root with the local pose explicitly in _process.
	_geometry.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not _unit.has_meta("visual_seed"):
		_unit.set_meta("visual_seed", _unit.find_parent("Match").allocate_visual_seed())
	motion = MotionProfile.new(_unit.get_meta("visual_seed"))
	_pose_remaining = fposmod(motion.phase, 1.0) / 15.0
	_clock = motion.phase
	_gesture = motion.idle_period
	_turret = _unit.find_child("*TurretPivot", true, false)
	_barrel = _unit.find_child("*BarrelPivot", true, false)
	_muzzle = _unit.find_child("*Muzzle", true, false)
	var left_muzzle = _unit.find_child("*LeftMuzzle", true, false)
	var right_muzzle = _unit.find_child("*RightMuzzle", true, false)
	if left_muzzle != null and right_muzzle != null:
		_paired_muzzles = [left_muzzle, right_muzzle]
	_legs = _unit.find_children("*LegLeft*", "Node3D", true, false).filter(_is_pivot)
	_legs += _unit.find_children("*LegRight*", "Node3D", true, false).filter(_is_pivot)
	_rotors = _unit.find_children("*RotorLeft", "Node3D", true, false)
	_rotors += _unit.find_children("*RotorRight", "Node3D", true, false)
	_rotors += _unit.find_children("*Rotor?", "Node3D", true, false)
	for pattern in ["*ToolArm*", "*ServiceArm*", "*RepairArm*", "*SensorPivot"]:
		_tools += _unit.find_children(pattern, "Node3D", true, false).filter(_is_pivot)
	_antennas = _unit.find_children("*AntennaPivot*", "Node3D", true, false).filter(_is_pivot)
	_stabilizers = _unit.find_children("*Stabilizer_*", "Node3D", true, false).filter(_is_pivot)
	for part in _legs + _rotors + _tools + _stabilizers + _antennas + [_turret, _barrel]:
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
	_geometry_pose = _geometry_rest
	_movement = _unit.get_node_or_null("Movement")
	_mobile = _movement != null
	_fixed_wing = _mobile and _movement.has_method("flight_velocity")
	_airborne = _unit.movement_domain == Constants.Match.Navigation.Domain.AIR
	_heavy = _unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	_turret_rate = 2.2 if _heavy else 3.4
	_constructible = _unit.has_method("is_under_construction")
	_deploys = "deployment_left" in _unit
	_repairs = _unit.type == "RepairRobot"
	if _unit.type == "Worker":
		_sparkling = _unit.get_node_or_null("Sparkling")
	var infantry = InfantryRoster.is_infantry(_unit.type)
	_ground_machine = _mobile and not _airborne and not infantry
	_damage_profile = DamageProfile.profile(_unit.player.faction)
	_damage_socket = _damage_profile.socket * maxf(.65, _unit.radius)
	var socket = _unit.find_child("*DamageSocket", true, false)
	if socket != null:
		_damage_socket = _geometry.to_local(socket.global_position)
	for rank in [1, 2]:
		for plate in _geometry.find_children("*ScrapRank%d*" % rank, "Node3D", true, false):
			if plate is MeshInstance3D:
				continue
			var meshes = plate.find_children("*", "MeshInstance3D", true, false)
			for mesh in meshes:
				mesh.set_meta("dynamic_presentation", true)
			_scrap_plates.append(
				{"node": plate, "rest": plate.rotation, "rank": rank, "meshes": meshes}
			)
	_sync_scrap_plates()
	if _mobile and not _airborne and not infantry:
		_track_motion = load("res://source/match/units/traits/TrackMotion.gd").new()
		_track_motion.setup(_unit)
		if _track_motion.belts.is_empty():
			_track_motion = null
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
	# Mobile presentation already composes the interpolated simulation transform
	# explicitly. Detach its transform inheritance so each physics translation and
	# turn does not dirty the entire articulated model before the rendered pose.
	if _mobile:
		_geometry.top_level = true


static func _is_pivot(node):
	return not node is MeshInstance3D


func _motion_kind(infantry):
	if infantry:
		return Chassis.Kind.INFANTRY
	if _airborne:
		return Chassis.Kind.AIR
	if _walker != null:
		return Chassis.Kind.WALKER
	if (
		_unit.type in ["Worker", "Tank", "AdvancedTank", "AntiAirVehicle"]
		and _unit.player != null
		and _unit.player.faction == "helix"
	):
		return Chassis.Kind.HOVER
	if _wheel_motion != null:
		return Chassis.Kind.WHEELED
	return Chassis.Kind.TRACKED


func _sync_scrap_plates():
	var rank = _unit.permanent_scrap_rank
	if rank == _scrap_rank:
		return
	_scrap_rank = rank
	for plate in _scrap_plates:
		for mesh in plate.meshes:
			mesh.visible = rank >= plate.rank


func _animate_scrap_plates():
	for index in _scrap_plates.size():
		var plate = _scrap_plates[index]
		var rattle = 0.0
		if _scrap_rank >= plate.rank and chassis.damage_band > 0:
			rattle = (
				sin(chassis.clock * (29.0 + index * 3.0))
				* (.006 if chassis.damage_band == 1 else .018)
			)
		plate.node.rotation = plate.rest + Vector3(rattle, 0, rattle * .4)


func damage_emission_point() -> Vector3:
	return _unit.global_transform * (_geometry_pose * _damage_socket)


func _update_damage(delta: float):
	_sync_scrap_plates()
	if not _ground_machine:
		# Aircraft and structures retain their existing smoke behavior.
		_damage_elapsed += delta
		if _damage_elapsed > .8:
			_damage_elapsed = 0.0
			_unit._match.combat_effects.damage_smoke(_unit)
		return
	var previous = _unit.damage_visual_band
	_unit.damage_visual_band = DamageProfile.band_for(_unit.hp / maxf(1.0, _unit.hp_max), previous)
	chassis.damage_band = _unit.damage_visual_band
	chassis.damage_faction = _unit.player.faction
	_backfire_left = maxf(0.0, _backfire_left - delta)
	if (
		_backfire_left == 0.0
		and DamageProfile.backfire_stress(
			_unit.player.faction, chassis.damage_band, chassis.forward_speed, chassis.accel.x
		)
	):
		if _unit._match.combat_effects.vehicle_backfire(_unit, damage_emission_point()):
			_backfire_left = 2.4
	if previous != chassis.damage_band:
		_settled = false
	_damage_elapsed += delta
	_damage_audio_elapsed += delta
	if _damage_audio_elapsed >= .2:
		_damage_audio_elapsed = 0.0
		_unit._match.combat_audio.update_damage(_unit, chassis.damage_band)
	if _damage_elapsed >= _damage_profile.interval:
		_damage_elapsed = 0.0
		if chassis.damage_band > 0:
			_unit._match.combat_effects.vehicle_damage(
				_unit, chassis.damage_band, damage_emission_point()
			)


func _speed_limit():
	return _movement.speed if _movement != null else 4.0


func _body_length():
	var reach = _unit.get("radius")
	return reach * 2.0 if reach != null else 2.0


func _on_screen(center: Vector3) -> bool:
	# Off-screen units keep their timers but skip posing. One frustum per rendered
	# frame is shared by every unit; headless runs have nothing to cull.
	if _shared.headless:
		return true
	var frame = Engine.get_process_frames()
	if frame != _shared.frustum_frame:
		_shared.frustum_frame = frame
		var camera = get_viewport().get_camera_3d()
		_shared.frustum = camera.get_frustum() if camera != null else []
	for plane: Plane in _shared.frustum:
		if plane.distance_to(center) > _cull_radius:
			return false
	return true


func _on_order(action):
	_quiet_time = 0.0
	_settled = false
	_action_reports_idle = action != null and action.has_method("is_idle")


func fire_recoil():
	_flush_pending_pose()
	_reaction_remaining = .12
	# Weapon authority samples the current simulation root, never the render offset.
	# Remove any idle scan before the weapon samples its actual muzzle transform,
	# and bring a lagging body onto the firing line.
	_quiet_time = 0.0
	_idle_blend = 0.0
	_settled = false
	var before = chassis.yaw_lag
	chassis.clamp_lag(.2)
	if _mobile:
		_geometry_pose.basis = Basis(Vector3.UP, chassis.yaw_lag - before) * _geometry_pose.basis
	_publish_simulation_pose()
	if _infantry_motion != null:
		_infantry_motion.raise_for_shot()
	_aim(1.0)
	if not _paired_muzzles.is_empty():
		_muzzle = _paired_muzzles[_next_muzzle]
		_next_muzzle = (_next_muzzle + 1) % _paired_muzzles.size()
	_sync_muzzle()
	motion.next_shot()
	_recoil = 1.0
	if _heavy and _unit.player.faction == "bastion":
		motion.recoil_duration = chassis.CANNON_RECOVERY
		var muzzle = _unit.get_node_or_null("ProjectileOrigin")
		var direction = -muzzle.global_basis.z if muzzle != null else -_unit.global_basis.z
		chassis.cannon_recoil(_unit.global_basis.inverse() * direction, motion.recoil_strength)
	elif _heavy:
		_suspension_velocity = -0.36
	elif _mobile and _infantry_motion == null:
		_suspension_velocity = -0.16


func hit_reaction(source_position = Vector3.INF, explosive := false):
	_hit_blast = explosive
	_flush_pending_pose()
	_reaction_remaining = .12
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
	var recipe = motion.death_motion(
		InfantryRoster.is_infantry(_unit.type), _airborne, _mobile, away, _unit.global_basis
	)
	if recipe.infantry and _hit_blast and _clock - _hit_clock < 1.5:
		recipe.duration = .8
		recipe.lift = .55
		recipe.slide += (_unit.global_basis * away) * .65
		recipe.style = 0
	return recipe


# Pose once per rendered frame. Simulation can catch up with several physics
# steps without repeatedly dirtying the same model hierarchy. fire_recoil()
# synchronizes the muzzle immediately when gameplay actually fires a shot.
func _process(delta: float):
	var interval := _pose_interval()
	_pose_elapsed += delta
	_pose_remaining -= delta
	_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	if interval == 0.0 or _reaction_remaining > 0.0 or _pose_remaining <= 0.0:
		_flush_pending_pose()
		# Retain the phase when a frame crosses the deadline. Resetting to one
		# whole interval here silently reduces a 30 Hz budget to 20 Hz at 60 FPS.
		if interval > 0.0:
			_pose_remaining += interval * (floorf(-_pose_remaining / interval) + 1.0)
		else:
			_pose_remaining = 0.0
	else:
		_presentation_root = _unit.get_global_transform_interpolated()
	_advance_rotors(delta)
	if _culled:
		_publish_simulation_pose()
		return
	var presented: Transform3D = _presentation_root * _geometry_pose
	# Build the local pose in memory, then publish it once. Restoring the previous
	# pose before animating dirties every mesh in the hierarchy several times.
	if _geometry.global_transform != presented:
		_geometry.global_transform = presented
	_aim(delta)
	if _aiming or _recoil > 0.0:
		_sync_muzzle()


func _physics_process(delta: float):
	if not gpu_interpolated:
		return
	# The GPU interpolates the articulated world poses between simulation ticks.
	# Weapon sockets always sample authoritative simulation time.
	prepare_gpu_pose(delta).solve()
	finish_gpu_pose(delta)


func prepare_gpu_pose(delta: float):
	_prepare_pose(delta)
	return _pose_job


func finish_gpu_pose(delta: float, finalize := true):
	_finish_pose(delta)
	_advance_rotors(delta)
	if finalize:
		publish_gpu_pose(delta)


func publish_gpu_pose(delta: float):
	if _pose_worker != null:
		_settle_pose(_pose_moving)
	_publish_simulation_pose()
	_aim(delta)
	if _aiming or _recoil > 0.0:
		_sync_muzzle()
	elif _pose_worker != null and _pose_hierarchy == null:
		_pose_worker.publish()


func set_gpu_interpolation(enabled: bool, anchors: Array = [], native = null):
	if enabled and _pose_hierarchy == null and not anchors.is_empty():
		_pose_hierarchy = load("res://source/match/rendering/RigidPoseHierarchy.gd").new(
			_geometry, anchors, native
		)
		_pose_hierarchy.remap(self, true)
	gpu_interpolated = enabled
	if (
		enabled
		and _infantry_motion != null
		and _pose_worker == null
		and (_pose_hierarchy != null or not "--no-infantry-workers" in OS.get_cmdline_user_args())
	):
		_pose_worker = load("res://source/match/rendering/InfantryPoseWorker.gd").new(
			_infantry_motion, _pose_hierarchy
		)
	elif not enabled and _pose_worker != null:
		_pose_worker.release()
		_pose_worker = null
	if not enabled and _pose_hierarchy != null:
		_pose_hierarchy.publish()
		_pose_hierarchy.remap(self, false)
		_pose_hierarchy = null
	_pose_elapsed = 0.0
	set_process(not enabled)
	# The renderer coordinates snapshot / worker solve / publication as one batch.
	set_physics_process(false)
	process_physics_priority = 9000
	_geometry.physics_interpolation_mode = (
		Node.PHYSICS_INTERPOLATION_MODE_ON if enabled else Node.PHYSICS_INTERPOLATION_MODE_OFF
	)
	_geometry.reset_physics_interpolation()


func _exit_tree():
	if _pose_worker != null:
		_pose_worker.release()
		_pose_worker = null
	set_native_presentation(null, -1)


func set_native_presentation(batch: RefCounted, handle: int):
	var elapsed := _pose_elapsed
	_native_presentation = batch
	_presentation_handle = handle
	_pose_elapsed = elapsed
	if batch != null:
		batch.set_geometry(
			handle,
			_geometry_pose,
			(
				(_track_motion != null and _track_motion.has_unbatched_belts())
				or not _scrap_plates.is_empty()
			)
		)


func _flush_pending_pose():
	if _pose_elapsed > 0.0:
		_advance_pose(_pose_elapsed)
		_pose_elapsed = 0.0


func _pose_interval() -> float:
	# Spend animation work where it is visible. Simulation, interpolated root
	# motion, turret aiming, rotors and immediate weapon authority remain live.
	if _shared.headless or not _mobile or _unit.is_in_group("selected_units"):
		return 0.0
	var frame := Engine.get_process_frames()
	if frame != _shared.budget_frame:
		_shared.budget_frame = frame
		_shared.crowded = _unit._match.get_units().size() >= 100
		_shared.pixels_per_metre = INF
		var camera := get_viewport().get_camera_3d()
		if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			_shared.pixels_per_metre = get_viewport().get_visible_rect().size.y / camera.size
	if not _shared.crowded:
		return 0.0
	var pixels: float = maxf(1.5, chassis.length) * _shared.pixels_per_metre
	return 1.0 / 15.0 if pixels < 32.0 else (1.0 / 30.0 if pixels < 64.0 else 0.0)


func _notification(what):
	if what == NOTIFICATION_PAUSED and is_instance_valid(_geometry):
		_publish_simulation_pose()


func _publish_simulation_pose():
	if _native_presentation != null:
		_native_presentation.set_geometry(
			_presentation_handle,
			_geometry_pose,
			(
				(_track_motion != null and _track_motion.has_unbatched_belts())
				or not _scrap_plates.is_empty()
			)
		)
		return
	var pose: Transform3D = _unit.global_transform * _geometry_pose
	if _pose_hierarchy != null:
		_pose_hierarchy.root.transform = pose
		# Deforming tracks render natively beside the batched rigid hull. Their
		# scene ancestor must follow the same pose even when rigid leaves are parked.
		if (
			(
				(_track_motion != null and _track_motion.has_unbatched_belts())
				or not _scrap_plates.is_empty()
			)
			and _geometry.global_transform != pose
		):
			_geometry.global_transform = pose
	elif _geometry.global_transform != pose:
		_geometry.global_transform = pose


func _advance_pose(delta: float):
	_prepare_pose(delta)
	_pose_job.solve()
	_finish_pose(delta)


func _prepare_pose(delta: float):
	var root: Transform3D = (
		_unit.get_global_transform_interpolated()
		if not gpu_interpolated and get_tree().physics_interpolation and _unit.can_process()
		else _unit.global_transform
	)
	_presentation_root = root
	_pose_job.chassis = chassis
	_pose_job.root = root
	_pose_job.delta = delta
	_pose_job.mode = 0
	_update_damage(delta)
	var travel: Vector3 = root.origin - _previous_position
	_pose_travel = travel
	var distance := travel.length()
	_previous_position = root.origin
	var moving: bool = distance > maxf(.000001, delta * .02)
	_pose_moving = moving
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
		_pose_job.mode = 1
	elif _settled and chassis.is_settled() and chassis._previous == root:
		_pose_job.mode = 2
	else:
		_pose_job.mode = 3


func _finish_pose(delta: float):
	if _pose_job.mode == 0:
		return
	var moving := _pose_moving
	var travel := _pose_travel
	# Wheels also roll through pivot turns, which have no root translation.
	if _wheel_motion != null:
		_wheel_motion.advance(delta)
	if _track_motion != null:
		_track_motion.advance(delta)
	_advance_antennas(delta)
	_animate_scrap_plates()

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
	if _airborne and not _fixed_wing and not _rotors.is_empty():
		_dust_elapsed += delta
		if _dust_elapsed > .45:
			_dust_elapsed = 0.0
			_unit._match.combat_effects.rotor_downwash(_unit)
	elif _fixed_wing and _movement != null and _unit._match != null:
		_aircraft_fx_elapsed += delta
		if _aircraft_fx_elapsed >= 0.08:
			_aircraft_fx_elapsed = 0.0
			var effects = _unit._match.get("combat_effects")
			if is_instance_valid(effects):
				effects.aircraft_flight_effects(_unit, _movement)
	if moving and not _airborne and _mobile:
		_dust_elapsed += delta
		if _dust_elapsed > 0.22 * motion.cadence:
			_dust_elapsed = 0.0
			_unit._match.combat_effects.movement_dust(_unit)

	if _infantry_motion == null or _infantry_motion.deferred_job == null:
		_settle_pose(moving)


func _settle_pose(moving: bool):
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
		_geometry_pose = _geometry_rest
		if _barrel != null:
			_barrel.position = _barrel_rest


func _apply_geometry(delta: float, ground_distance: float):
	var kick = recoil_envelope(1.0 - _recoil) * motion.recoil_strength
	if _barrel != null and (kick > 0.0 or _barrel.position != _barrel_rest):
		_barrel.position = (
			_barrel_rest
			+ (
				Vector3(0, -sin(_barrel_pitch), cos(_barrel_pitch))
				* kick
				* (0.28 if _heavy else 0.12)
				/ _barrel_scale
			)
		)
	# Buildings keep their foundation fixed; their articulated parts still animate.
	if not _mobile:
		return
	if _fixed_wing:
		# Fixed-wing attitude is authoritative flight state, not synthesized sway:
		# nose follows the flight path, wings bank into coordinated turns.
		_pose_geometry(Vector3(_movement.pitch + kick * 0.03, 0, -_movement.bank), Vector3.ZERO)
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
		_walker.advance(
			delta,
			ground_distance,
			1.0 if _unit.weapon_charge_progress >= 0 else 0.0,
			_presentation_root
		)
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
	if _walker != null:
		_geometry_pose = _walker.support_body(_geometry_pose)
		_walker.pose(_geometry_pose)


func _pose_geometry(rotation: Vector3, offset: Vector3):
	# Keep simulation-local posing separate from the final interpolated transform.
	if _rest_is_identity:
		_geometry_pose = Transform3D(Basis.from_euler(rotation), _geometry_rest.origin + offset)
	else:
		_geometry_pose = Transform3D(
			Basis.from_euler(_geometry_rest_rotation + rotation) * _geometry_rest_scale,
			_geometry_rest.origin + offset
		)


func _pose_at_rest() -> bool:
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


func _update_idle(delta: float, moving: bool):
	var busy = moving or _aiming or _recoil > 0 or _hit_kick > 0
	busy = busy or (_movement != null and _movement._has_destination)
	var action = _unit.action
	if action != null:
		busy = busy or not _action_reports_idle or not action.is_idle()
	if _constructible:
		busy = busy or _unit.is_under_construction() or _is_working()
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


func _update_work(delta: float, moving: bool):
	# Harvesting, building and field repairs get a purposeful tool rhythm.
	var working = not moving and _is_working()
	_work = move_toward(_work, 1.0 if working else 0.0, delta * 3.0)
	if _work > 0.0:
		_work_clock += delta
		_settled = false
	else:
		_work_clock = 0.0


func _is_working() -> bool:
	if _constructible:
		return _unit.is_constructed() and _unit.get_meta("service_used", 0) > 0
	if _sparkling != null:
		return _sparkling._animation != null
	if _repairs and _unit.action != null:
		return (
			_unit.action.has_method("repair_target")
			and _movement != null
			and not _movement._has_destination
		)
	return false


static func _strike(cycle: float) -> float:
	# Quick downward stroke, slower recovery.
	var progress = fposmod(cycle, 1.0)
	if progress < .25:
		return smoothstep(0.0, .25, progress)
	return 1.0 - smoothstep(.25, 1.0, progress)


func _idle_gesture() -> float:
	# A short smooth weight shift / scan followed by several seconds of rest.
	if _idle_blend <= 0.0:
		return 0.0
	var wave = sin(clampf(_gesture / 3.2, 0.0, 1.0) * PI)
	return wave * wave * _gesture_strength * _idle_blend


func _advance_rotors(delta: float):
	if _culled:
		return
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


func _update_parts(delta: float):
	var gesture = _gesture_value
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
			if _deploy < .98 and deploy >= .98 and _deploys:
				_unit._match.combat_effects.deployment_dust(_unit)
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


func _traverse(target: float, delta: float, omega: float, max_rate: float):
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


func _set_turret_yaw(yaw: float):
	# Only this node animates the turret, so the cached yaw is authoritative.
	if yaw == _turret_yaw:
		return
	_turret_yaw = yaw
	var rest: Vector3 = _rests[_turret]
	_turret.rotation = Vector3(rest.x, yaw, rest.z)


func _set_barrel_pitch(pitch: float):
	if pitch == _barrel_pitch:
		return
	_barrel_pitch = pitch
	var rest: Vector3 = _rests[_barrel]
	_barrel.rotation = Vector3(pitch, rest.y, rest.z)


func _aim(delta: float):
	if not is_instance_valid(_unit.aim_target) or _turret == null:
		return
	var target_position: Vector3 = _unit.aim_target.global_position + Vector3.UP * 0.45
	var target_local: Vector3 = _parent_local(_turret, target_position) - _turret.position
	var bearing: float = TurretAim.within_arc(TurretAim.bearing(target_local), 0.0, PI)
	if delta >= 1.0:
		_turret_velocity = 0.0
		_set_turret_yaw(bearing)
	else:
		_traverse(bearing, delta, 11.0, _turret_rate)
	if _barrel != null:
		var direction: Vector3 = _parent_local(_barrel, target_position) - _barrel.position
		var elevation: float = TurretAim.elevation(direction)
		_set_barrel_pitch(
			(
				elevation
				if delta >= 1.0
				else lerp_angle(_barrel_pitch, elevation, minf(1.0, delta * 9.0))
			)
		)


func _parent_local(part, point: Vector3) -> Vector3:
	if _pose_hierarchy != null:
		return _pose_hierarchy.world_for_pose(part.get_parent()).affine_inverse() * point
	return part.get_parent().to_local(point)


func _sync_muzzle():
	if _pose_hierarchy != null:
		if _muzzle != null and _projectile_origin != null:
			_projectile_origin.global_transform = (
				_pose_hierarchy.world_for(_muzzle).orthonormalized()
			)
		return
	if _pose_worker != null:
		_pose_worker.publish()
	if _muzzle != null and _projectile_origin != null:
		_projectile_origin.global_transform = _muzzle.global_transform.orthonormalized()


static func recoil_envelope(progress: float) -> float:
	# Explosive kick, short mechanical hold, then a soft hydraulic return.
	if progress >= 1.0:
		return 0.0
	if progress < .1:
		return smoothstep(0.0, .1, progress)
	if progress < .24:
		return 1.0
	return 1.0 - smoothstep(.24, 1.0, progress)


func _advance_antennas(delta: float):
	if _antennas.is_empty():
		return
	# Exact underdamped oscillator; stable even when pose updates are throttled.
	var target := Vector2(chassis.accel.x, chassis.accel.y).limit_length(16.0) * .009
	var error := _antenna_lean - target
	var damping := 4.0
	var frequency := 16.0
	var decay := exp(-damping * delta)
	var c := cos(frequency * delta)
	var s := sin(frequency * delta) / frequency
	_antenna_lean = target + decay * (error * c + (_antenna_velocity + damping * error) * s)
	_antenna_velocity = (
		decay * (_antenna_velocity * c - (damping * _antenna_velocity + 272.0 * error) * s)
	)
	for antenna in _antennas:
		antenna.rotation = _rests[antenna] + Vector3(_antenna_lean.x, 0, _antenna_lean.y)
