# Movement keeps its shared navigation and native-state lifecycle in one trait.
# gdlint: disable=max-file-lines
extends NavigationAgent3D

signal movement_finished
signal passive_movement_started
signal passive_movement_finished
signal phase_shifted(origin, destination)

const MassContacts = preload("res://source/match/orders/MassContactIndex.gd")
const MotionProfile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
const Unit = preload("res://source/match/units/Unit.gd")
const BattleMap = preload("res://source/match/Map.gd")
const Battlefield = preload("res://source/match/combat/Battlefield.gd")
const TerrainNavigation = preload("res://source/match/TerrainNavigation.gd")

const PROGRESS_WINDOW = 1.0
const MINIMUM_PROGRESS = 0.2
const RECOVERY_DURATION = 0.6
const GROUND_RECOVERY_DURATION = 2.0
const GROUND_RECOVERY_DISTANCE = 2.0
const GROUND_RECOVERY_LOOKAHEAD = 8.0
const GROUND_CONTACT_MARGIN = .02
# Vertical speed of rotorcraft settling onto or lifting off a helipad.
const SETTLE_RATE = 1.2
# Tracked vehicles and convoy trucks reach cruise speed in roughly a third of
# a second. Steering, crowd clipping and explicit Stop retain immediate control.
const VEHICLE_ACCELERATION = 9.0
const VEHICLE_BRAKING = 13.0
const VEHICLE_ROLES = ["Tank", "AdvancedTank", "SupplyTruck"]

const ROTATION_LOW_PASS_FILTER_ENABLED = true
const ROTATION_LOW_PASS_FILTER_WINDOW_SIZE = 10  # number of frames for accumulating directions
const ROTATION_LOW_PASS_FILTER_VELOCITY_THRESHOLD = 0.01  # velocities below will be dropped

const PASSIVE_MOVEMENT_TRACKING_ENABLED = true

@export var domain = Constants.Match.Navigation.Domain.TERRAIN:
	set(value):
		domain = value
		var unit = get_parent()
		if unit != null and unit.get("_native_state") != null:
			unit._native_state.domain = value
# Rotorcraft and drones accelerate and brake at this rate instead of snapping
# to full speed (metres per second squared). Ground units are unaffected.
@export var air_acceleration = 7.0
@export var speed: float = 4.0:
	set(value):
		speed = value
		_native_base_speed = value
		var unit = get_parent()
		if unit != null and unit.get("_native_state") != null:
			unit._native_state.base_speed = value
		_native_refresh_facts()
	get:
		var value = unclamped_speed()
		return minf(value, cohesion_limit) if cohesion_limit >= 0 else value

var ion_stall_left = 0.0
var cohesion_group = null
# A negative value disables the clamp; native crowd reads this cached value.
var cohesion_limit = -1.0
var settle_height = INF
# A harvest run passes through other ground units in both directions. Terrain,
# structures and deposits still constrain it through the navmesh and obstacles.
var ghosted = false:
	set = set_ghosted

# Rotorcraft settle onto a helipad deck at this height, then climb back out.
var _hovering = false
var _exit_clearance_target = Vector3.INF
var _native_base_speed: float = 4.0
var _exit_clearance_until = 0.0
var _physics_delta: float = 0.0
var _last_navigation_iteration = 0
var _has_destination = false
var _synchronized = false
var _command_revision = 0
var _progress_elapsed = 0.0
var _progress_position = Vector3.ZERO
var _recovery_left = 0.0
var _recovery_direction = Vector3.ZERO
var _recovery_checked = false

var _rotation_low_pass_filter_window = []
var _total_direction_in_the_low_pass_filter_window = Vector3.ZERO
var _previously_set_global_transform_of_unit = null

var _passive_movement_detected = false
var _air_velocity = Vector3.ZERO
var _climbing_out = false
var _ground_alignment_height = INF
var _uses_platform_height = false
var _projection_hint = {}
var _projection_frame = -1
var _projection_iteration = -1
var _projection_point = Vector2.INF
var _projection_result = Vector3.ZERO
var _native_runtime: RefCounted
var _native_handle := -1
var _native_velocity_callback := Callable()
var _ground_travel_frame := -1
var _ground_travel_distance := 0.0

@onready var _match = find_parent("Match")
@onready var _unit: Unit = get_parent()
@onready var _map: BattleMap = _match.map
@onready var _elevated: bool = _map.is_elevated()
@onready var _battlefield: Battlefield = _match.battlefield
@onready var _terrain_navigation: TerrainNavigation = _match.navigation.terrain
@onready var _commander_support = _match.commander_support


func unclamped_speed() -> float:
	if not is_instance_valid(_unit):
		return _native_base_speed
	if _unit._native_state != null:
		return _unit._native_state.speed()
	var factor: float = _unit.signature.speed_factor() if _unit.signature != null else 1.0
	if _unit.abilities != null:
		factor *= _unit.abilities.speed_factor()
	if _unit.suppression != null:
		factor *= _unit.suppression.speed_factor()
	if _commander_support != null:
		factor *= _commander_support.speed_factor(_unit)
	return (
		_native_base_speed
		* factor
		* _unit.veterancy_speed_factor
		* (1.0 + 0.1 * _unit.scrap_hardened_tiers)
		* _unit.movement_technology_factor()
	)


