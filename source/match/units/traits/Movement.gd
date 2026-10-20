extends NavigationAgent3D

signal movement_finished
signal passive_movement_started
signal passive_movement_finished

const Unit = preload("res://source/match/units/Unit.gd")

const PROGRESS_WINDOW = 1.0
const MINIMUM_PROGRESS = 0.2
const RECOVERY_DURATION = 0.6
const GROUND_RECOVERY_DURATION = 2.0
const GROUND_RECOVERY_DISTANCE = 2.0
const GROUND_CONTACT_MARGIN = .02
# Vertical speed of rotorcraft settling onto or lifting off a helipad.
const SETTLE_RATE = 1.2

const ROTATION_LOW_PASS_FILTER_ENABLED = true
const ROTATION_LOW_PASS_FILTER_WINDOW_SIZE = 10  # number of frames for accumulating directions
const ROTATION_LOW_PASS_FILTER_VELOCITY_THRESHOLD = 0.01  # velocities below will be dropped

const PASSIVE_MOVEMENT_TRACKING_ENABLED = true

@export var domain = Constants.Match.Navigation.Domain.TERRAIN
# Rotorcraft and drones accelerate and brake at this rate instead of snapping
# to full speed (metres per second squared). Ground units are unaffected.
@export var air_acceleration = 7.0
@export var speed: float = 4.0:
	get:
		var factor = (
			_unit.signature.speed_factor()
			if is_instance_valid(_unit) and _unit.signature != null
			else 1.0
		)
		return speed * factor

# Rotorcraft settle onto a helipad deck at this height, then climb back out.
var settle_height = INF
# A harvest run passes through other ground units in both directions. Terrain,
# structures and deposits still constrain it through the navmesh and obstacles.
var ghosted = false:
	set = set_ghosted

var _exit_clearance_target = Vector3.INF
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

@onready var _match = find_parent("Match")
@onready var _unit: Unit = get_parent()


func _physics_process(delta):
	_physics_delta = delta
	var current_speed: float = speed
	if max_speed != current_speed:
		max_speed = current_speed
	# A settled firing line holds its ground while arriving allies flow around it.
	# Equal avoidance priority lets the rear ranks push shooters toward the enemy.
	var priority := 0.8 if not _has_destination and is_instance_valid(_unit.aim_target) else 0.5
	if avoidance_priority != priority:
		avoidance_priority = priority
	if _advance_exit_clearance(delta):
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
		velocity = _air_inertia(direction * minf(speed, braking), delta)
	else:
		velocity = direction * min(speed, offset.length() / delta)


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


func _advance_exit_clearance(delta):
	if not _exit_clearance_target.is_finite():
		return false
	var offset = (_exit_clearance_target - _unit.global_position) * Vector3(1, 0, 1)
	if offset.length() < .15 or _match.simulation_time >= _exit_clearance_until:
		_exit_clearance_target = Vector3.INF
		return false
	# This is a short avoidance maneuver, not a new order. Keep the navigation
	# destination, action and queued orders intact.
	velocity = offset.normalized() * minf(speed, offset.length() / delta)
	return true


func has_occupied_endpoint(require_short_route = true):
	var path = get_current_navigation_path()
	if path.is_empty():
		return false
	var end: Vector3 = path[-1] * Vector3(1, 0, 1)
	# A settled mobile body can only finish this order within contact range.
	# Most recovering units are farther away; avoid scanning their destination
	# neighbors (and the remaining path) until arrival is actually possible.
	var contact_bound: float = radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + .2
	if _unit.global_position_yless.distance_squared_to(end) > contact_bound * contact_bound:
		return false
	var remaining = 0.0
	if require_short_route:
		# A nearby endpoint can sit just beyond a tiny polygon bend. Bound
		# actual remaining travel instead of requiring a particular path index;
		# an endpoint across a wall still requires its full remaining route.
		var previous = _unit.global_position_yless
		for index in range(get_current_navigation_path_index(), path.size()):
			var point = path[index] * Vector3(1, 0, 1)
			remaining += previous.distance_to(point)
			previous = point
	# A plain point order can finish beside a settled ally occupying its final
	# reachable position. MovingToUnit owns its own process/contact checks.
	for other in _match.battlefield.nearby_bodies(end, _unit.radius, _unit.player):
		if (
			other == _unit
			or not other.is_in_group("units")
			or other.is_queued_for_deletion()
			or other.hp <= 0
			or other.movement_speed <= 0
			or other.movement_domain != _unit.movement_domain
		):
			continue
		var movement = other.get_node_or_null("Movement")
		if (
			movement == null
			or movement.ghosted
			or movement._has_destination
			or movement.velocity.length_squared() >= 0.01
		):
			continue
		var spacing = _unit.radius + other.radius
		if (
			other.global_position_yless.distance_to(end) < spacing
			and _unit.global_position_yless.distance_to(end) <= spacing + 0.2
			and (not require_short_route or remaining <= spacing + 0.2)
		):
			return true
	return false