func phase_destination(point: Vector3, maximum_distance = 8.0) -> Vector3:
	if not _synchronized or not point.is_finite() or _unit.has_meta("garrison_host"):
		return Vector3.INF
	var delta = (point - _unit.global_position) * Vector3(1, 0, 1)
	if delta.length() > maximum_distance + .001 or delta.length() < .05:
		return Vector3.INF
	if (
		point.x < radius
		or point.z < radius
		or point.x > _map.size.x - radius
		or point.z > _map.size.y - radius
	):
		return Vector3.INF
	var projected = _navigation_position(point)
	if ((projected - point) * Vector3(1, 0, 1)).length() > .2:
		return Vector3.INF
	for other in _battlefield.nearby_units(projected, radius + 3.0):
		if (
			other == _unit
			or other.hp <= 0
			or other.has_meta("garrison_host")
			or other.movement_domain != domain
		):
			continue
		if (
			((other.global_position - projected) * Vector3(1, 0, 1)).length()
			< radius + other.radius
		):
			return Vector3.INF
	return projected


func phase_shift(point: Vector3) -> bool:
	var destination = phase_destination(point)
	if not destination.is_finite():
		return false
	var origin = _unit.global_position
	if not relocate(destination):
		return false
	phase_shifted.emit(origin, destination)
	return true


func relocate(destination: Vector3) -> bool:
	if not destination.is_finite():
		return false
	# Preserve current orders and the turret target. Relocate the path origin;
	# a new query resumes movement from the phase landing instead of old corners.
	var travelling = _has_destination
	var target = target_position
	_unit.global_position = destination
	_unit.reset_physics_interpolation()
	_progress_position = destination
	_progress_elapsed = 0.0
	_recovery_left = 0.0
	_recovery_checked = false
	_previously_set_global_transform_of_unit = null
	_rotation_low_pass_filter_window.clear()
	_total_direction_in_the_low_pass_filter_window = Vector3.ZERO
	set_velocity_forced(Vector3.ZERO)
	velocity = Vector3.ZERO
	_ground_motion_budget(0.0, 0.0, true)
	if travelling:
		target_position = target
	_native_refresh_facts()
	return true


func apply_ion_stall(seconds: float):
	ion_stall_left = maxf(ion_stall_left, maxf(0.0, seconds))


func _update_mass_contacts(delta: float):
	if (
		not _synchronized
		or not _has_destination
		or ghosted
		or domain != Constants.Match.Navigation.Domain.TERRAIN
		or MotionProfile.mass_tier(_unit) != MotionProfile.Mass.HEAVY
	):
		return
	var direction = velocity * Vector3(1, 0, 1)
	if direction.length_squared() < .01:
		return
	direction = direction.normalized()
	var origin = _unit.global_position
	var reach = radius + 1.2
	for other in MassContacts.nearby(_match, origin, reach):
		if (
			other == _unit
			or other.hp <= 0
			or other.has_meta("garrison_host")
			or MotionProfile.mass_tier(other) != MotionProfile.Mass.LIGHT
		):
			continue
		var movement = other.get_node_or_null("Movement")
		if movement == null or movement.domain != domain:
			continue
		var offset = (other.global_position - origin) * Vector3(1, 0, 1)
		var forward = offset.dot(direction)
		var contact = radius + movement.radius
		if forward < -.05 or forward > contact + .35 or offset.length() > contact + .35:
			continue
		if other.player != _unit.player:
			if (
				other.suppression != null
				and other.suppression.band == other.suppression.Band.PINNED
				and offset.length() <= contact + .04
			):
				var open_ground = true
				if _map.get("terrain") != null:
					var flags = _map.terrain.flag_at(
						Vector2(other.global_position.x, other.global_position.z)
					)
					open_ground = flags & _map.terrain.FOREST == 0
				if open_ground:
					other.receive_damage(_unit, 1000000.0, other.global_position, {"kind": "crush"})
			continue
		var side = Vector3(-direction.z, 0, direction.x)
		if (
			offset.dot(side) < 0
			or (is_zero_approx(offset.dot(side)) and other.get_instance_id() % 2 == 0)
		):
			side = -side
		var remaining = movement._ground_motion_budget(delta)
		var step = minf(minf(1.8 * delta, .06), remaining)
		if step <= .00001:
			continue
		var candidate = other.global_position + side * step
		var navigable = movement._navigation_position(candidate)
		if ((navigable - candidate) * Vector3(1, 0, 1)).length() > .02:
			continue
		var distance = ((navigable - other.global_position) * Vector3(1, 0, 1)).length()
		if distance > remaining + .00001:
			continue
		var blocked = false
		for neighbor in _battlefield.nearby_units(candidate, movement.radius + 1.2):
			if (
				neighbor == other
				or neighbor == _unit
				or neighbor.hp <= 0
				or neighbor.movement_domain != domain
			):
				continue
			if (
				candidate.distance_to(neighbor.global_position)
				< movement.radius + neighbor.radius - .02
			):
				blocked = true
				break
		if not blocked:
			other.global_position = navigable
			movement._ground_motion_budget(delta, distance)


func _ground_motion_budget(delta: float, consumed = 0.0, reset = false) -> float:
	var frame = Engine.get_physics_frames()
	if reset or _ground_travel_frame != frame:
		_ground_travel_frame = frame
		_ground_travel_distance = 0.0
	if _native_runtime != null and _native_handle >= 0:
		return _native_runtime.motion_budget(_native_handle, delta, consumed, reset)
	if reset:
		return 0.0
	_ground_travel_distance += consumed
	return maxf(0.0, speed * delta - _ground_travel_distance)


func refresh_cohesion():
	cohesion_limit = (
		cohesion_group.speed_limit()
		if (
			cohesion_group != null
			and _unit != null
			and _unit.manual_orders != null
			and _unit.manual_orders.cohesion_enabled
		)
		else -1.0
	)


func _enter_tree():
	if _native_runtime != null:
		_rebind_native.call_deferred()


func _rebind_native():
	if (
		_native_handle < 0
		and is_inside_tree()
		and is_instance_valid(_match)
		and _match.crowd_runtime != null
	):
		_match.crowd_runtime.bind_agent(self)


func _physics_process(delta):
	ion_stall_left = maxf(0.0, ion_stall_left - delta)
	refresh_cohesion()
	_update_mass_contacts(delta)
	if _native_runtime != null:
		return
	_physics_delta = delta
	if _unit.has_meta("breach_pending") or _abilities_prevent_movement():
		velocity = Vector3.ZERO
		return
	var current_speed: float = speed
	if ion_stall_left > 0 and domain == Constants.Match.Navigation.Domain.AIR:
		current_speed *= .15
	if max_speed != current_speed:
		max_speed = current_speed
	# A settled firing line holds its ground while arriving allies flow around it.
	# Equal avoidance priority lets the rear ranks push shooters toward the enemy.
	var priority := 0.8 if not _has_destination and is_instance_valid(_unit.aim_target) else 0.5
	if avoidance_priority != priority:
		avoidance_priority = priority
	if _advance_exit_clearance(delta, current_speed):
		return
	if not _has_destination:
		velocity = _air_inertia(Vector3.ZERO, delta)
		return
	# Advance the path exactly once per physics tick, never from an avoidance callback.
	var next_point: Vector3
	var finished: bool
	if _uses_flight_clearance():
		# The air navigation region is an unobstructed rectangle. Steer toward
		# its nearest valid destination in XZ; height must not stall a planar path.
		next_point = NavigationServer3D.map_get_closest_point(get_navigation_map(), target_position)
		finished = (
			((_unit.global_position - next_point) * Vector3(1, 0, 1)).length()
			<= target_desired_distance
		)
	else:
		next_point = get_next_path_position()
		finished = is_navigation_finished()
	if finished:
		_has_destination = false
		velocity = Vector3.ZERO
		_finish_command.call_deferred(_command_revision)
		return
	var offset = (next_point - _unit.global_position) * Vector3(1, 0, 1)
	var direction = offset.normalized()
	_progress_elapsed += delta
	if _progress_elapsed >= PROGRESS_WINDOW and _recovery_left <= 0:
		var travelled = _unit.global_position.distance_to(_progress_position)
		_progress_position = _unit.global_position
		_progress_elapsed = 0.0
		if travelled < MINIMUM_PROGRESS and _recovery_left <= 0:
			# A short, consistent sidestep breaks symmetric crowd deadlocks.
			_recovery_direction = direction.rotated(Vector3.UP, PI / 2.0)
			_recovery_left = RECOVERY_DURATION
			if (
				domain == Constants.Match.Navigation.Domain.TERRAIN
				and not has_occupied_endpoint(false)
			):
				_recovery_direction = _ground_recovery_direction(direction)
				_recovery_left = GROUND_RECOVERY_DURATION
			_recovery_checked = true
			var destination = target_position
			target_position = destination
	if _recovery_left > 0:
		_recovery_left -= delta
		if domain == Constants.Match.Navigation.Domain.TERRAIN and not has_occupied_endpoint(false):
			# A restored sidestep may point into a rebuilt boundary. Give its new
			# direction one local recovery window; no-progress timers still
			# depend only on actual movement.
			if not _recovery_checked:
				if _recovery_clearance(_recovery_direction) < GROUND_RECOVERY_DISTANCE:
					_recovery_direction = _ground_recovery_direction(direction)
					_recovery_left = GROUND_RECOVERY_DURATION
				_recovery_checked = true
			if _unit.global_position.distance_to(_progress_position) >= GROUND_RECOVERY_DISTANCE:
				_recovery_left = 0.0
				_continue_ground_recovery()
			if _recovery_left <= 0:
				# The escape can bypass a corner covered by a settled body. Rebuild
				# from here instead of returning to that unreachable old waypoint.
				target_position = target_position
			else:
				# Commit briefly to clear the obstruction before following the same
				# path again. Navigation and body clipping still constrain every step.
				direction = _recovery_direction
		else:
			# Near an occupied final point, retain short yielding so arrival or
			# work-face selection can resolve contact without an outward detour.
			_recovery_left = minf(_recovery_left, RECOVERY_DURATION)
			direction = (direction * 0.35 + _recovery_direction).normalized()
	# Avoidance consumes metres per second. Apply delta only when moving the unit.
	if domain == Constants.Match.Navigation.Domain.AIR:
		# Brake in time to stop at the destination instead of arriving at speed.
		var braking = sqrt(2.0 * air_acceleration * offset.length())
		velocity = _air_inertia(direction * minf(current_speed, braking), delta)
	else:
		velocity = _ground_velocity(direction, offset.length(), delta, current_speed)


func _ground_velocity(
	direction: Vector3, waypoint_distance: float, delta: float, current_speed: float
) -> Vector3:
	var desired: float = minf(current_speed, waypoint_distance / maxf(delta, 0.001))
	if ghosted or _unit.type not in VEHICLE_ROLES or _recovery_left > 0:
		return direction * desired
	# Only brake for the final waypoint. Slowing at every intermediate corner
	# would make narrow passages and production routes needlessly hesitant.
	var remaining := ((_unit.global_position - get_final_position()) * Vector3(1, 0, 1)).length()
	var braking_distance := current_speed * current_speed / (2.0 * VEHICLE_BRAKING)
	if remaining < braking_distance + target_desired_distance + 0.1:
		var path = get_current_navigation_path()
		if not path.is_empty() and get_current_navigation_path_index() >= path.size() - 1:
			var stopping_distance := maxf(0.0, remaining - target_desired_distance + 0.02)
			desired = minf(desired, sqrt(2.0 * VEHICLE_BRAKING * stopping_distance))
	# The requested velocity is already archived, so an interrupted acceleration
	# resumes without a new unsaved throttle or a full-speed jump after loading.
	var current := maxf(0.0, velocity.dot(direction))
	var rate := VEHICLE_ACCELERATION if desired > current else VEHICLE_BRAKING
	return direction * move_toward(current, desired, rate * delta)