func _ground_recovery_direction(path_direction):
	var best = path_direction.rotated(Vector3.UP, PI / 2.0)
	var clearance = -1.0
	var free_distance = -1.0
	var origin = _unit.global_position
	var neighbors = []
	if _match.battlefield != null and not ghosted:
		neighbors = _match.battlefield.nearby_units(
			origin,
			(
				_unit.radius
				+ Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
				+ GROUND_RECOVERY_DISTANCE
				+ .25
			)
		)
	for angle in [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, 3 * PI / 4.0, -3 * PI / 4.0, PI]:
		# Prefer a side route when the whole escape is clear. A terrain-clear
		# ray with only centimetres before body contact must not hide a usable
		# backward escape.
		if absf(angle) > PI / 2.0 and free_distance >= GROUND_RECOVERY_DISTANCE:
			break
		var candidate = path_direction.rotated(Vector3.UP, angle)
		var distance = _recovery_clearance(candidate)
		var contact = _ground_step_contact(origin, origin + candidate * distance, neighbors)
		var free = distance * contact.fraction
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
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		# Near-collinear mesh portals can pin avoidance to an unnecessary point
		# inside a neighbor. Remove them without broadening arrival tolerances.
		simplify_path = true
		simplify_epsilon = .01
	set_physics_process(false)
	if _match.navigation == null:
		await _match.ready
	await _match.navigation.wait_until_synchronized(domain)
	set_navigation_map(_match.navigation.get_navigation_map_rid_by_domain(domain))
	_align_unit_position_to_navigation()
	velocity_computed.connect(_on_velocity_computed)
	_progress_position = _unit.global_position
	_synchronized = true
	# Preserve orders received while the navigation server was synchronizing.
	if not _has_destination:
		target_position = _unit.global_position
	set_physics_process(true)


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


func move(movement_target: Vector3):
	if not movement_target.is_finite():
		stop()
		return
	if domain == Constants.Match.Navigation.Domain.TERRAIN and _match.map.is_elevated():
		# Orders often carry flattened points; aim at the ground of their own tier.
		movement_target.y = _match.map.height_at(Vector2(movement_target.x, movement_target.z))
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


func _align_unit_position_to_navigation():
	var aligned = (
		NavigationServer3D.map_get_closest_point(get_navigation_map(), _unit.global_position)
		- Vector3(0, path_height_offset, 0)
	)
	aligned.y = _flight_height(aligned)
	_unit.global_position = aligned
	_unit.reset_physics_interpolation()


func _uses_flight_clearance():
	return (
		domain == Constants.Match.Navigation.Domain.AIR
		and _match.map.has_method("flight_height_at")
	)


func _flight_height(point):
	if _uses_flight_clearance():
		return _match.map.flight_height_at(point, point.y)
	return point.y


func _is_moving_actively():
	return _has_destination


func _finish_command(revision):
	if revision == _command_revision and not _has_destination:
		movement_finished.emit()