func _changing_height():
	return (
		(is_finite(settle_height) and absf(_unit.global_position.y - settle_height) > 0.005)
		or _climbing_out
		or (
			domain == Constants.Match.Navigation.Domain.TERRAIN
			and is_finite(_ground_alignment_height)
			and absf(_unit.global_position.y - _ground_alignment_height) > 0.005
		)
	)


func _air_inertia(desired, delta):
	if domain != Constants.Match.Navigation.Domain.AIR:
		return desired
	_air_velocity = _air_velocity.move_toward(desired, air_acceleration * delta)
	if _air_velocity.length_squared() < 0.0004:
		_air_velocity = Vector3.ZERO
	return _air_velocity


func request_exit_clearance(point):
	if not _synchronized or ghosted or _unit.has_meta("garrison_host"):
		return
	# An actively travelling manual order already clears its current position.
	# Production must not steer it away from the player's destination.
	if _has_destination and _unit.manual_orders != null and _unit.manual_orders._engaged:
		return
	if _exit_clearance_target.is_finite() and _match.simulation_time < _exit_clearance_until:
		return
	_exit_clearance_target = point
	_exit_clearance_until = _match.simulation_time + 2.5


func cancel_exit_clearance():
	_exit_clearance_target = Vector3.INF
	_exit_clearance_until = 0.0


func _advance_exit_clearance(delta, current_speed: float):
	if not _exit_clearance_target.is_finite():
		return false
	var offset = (_exit_clearance_target - _unit.global_position) * Vector3(1, 0, 1)
	if offset.length() < .15 or _match.simulation_time >= _exit_clearance_until:
		_exit_clearance_target = Vector3.INF
		return false
	# This is a short avoidance maneuver, not a new order. Keep the navigation
	# destination, action and queued orders intact.
	velocity = offset.normalized() * minf(current_speed, offset.length() / delta)
	return true


func has_occupied_endpoint(require_short_route = true):
	var path = get_current_navigation_path()
	if path.is_empty():
		return false
	var end: Vector3 = path[-1] * Vector3(1, 0, 1)
	var own_radius: float = radius
	var origin: Vector3 = _unit.global_position_yless
	var mobile_reach: float = own_radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
	# A settled mobile body can only finish this order within contact range.
	# Most recovering units are farther away; avoid scanning their destination
	# neighbors (and the remaining path) until arrival is actually possible.
	var contact_bound: float = mobile_reach + .2
	if origin.distance_squared_to(end) > contact_bound * contact_bound:
		return false
	var remaining = 0.0
	if require_short_route:
		# A nearby endpoint can sit just beyond a tiny polygon bend. Bound
		# actual remaining travel instead of requiring a particular path index;
		# an endpoint across a wall still requires its full remaining route.
		var previous = origin
		for index in range(get_current_navigation_path_index(), path.size()):
			var point = path[index] * Vector3(1, 0, 1)
			remaining += previous.distance_to(point)
			previous = point
	# A plain point order can finish beside a settled ally occupying its final
	# reachable position. MovingToUnit owns its own process/contact checks.
	# Only mobile agents qualify; structure radii must not widen this query.
	# The terrain agent limit also covers the smaller air-agent radius limit.
	for other in _battlefield.nearby_units(end, mobile_reach, _unit.player):
		if (
			other == _unit
			or not other.is_in_group("units")
			or other.is_queued_for_deletion()
			or other.hp <= 0
		):
			continue
		var movement = other._get_navigation_trait()
		if (
			not movement is NavigationAgent3D
			or movement.domain != domain
			or movement.speed <= 0
			or movement.ghosted
			or movement._has_destination
			or movement.velocity.length_squared() >= 0.01
		):
			continue
		var spacing: float = own_radius + movement.radius
		if (
			other.global_position_yless.distance_to(end) < spacing
			and origin.distance_to(end) <= spacing + 0.2
			and (not require_short_route or remaining <= spacing + 0.2)
		):
			return true
	return false


func _continue_ground_recovery():
	# A backward escape can leave the next corner covered by the same body.
	# Look through short polygon-edge waypoints before resuming the route;
	# continue with another bounded, collision-constrained side step if needed.
	if _battlefield == null or ghosted:
		return
	var origin = _unit.global_position
	var path = NavigationServer3D.map_get_path(get_navigation_map(), origin, target_position, true)
	if path.size() < 2:
		return
	var neighbors = _battlefield.nearby_units(
		origin,
		GROUND_RECOVERY_LOOKAHEAD + radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + .25
	)
	var blocked = false
	var distance = 0.0
	for index in range(1, path.size()):
		var previous = path[index - 1]
		var next = previous.move_toward(path[index], GROUND_RECOVERY_LOOKAHEAD - distance)
		if _ground_contact(previous, next, neighbors).w < 1.0:
			blocked = true
			break
		distance += previous.distance_to(next)
		if distance >= GROUND_RECOVERY_LOOKAHEAD - .001:
			break
	if not blocked:
		return
	_recovery_direction = _ground_recovery_direction(
		((path[1] - origin) * Vector3(1, 0, 1)).normalized(), true
	)
	_recovery_left = GROUND_RECOVERY_DURATION
	_progress_position = origin


func _ground_recovery_direction(path_direction, continuing = false):
	var best = path_direction.rotated(Vector3.UP, PI / 2.0)
	var clearance = -1.0
	var free_distance = -1.0
	var origin = _unit.global_position
	var neighbors = []
	if _battlefield != null and not ghosted:
		neighbors = _battlefield.nearby_units(
			origin,
			(
				_unit.radius
				+ Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
				+ GROUND_RECOVERY_DISTANCE
				+ .25
			)
		)
	var angles = [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, 3 * PI / 4.0, -3 * PI / 4.0, PI]
	var side = signf(path_direction.cross(_recovery_direction).y)
	if continuing:
		# Keep rounding the same side of the obstruction. Choosing the longest
		# opposite ray at every step oscillates between two open pockets.
		angles.sort_custom(func(a, b): return signf(a) * side > signf(b) * side)
	for angle in angles:
		if continuing:
			if signf(angle) != side and free_distance >= MINIMUM_PROGRESS * 2.0:
				break
		elif absf(angle) > PI / 2.0 and free_distance >= GROUND_RECOVERY_DISTANCE:
			break
		var candidate = path_direction.rotated(Vector3.UP, angle)
		var distance = _recovery_clearance(candidate)
		var contact := _ground_contact(origin, origin + candidate * distance, neighbors)
		var free = distance * contact.w
		# Rank actual body-clear travel, not the unobstructed terrain ray.
		# Otherwise a two-metre ray stopped by a neighbor after two centimetres
		# defeats a shorter route the unit could actually traverse.
		var usable = free >= GROUND_CONTACT_MARGIN
		var previous_usable = free_distance >= GROUND_CONTACT_MARGIN
		if (
			(usable and not previous_usable)
			or (
				usable == previous_usable
				and (
					free > free_distance
					or (is_equal_approx(free, free_distance) and distance > clearance)
				)
			)
		):
			best = candidate
			clearance = distance
			free_distance = free
	return best


func _recovery_clearance(direction):
	var origin = _unit.global_position
	var clearance = 0.0
	for step in 4:
		var distance = (step + 1) * 0.5
		var candidate = origin + direction * distance
		var navigable := _closest_navigation_point(candidate)
		if ((navigable - candidate) * Vector3(1, 0, 1)).length() > 0.15:
			break
		clearance = distance
	return clearance


func _ready():
	if (
		MotionProfile.mass_tier(_unit) == MotionProfile.Mass.LIGHT
		and domain == Constants.Match.Navigation.Domain.TERRAIN
	):
		_unit.add_to_group("light_crowd_units")
	_hovering = _unit.has_method("is_flux_skimmer") and _unit.is_flux_skimmer()
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		# Intermediate corners are shared by an entire crowd. Requiring every
		# large chassis to touch the same 20 cm disc forces single-file turns
		# even when the passage has room to pass. Allow its footprint around a
		# corner; final arrival still uses target_desired_distance, and every
		# step remains constrained by the navigation mesh and body contacts.
		path_desired_distance = .2 if _hovering else maxf(path_desired_distance, radius)
		# Near-collinear mesh portals can pin avoidance to an unnecessary point
		# inside a neighbor. Remove them without broadening arrival tolerances.
		simplify_path = true
		simplify_epsilon = .01
	set_physics_process(false)
	if _match.navigation == null:
		await _match.ready
	await _match.navigation.wait_until_synchronized(domain)
	if _hovering and _match.navigation.hover != null:
		var hover_map = _match.navigation.hover.navigation_map_rid
		while (
			NavigationServer3D.map_get_iteration_id(hover_map) == 0
			or not (
				NavigationServer3D
				. map_get_closest_point_owner(hover_map, _unit.global_position)
				. is_valid()
			)
		):
			await get_tree().physics_frame
		set_navigation_map(hover_map)
	else:
		set_navigation_map(_match.navigation.get_navigation_map_rid_by_domain(domain))
	_align_unit_position_to_navigation()
	_progress_position = _unit.global_position
	_synchronized = true
	# Preserve orders received while the navigation server was synchronizing.
	if not _has_destination:
		target_position = _unit.global_position
	if _match.crowd_runtime == null or not _match.crowd_runtime.bind_agent(self):
		velocity_computed.connect(_on_velocity_computed)
	set_physics_process(true)


func _exit_tree():
	if _native_runtime != null and _native_handle >= 0:
		if (
			_native_velocity_callback.is_valid()
			and velocity_computed.is_connected(_native_velocity_callback)
		):
			velocity_computed.disconnect(_native_velocity_callback)
		_native_runtime.unbind_agent(_native_handle)
		_native_handle = -1


func _native_refresh_facts(_ability = null):
	if _native_runtime != null and _native_handle >= 0:
		_native_runtime.refresh_agent(_native_handle)


func _native_connect_facts():
	if _native_runtime == null or _native_handle < 0 or not is_inside_tree():
		return
	var unit = get_parent()
	if (
		unit.abilities != null
		and not unit.abilities.ability_changed.is_connected(_native_refresh_facts)
	):
		unit.abilities.ability_changed.connect(_native_refresh_facts)
	_native_refresh_facts()


func set_ghosted(value):
	ghosted = value
	avoidance_layers = (
		Constants.Match.Navigation.AVOIDANCE_GHOSTS
		if value
		else Constants.Match.Navigation.AVOIDANCE_UNITS
	)
	avoidance_mask = (
		Constants.Match.Navigation.AVOIDANCE_STATIC
		if value
		else Constants.Match.Navigation.AVOIDANCE_UNITS
	)
	_native_refresh_facts()


func _abilities_prevent_movement() -> bool:
	return (
		is_instance_valid(_unit)
		and _unit.abilities != null
		and _unit.abilities.is_active("siege_anchor")
	)


func move(movement_target: Vector3):
	if _abilities_prevent_movement():
		return
	if not movement_target.is_finite():
		stop()
		return
	if domain == Constants.Match.Navigation.Domain.TERRAIN and _elevated:
		# Orders often carry flattened points; aim at the ground of their own tier.
		movement_target.y = _map.height_at(Vector2(movement_target.x, movement_target.z))
	if _has_destination and target_position.distance_to(movement_target) < 0.1:
		return
	_command_revision += 1
	_has_destination = true
	target_position = movement_target
	_progress_position = get_parent().global_position
	_progress_elapsed = 0.0
	_recovery_left = 0.0
	_recovery_checked = false