func _get_filtered_rotation_direction(safe_velocity: Vector3):
	var direction = safe_velocity.normalized()
	if (
		_previously_set_global_transform_of_unit != null
		and not _previously_set_global_transform_of_unit.is_equal_approx(_unit.global_transform)
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
	if ROTATION_LOW_PASS_FILTER_ENABLED:
		direction = _get_filtered_rotation_direction(direction)
	var rotation_target = _unit.global_transform.origin + direction
	if (
		not is_zero_approx(direction.length())
		and not rotation_target.is_equal_approx(_unit.global_transform.origin)
	):
		_unit.global_transform = _unit.global_transform.looking_at(rotation_target)


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
	var navigation_iteration = NavigationServer3D.map_get_iteration_id(get_navigation_map())
	if (
		safe_velocity.is_zero_approx()
		and _previously_set_global_transform_of_unit == _unit.global_transform
		and navigation_iteration == _last_navigation_iteration
		and not _changing_height()
	):
		# Already aligned and untouched: a stationary body needs no navmesh or
		# neighbor query. Preserve the passive-stop notification for work actions.
		_update_passive_movement_tracking(Vector3.ZERO)
		return
	_last_navigation_iteration = navigation_iteration
	var current_speed: float = speed
	var displacement := safe_velocity.limit_length(current_speed) * _physics_delta
	var candidate := _unit.global_position + displacement
	# Local avoidance can push agents off the mesh; constrain the resulting step.
	var navigable := _closest_navigation_point(candidate)
	navigable.y -= path_height_offset
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		# A teleport or restored position can need several vertical steps. Zero
		# planar velocity must not freeze it above the first path waypoint.
		_ground_alignment_height = navigable.y
	var next := _unit.global_position.move_toward(
		Vector3(navigable.x, _unit.global_position.y, navigable.z), current_speed * _physics_delta
	)
	# Flight clearance follows the map without consuming horizontal movement speed.
	# Ground agents retain the existing navmesh-constrained elevation step.
	if _uses_flight_clearance():
		next.y = _flight_height(Vector3(next.x, navigable.y, next.z))
		if is_finite(settle_height):
			next.y = move_toward(
				_unit.global_position.y, settle_height, SETTLE_RATE * _physics_delta
			)
			_climbing_out = true
		elif _climbing_out:
			next.y = move_toward(_unit.global_position.y, next.y, SETTLE_RATE * _physics_delta)
			_climbing_out = next.y < _flight_height(next) - 0.01
	else:
		next = _unit.global_position.move_toward(navigable, current_speed * _physics_delta)
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		next = _clip_ground_step(next)
		# Only retry when mesh projection displaced avoidance and the final
		# step was under one millimetre; ordinary body yielding stays intact.
		if (
			_has_destination
			and _recovery_left > 0
			and not has_occupied_endpoint(false)
			and ((navigable - candidate) * Vector3(1, 0, 1)).length_squared() > 0.000001
			and next.distance_squared_to(_unit.global_position) < 0.000001
		):
			# Avoidance can steer an escape back into a boundary contact. Try
			# the committed recovery step with the same mesh/body constraints.
			var recovery_point = (
				_unit.global_position + velocity.limit_length(current_speed) * _physics_delta
			)
			var recovery_nav = _closest_navigation_point(recovery_point)
			recovery_nav.y -= path_height_offset
			var recovery_step = _clip_ground_step(
				_unit.global_position.move_toward(recovery_nav, current_speed * _physics_delta)
			)
			if (
				recovery_step.distance_squared_to(_unit.global_position)
				> next.distance_squared_to(_unit.global_position)
			):
				next = recovery_step
	var actual_velocity := (next - _unit.global_position) / maxf(_physics_delta, 0.001)
	if (
		domain == Constants.Match.Navigation.Domain.TERRAIN
		and actual_velocity.distance_to(safe_velocity) > 0.1
	):
		# Projection can prevent an avoidance step at a navigation boundary.
		# Neighbors must predict the movement that actually happened, otherwise
		# they keep yielding toward a gap that the constrained unit cannot enter.
		set_velocity_forced(actual_velocity)
	_unit.global_position = next
	_rotate_in_direction(actual_velocity * Vector3(1, 0, 1))
	_previously_set_global_transform_of_unit = _unit.global_transform
	_update_passive_movement_tracking(actual_velocity)


func _clip_ground_step(next: Vector3) -> Vector3:
	var origin: Vector3 = _unit.global_position
	# The contact solver accepts a negligible planar step unchanged. Avoid
	# building a neighbor list for that same no-op (including elevation only).
	if (
		ghosted
		or _match.battlefield == null
		or ((next - origin) * Vector3(1, 0, 1)).length_squared() < 0.00000001
	):
		return next
	var reach: float = (
		radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + speed * _physics_delta + .25
	)
	var neighbors = _match.battlefield.nearby_units(origin, reach)
	var contact = _ground_step_contact(origin, next, neighbors)
	if contact.fraction >= 1.0:
		return next
	var clipped := origin.lerp(next, contact.fraction)
	# Preserve the tangential part of a blocked step. Clamping alone can pin
	# two agents together at a mesh boundary even when there is room to pass.
	var step := (next - origin) * Vector3(1, 0, 1)
	var normal: Vector3 = contact.normal
	var slide := step - normal * minf(0.0, step.dot(normal))
	var navigable := _closest_navigation_point(origin + slide)
	navigable.y -= path_height_offset
	var alternative := origin.move_toward(navigable, speed * _physics_delta)
	var slide_contact = _ground_step_contact(origin, alternative, neighbors)
	alternative = origin.lerp(alternative, slide_contact.fraction)
	if alternative.distance_squared_to(origin) > clipped.distance_squared_to(origin):
		return alternative
	return clipped


func _ground_step_contact(origin: Vector3, next: Vector3, neighbors: Array) -> Dictionary:
	var step := (next - origin) * Vector3(1, 0, 1)
	var length_squared := step.length_squared()
	var result = {"fraction": 1.0, "normal": Vector3.ZERO}
	if length_squared < 0.00000001:
		return result
	var own_radius: float = radius
	for candidate in neighbors:
		var other: Unit = candidate
		if other == _unit:
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
		var offset: Vector3 = (origin - other.global_position) * Vector3(1, 0, 1)
		var separation: float = own_radius + movement.radius - GROUND_CONTACT_MARGIN
		var outside := offset.length_squared() - separation * separation
		var toward := offset.dot(step)
		if toward >= 0:
			continue
		var fraction := 0.0
		if outside > 0:
			var discriminant := toward * toward - length_squared * outside
			if discriminant < 0:
				continue
			fraction = (-toward - sqrt(discriminant)) / length_squared
		if fraction >= 0 and fraction < result.fraction:
			result.fraction = fraction
			result.normal = offset.normalized()
	return result


func _closest_navigation_point(point: Vector3) -> Vector3:
	if domain == Constants.Match.Navigation.Domain.TERRAIN:
		return _match.navigation.terrain.closest_point(point)
	return NavigationServer3D.map_get_closest_point(get_navigation_map(), point)