func stop():
	_command_revision += 1
	_has_destination = false
	target_position = get_parent().global_position
	velocity = Vector3.ZERO
	_recovery_left = 0.0
	_recovery_checked = false
	_native_refresh_facts()


func _align_unit_position_to_navigation():
	var aligned = _navigation_position(_unit.global_position)
	aligned.y = _flight_height(aligned)
	_unit.global_position = aligned
	_sync_ground_navigation_height()
	_unit.reset_physics_interpolation()
	_ground_motion_budget(0.0, 0.0, true)


func _uses_flight_clearance():
	return domain == Constants.Match.Navigation.Domain.AIR and _map.has_method("flight_height_at")


func _flight_height(point):
	if _uses_flight_clearance():
		return _map.flight_height_at(point, point.y)
	return point.y


func _is_moving_actively():
	return _has_destination


func _finish_command(revision):
	if revision == _command_revision and not _has_destination:
		movement_finished.emit()


func _get_filtered_rotation_direction(safe_velocity: Vector3, current: Transform3D) -> Vector3:
	var direction := safe_velocity.normalized()
	if (
		_previously_set_global_transform_of_unit != null
		and not _previously_set_global_transform_of_unit.is_equal_approx(current)
	):
		# reset filter if a global_transform of unit was altered from the outside
		_rotation_low_pass_filter_window = []
		_total_direction_in_the_low_pass_filter_window = Vector3.ZERO
	if safe_velocity.length() >= ROTATION_LOW_PASS_FILTER_VELOCITY_THRESHOLD:
		_rotation_low_pass_filter_window.append(direction)
		_total_direction_in_the_low_pass_filter_window += direction
	if _rotation_low_pass_filter_window.size() > ROTATION_LOW_PASS_FILTER_WINDOW_SIZE:
		_total_direction_in_the_low_pass_filter_window -= (
			_rotation_low_pass_filter_window.pop_front()
		)
	if _rotation_low_pass_filter_window.size() == ROTATION_LOW_PASS_FILTER_WINDOW_SIZE:
		return (
			_total_direction_in_the_low_pass_filter_window
			/ float(ROTATION_LOW_PASS_FILTER_WINDOW_SIZE)
		)
	return direction


func _rotate_in_direction(direction: Vector3):
	var current := _unit.global_transform
	var facing := _oriented_transform(current, direction)
	if facing != current:
		_unit.global_transform = facing


func _oriented_transform(current: Transform3D, direction: Vector3) -> Transform3D:
	# Crowd avoidance may nudge a firing unit sideways. Aiming owns its facing
	# until it receives a movement order; tiny settling steps have no heading.
	if (
		direction.length() < ROTATION_LOW_PASS_FILTER_VELOCITY_THRESHOLD
		or (not _has_destination and is_instance_valid(_unit.aim_target))
	):
		return current
	if ROTATION_LOW_PASS_FILTER_ENABLED:
		direction = _get_filtered_rotation_direction(direction, current)
	var rotation_target := current.origin + direction
	if (
		not is_zero_approx(direction.length())
		and not rotation_target.is_equal_approx(current.origin)
	):
		return current.looking_at(rotation_target)
	return current


func _update_passive_movement_tracking(safe_velocity):
	if not PASSIVE_MOVEMENT_TRACKING_ENABLED:
		return
	if _is_moving_actively() or safe_velocity.is_zero_approx():
		if _passive_movement_detected:
			_passive_movement_detected = false
			passive_movement_finished.emit()
		return
	if not _passive_movement_detected:
		_passive_movement_detected = true
		passive_movement_started.emit()


func _on_velocity_computed(safe_velocity: Vector3):
	if not _synchronized or get_tree().paused or _unit.has_meta("garrison_host"):
		return
	if _abilities_prevent_movement():
		velocity = Vector3.ZERO
		_update_passive_movement_tracking(Vector3.ZERO)
		return
	var navigation_iteration = NavigationServer3D.map_get_iteration_id(get_navigation_map())
	if (
		safe_velocity.is_zero_approx()
		and _recovery_left <= 0
		and _previously_set_global_transform_of_unit != null
		and _previously_set_global_transform_of_unit.origin == _unit.global_position
		and navigation_iteration == _last_navigation_iteration
		and not _changing_height()
	):
		# Aiming can turn a stationary infantry root every tick. Heading alone
		# does not invalidate its ground position; teleports and rebakes still do.
		# Preserve the passive-stop notification for work actions.
		_update_passive_movement_tracking(Vector3.ZERO)
		return
	_last_navigation_iteration = navigation_iteration
	var current_speed: float = speed
	var origin: Vector3 = _unit.global_position
	if (
		domain == Constants.Match.Navigation.Domain.TERRAIN
		and not _uses_platform_height
		and not _elevated
		and origin.y > 0.01
	):
		# A restored vehicle may already be descending off a platform.
		_uses_platform_height = true
	var maximum_step: float = current_speed * _physics_delta
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		maximum_step = _ground_motion_budget(_physics_delta)
	var displacement := safe_velocity.limit_length(current_speed) * _physics_delta
	var candidate := origin + displacement
	# Local avoidance can push agents off the mesh; constrain the resulting step.
	var navigable := _navigation_position(candidate)
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		# A teleport or restored position can need several vertical steps. Zero
		# planar velocity must not freeze it above the first path waypoint.
		_ground_alignment_height = navigable.y
	var next: Vector3
	# Flight clearance follows the map without consuming horizontal movement speed.
	# Ground agents retain the existing navmesh-constrained elevation step.
	if _uses_flight_clearance():
		next = origin.move_toward(Vector3(navigable.x, origin.y, navigable.z), maximum_step)
		next.y = _flight_height(Vector3(next.x, navigable.y, next.z))
		if is_finite(settle_height):
			next.y = move_toward(origin.y, settle_height, SETTLE_RATE * _physics_delta)
			_climbing_out = true
		elif _climbing_out:
			next.y = move_toward(origin.y, next.y, SETTLE_RATE * _physics_delta)
			_climbing_out = next.y < _flight_height(next) - 0.01
	else:
		next = (
			_bounded_ground_step(origin, navigable, current_speed, maximum_step)
			if domain == Constants.Match.Navigation.Domain.TERRAIN
			else origin.move_toward(navigable, maximum_step)
		)
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		next = _clip_ground_step(next, current_speed, maximum_step)
		# A fully stalled avoidance result must not cancel a committed escape.
		# The retry retains the same navigation, body and speed constraints.
		if (
			_has_destination
			and _recovery_left > 0
			and next.distance_squared_to(origin) < 0.000001
			and not has_occupied_endpoint(false)
		):
			# Avoidance can steer an escape back into a boundary contact. Try
			# the committed recovery step with the same mesh/body constraints.
			var recovery_point = origin + velocity.limit_length(current_speed) * _physics_delta
			var recovery_nav = _navigation_position(recovery_point)
			var recovery_step = _clip_ground_step(
				_bounded_ground_step(origin, recovery_nav, current_speed, maximum_step),
				current_speed,
				maximum_step
			)
			if recovery_step.distance_squared_to(origin) > next.distance_squared_to(origin):
				next = recovery_step
		# Clipping and sliding can change XZ after projection. Ground the final
		# position on the authored surface, not the voxelized navigation mesh.
		if _elevated and not _hovering:
			next.y = _map.height_at(Vector2(next.x, next.z))
			_ground_alignment_height = next.y
		# Repair platforms are drive-on ground surfaces, including while leaving
		# a completed or cancelled recovery order. Derive height from position so
		# restored units do not need a separate docking state.
		for body in _battlefield.nearby_repair_platforms(next):
			if body.is_constructed():
				var deck_height = body.deck_height(next)
				if deck_height > 0:
					_uses_platform_height = true
				next.y = maxf(next.y, body.global_position.y + deck_height)
				_ground_alignment_height = maxf(
					_ground_alignment_height, body.global_position.y + deck_height
				)
	var travelled = (next - origin) * Vector3(1, 0, 1)
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		_ground_motion_budget(_physics_delta, travelled.length())
	var actual_velocity := (next - origin) / maxf(_physics_delta, 0.001)
	if (
		domain == Constants.Match.Navigation.Domain.TERRAIN
		and actual_velocity.distance_to(safe_velocity) > 0.1
	):
		# Projection can prevent an avoidance step at a navigation boundary.
		# Neighbors must predict the movement that actually happened, otherwise
		# they keep yielding toward a gap that the constrained unit cannot enter.
		set_velocity_forced(actual_velocity)
	# Publish position and facing together. Two writes propagate two transform
	# changes through the unit's descendants and its server instances.
	var current := _unit.global_transform
	var advanced := current
	advanced.origin = next
	advanced = _oriented_transform(advanced, actual_velocity * Vector3(1, 0, 1))
	if advanced != current:
		_unit.global_transform = advanced
	_sync_ground_navigation_height()
	_previously_set_global_transform_of_unit = advanced
	_update_passive_movement_tracking(actual_velocity)


func _bounded_ground_step(
	origin: Vector3, point: Vector3, current_speed: float, maximum_planar: float
) -> Vector3:
	# Clearance/grounding keeps its original vertical step even when contacts
	# have consumed this frame's horizontal travel allowance.
	var result = origin.move_toward(point, current_speed * _physics_delta)
	if maximum_planar >= current_speed * _physics_delta:
		return result
	var horizontal = ((result - origin) * Vector3(1, 0, 1)).limit_length(maximum_planar)
	result.x = origin.x + horizontal.x
	result.z = origin.z + horizontal.z
	return result


func _clip_ground_step(next: Vector3, current_speed: float, maximum_step = -1.0) -> Vector3:
	var origin: Vector3 = _unit.global_position
	# The contact solver accepts a negligible planar step unchanged. Avoid
	# building a neighbor list for that same no-op (including elevation only).
	if (
		ghosted
		or _battlefield == null
		or ((next - origin) * Vector3(1, 0, 1)).length_squared() < 0.00000001
	):
		return next
	var reach: float = (
		radius
		+ Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
		+ current_speed * _physics_delta
		+ .25
	)
	var neighbors = _battlefield.nearby_units(origin, reach)
	var contact := _ground_contact(origin, next, neighbors)
	if contact.w >= 1.0:
		return next
	var clipped := origin.lerp(next, contact.w)
	# Preserve the tangential part of a blocked step. Clamping alone can pin
	# two agents together at a mesh boundary even when there is room to pass.
	var step := (next - origin) * Vector3(1, 0, 1)
	var normal := Vector3(contact.x, contact.y, contact.z)
	var slide := step - normal * minf(0.0, step.dot(normal))
	var navigable := _navigation_position(origin + slide)
	var allowance = current_speed * _physics_delta if maximum_step < 0 else maximum_step
	var alternative := _bounded_ground_step(origin, navigable, current_speed, allowance)
	var slide_contact := _ground_contact(origin, alternative, neighbors)
	alternative = origin.lerp(alternative, slide_contact.w)
	if alternative.distance_squared_to(origin) > clipped.distance_squared_to(origin):
		return alternative
	return clipped


func _ground_step_contact(origin: Vector3, next: Vector3, neighbors: Array) -> Dictionary:
	var contact := _ground_contact(origin, next, neighbors)
	return {"fraction": contact.w, "normal": Vector3(contact.x, contact.y, contact.z)}


func _ground_contact(origin: Vector3, next: Vector3, neighbors: Array) -> Vector4:
	var native = _battlefield._native_queries if _match != null and _battlefield != null else null
	if native != null:
		return native.ground_contact(
			origin, next, neighbors, _unit, domain, float(radius), GROUND_CONTACT_MARGIN
		)
	return _ground_contact_script(origin, next, neighbors)


func _ground_contact_script(origin: Vector3, next: Vector3, neighbors: Array) -> Vector4:
	# The hot path returns a value (normal.xyz, fraction.w), avoiding a heap
	# dictionary and string-key lookups for every step and candidate collision.
	var step := (next - origin) * Vector3(1, 0, 1)
	var length_squared := step.length_squared()
	var best_fraction := 1.0
	var best_normal := Vector3.ZERO
	if length_squared < 0.00000001:
		return Vector4(0, 0, 0, 1)
	var own_radius: float = radius
	for candidate in neighbors:
		var other: Unit = candidate
		if other == _unit:
			continue
		var offset: Vector3 = (origin - other.global_position) * Vector3(1, 0, 1)
		var toward := offset.dot(step)
		# Receding or tangential motion cannot make a new contact, regardless
		# of the neighbor's live domain, radius, ghost state or speed modifiers.
		if toward >= 0:
			continue
		# Read the neighbor's trait once instead of resolving radius, speed and
		# domain through three separate unit property getters for every contact.
		var movement = other._get_navigation_trait()
		if (
			not movement is NavigationAgent3D
			or movement.domain != domain
			or movement.speed <= 0
			or movement.ghosted
		):
			continue
		var separation: float = own_radius + movement.radius - GROUND_CONTACT_MARGIN
		var outside := offset.length_squared() - separation * separation
		var fraction := 0.0
		if outside > 0:
			var discriminant := toward * toward - length_squared * outside
			if discriminant < 0:
				continue
			fraction = (-toward - sqrt(discriminant)) / length_squared
		if fraction >= 0 and fraction < best_fraction:
			best_fraction = fraction
			best_normal = offset.normalized()
	return Vector4(best_normal.x, best_normal.y, best_normal.z, best_fraction)


func _sync_ground_navigation_height():
	if _hovering:
		path_height_offset = (
			_closest_navigation_point(_unit.global_position).y - _unit.global_position.y
		)
		return
	if (
		domain == Constants.Match.Navigation.Domain.TERRAIN
		and (_elevated or _uses_platform_height)
		and not _hovering
	):
		# Offset path waypoints by the local bake lift. A fixed offset can leave
		# a grounded body outside the waypoint's vertical arrival tolerance.
		path_height_offset = (
			_closest_navigation_point(_unit.global_position).y - _unit.global_position.y
		)


func _hover_height(point: Vector3) -> float:
	return hover_body_height(_map, point)


static func hover_body_height(map, point: Vector3) -> float:
	var height = map.height_at(Vector2(point.x, point.z))
	var terrain = map.get("terrain")
	if terrain != null:
		var flags = terrain.flag_at(Vector2(point.x, point.z))
		if flags & terrain.WATER:
			height += terrain.WATER_DEPTH
		elif flags & terrain.FORD:
			height += terrain.FORD_DEPTH
		elif flags & terrain.SOLID:
			var column = clampi(floori(point.x / terrain.RESOLUTION), 0, terrain.columns - 1)
			var row = clampi(floori(point.z / terrain.RESOLUTION), 0, terrain.rows - 1)
			height = maxf(height, terrain.cover_tops[row * terrain.columns + column])
	return height + .16


func _navigation_position(point: Vector3) -> Vector3:
	if _hovering:
		var projected = NavigationServer3D.map_get_closest_point(
			get_navigation_map(), point * Vector3(1, 0, 1)
		)
		projected.y = _hover_height(projected)
		return projected
	var position := _closest_navigation_point(point)
	position.y -= path_height_offset
	if domain == Constants.Match.Navigation.Domain.TERRAIN and (_elevated or _uses_platform_height):
		position.y = _map.height_at(Vector2(position.x, position.z))
	return position


func project_command_point(point: Vector3) -> Vector3:
	# Commands share the same published surface and terrain projection as live
	# native steering. The runtime validates its map iteration before querying.
	if _native_runtime != null and _native_handle >= 0 and _synchronized:
		return _native_runtime.project_point(point, _native_handle)
	return _closest_navigation_point(point)


func _closest_navigation_point(point: Vector3) -> Vector3:
	if _hovering:
		return NavigationServer3D.map_get_closest_point(
			get_navigation_map(), point * Vector3(1, 0, 1)
		)
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		var terrain: TerrainNavigation = _terrain_navigation
		if _elevated:
			# Projection and final waypoint-height alignment often query the same
			# XZ twice in one tick. Elevated projection deliberately ignores input Y.
			var frame = Engine.get_physics_frames()
			var iteration = NavigationServer3D.map_get_iteration_id(terrain.navigation_map_rid)
			var flat = Vector2(point.x, point.z)
			if (
				_projection_frame == frame
				and _projection_iteration == iteration
				and _projection_point == flat
			):
				return _projection_result
			_projection_result = terrain.closest_point(point, _projection_hint)
			_projection_frame = frame
			_projection_iteration = iteration
			_projection_point = flat
			return _projection_result
		return terrain.closest_point(point, _projection_hint)
	return NavigationServer3D.map_get_closest_point(get_navigation_map(), point)
