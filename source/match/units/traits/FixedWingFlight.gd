# gdlint: disable=max-returns,max-file-lines
extends "res://source/match/units/traits/Movement.gd"

# Fixed-wing flight. Keeps the Movement contract that actions and systems rely
# on (move/stop, _has_destination, target_position, velocity, movement_finished)
# but replaces navigation with a point-mass flight model:
#   - airspeed between stall and cruise; jets never hover
#   - coordinated turns: turn rate = g * tan(bank) / airspeed, bank limited and
#     rolled in at a finite rate
#   - limited climb and sink; terrain clearance from the map
#   - explicit ground phases: taxi on the airfield, take-off roll, landing
#     approach on a glide slope with flare, rollout and taxi back to a stand
# Missions: hold a station (banked orbit), strike a target, or return to base.

enum Phase { PARKED, TAXI, TAKEOFF, AIRBORNE, APPROACH, ROLLOUT }

const GRAVITY = 9.8
const TURN_GAIN = 2.6
const TAXI_TURN_RATE = 2.2
const FINAL_LENGTH = 13.0
const FLARE_HEIGHT = 0.45
const LIFT_OFF_HEIGHT = 1.2
const MAP_MARGIN = 3.0
# Aircraft may manoeuvre this far beyond the playable edge (over the backdrop).
const AIRSPACE_MARGIN = 6.0
const OUTER_FIX = 7.0
const NO_AIRFIELD_RETRY = 2.0

@export var cruise_speed = 9.0
@export var stall_speed = 4.5
@export var rotate_speed = 5.5
@export var takeoff_acceleration = 3.2
@export var acceleration = 2.5
@export var braking = 4.0
@export var max_bank = 1.05
@export var roll_rate = 2.4
@export var climb_rate = 2.4
@export var sink_rate = 2.6
@export var cruise_height = 5.0
@export var taxi_speed = 2.6
@export var orbit_radius = 7.0
@export var glide_slope = 0.18

var phase = Phase.AIRBORNE
var heading = 0.0
var airspeed = 0.0
var bank = 0.0
var pitch = 0.0
var vertical_speed = 0.0
var mode = "station"
var station = Vector3.INF
var strike_target = null
var airfield = null
var stand = -1
var orbit_sign = 1
var ordered = false
var go_arounds = 0
var _route = []
var _route_after = ""
var _approach_entry = false
var _landing_end = -1
var _arrived = false
var _airfield_retry = 0.0
var _restored_state = false


func _ready():
	avoidance_enabled = false
	set_physics_process(false)
	if _match.navigation == null:
		await _match.ready
	if not _unit.is_node_ready():
		await _unit.ready
	heading = _heading_of(-_unit.global_basis.z)
	# A restored aircraft receives its saved flight state instead.
	if not _restored_state and not _match.restoring:
		_settle_on_spawn()
	_synchronized = true
	set_physics_process(true)


# Production places a new aircraft on a stand of the nearest friendly airfield;
# anything else (scenario spawns, older saves) starts airborne at its position.
func _settle_on_spawn():
	var field = _nearest_airfield(_unit.global_position, 14.0)
	if field != null and field.claim_stand(_unit) >= 0:
		_park_at(field, field.stand_of(_unit))
		station = Vector3.INF
		mode = "idle"
		return
	phase = Phase.AIRBORNE
	airspeed = cruise_speed
	var point = _unit.global_position
	point.y = _cruise_height_at(point)
	_unit.global_position = point
	station = point
	mode = "station"
	_publish()


func _park_at(field, index):
	airfield = field
	stand = index
	phase = Phase.PARKED
	airspeed = 0.0
	vertical_speed = 0.0
	bank = 0.0
	var point = field.stand_point(index)
	point.y = _ground_height(point)
	_unit.global_position = point
	heading = _heading_of(field.stand_direction())
	_publish()
	_unit.reset_physics_interpolation()


# --- Commands -----------------------------------------------------------------


func move(movement_target: Vector3):
	fly_station(movement_target)


func stop():
	_command_revision += 1
	_has_destination = false
	if is_airborne():
		station = _clamp_to_map(_unit.global_position)
		mode = "station"
	elif mode != "return":
		mode = "idle"
	strike_target = null


func fly_station(point, by_order = true):
	_command_revision += 1
	station = _clamp_to_map(point)
	target_position = station
	_has_destination = true
	_arrived = false
	mode = "station"
	strike_target = null
	ordered = by_order


func strike(target):
	_command_revision += 1
	strike_target = target
	mode = "strike"
	ordered = true
	_has_destination = true


func return_to_base():
	_command_revision += 1
	mode = "return"
	strike_target = null
	_has_destination = true


func idle():
	if mode == "strike":
		mode = "station" if station.is_finite() else "idle"
	strike_target = null
	ordered = false
	_has_destination = false


func arrived():
	return _arrived


func is_airborne():
	return (
		phase in [Phase.AIRBORNE, Phase.APPROACH]
		or (phase == Phase.TAKEOFF and height_above_ground() > 0.3)
	)


func on_ground():
	return not is_airborne()


func is_parked():
	return phase == Phase.PARKED


func height_above_ground():
	return _unit.global_position.y - _ground_height(_unit.global_position)


func flight_velocity():
	return _forward() * airspeed + Vector3.UP * vertical_speed


func cancel_exit_clearance():
	pass


func request_exit_clearance(_point):
	pass


func has_occupied_endpoint(_require_short_route = true):
	return false


# --- Simulation ---------------------------------------------------------------


func _physics_process(delta):
	_physics_delta = delta
	if not _synchronized:
		return
	match phase:
		Phase.PARKED:
			_parked(delta)
		Phase.TAXI:
			_taxi(delta)
		Phase.TAKEOFF:
			_takeoff(delta)
		Phase.AIRBORNE:
			_fly(delta)
		Phase.APPROACH:
			_approach(delta)
		Phase.ROLLOUT:
			_rollout(delta)
	_publish()


func _parked(delta):
	airspeed = 0.0
	vertical_speed = 0.0
	bank = move_toward(bank, 0.0, roll_rate * delta)
	if not _valid_airfield() or mode in ["idle", "return"]:
		if not _valid_airfield():
			# Our airfield is gone: an aircraft cannot stay parked on rubble.
			# Preserve an ordered sortie; idle/returning aircraft seek another
			# home once airborne instead of discarding their return command.
			if mode in ["idle", "return"]:
				mode = "return"
			_depart_without_runway()
		return
	if _unit.sortie_ready(ordered):
		_route = airfield.taxi_out_route(stand)
		_route_after = "takeoff"
		phase = Phase.TAXI


# A stranded aircraft (airfield destroyed while parked) lifts off in place.
func _depart_without_runway():
	phase = Phase.TAKEOFF
	airspeed = rotate_speed


func _taxi(delta):
	if not _valid_airfield():
		_depart_without_runway()
		return
	vertical_speed = 0.0
	bank = move_toward(bank, 0.0, roll_rate * delta)
	if _route.is_empty():
		_finish_taxi(delta)
		return
	var point = _route[0]
	var offset = (point - _unit.global_position) * Vector3(1, 0, 1)
	if offset.length() < 0.2:
		_route.pop_front()
		return
	var error = _turn_on_ground(_heading_of(offset), delta)
	var wanted = taxi_speed * (0.25 if absf(error) > 0.6 else 1.0)
	if _taxi_blocked():
		wanted = 0.0
	airspeed = move_toward(airspeed, minf(wanted, offset.length() / delta), braking * delta)
	_advance_ground(delta)


func _finish_taxi(delta):
	airspeed = 0.0
	if _route_after == "takeoff":
		var error = _turn_on_ground(_heading_of(airfield.runway_direction()), delta)
		if absf(error) < 0.05 and airfield.take_runway(_unit):
			phase = Phase.TAKEOFF
		return
	var error = _turn_on_ground(_heading_of(airfield.stand_direction()), delta)
	if absf(error) < 0.05:
		phase = Phase.PARKED
		if mode == "return":
			mode = "idle"
			_has_destination = false
		_unit.landed()


func _taxi_blocked():
	var ahead = _forward()
	for other in _match.battlefield.nearby_units(
		_unit.global_position * Vector3(1, 0, 1), 1.7, _unit.player
	):
		if other == _unit or not other.has_node("Movement"):
			continue
		var flight = other.get_node("Movement")
		if not flight.has_method("on_ground") or not flight.on_ground():
			continue
		var offset = (other.global_position - _unit.global_position) * Vector3(1, 0, 1)
		# Only yield to aircraft in front; the rear one waits, never both.
		if offset.length() < 1.6 and offset.normalized().dot(ahead) > 0.5:
			return true
	return false


func _takeoff(delta):
	if _valid_airfield():
		heading = _turn_toward_heading(_heading_of(airfield.runway_direction()), delta)
	bank = move_toward(bank, 0.0, roll_rate * delta)
	airspeed = minf(cruise_speed, airspeed + takeoff_acceleration * delta)
	if airspeed >= rotate_speed:
		vertical_speed = move_toward(vertical_speed, climb_rate, climb_rate * 2.0 * delta)
	_advance(delta)
	var ground = _ground_height(_unit.global_position)
	if _unit.global_position.y < ground:
		_unit.global_position.y = ground
	if height_above_ground() >= LIFT_OFF_HEIGHT:
		if _valid_airfield():
			airfield.release_runway(_unit)
		phase = Phase.AIRBORNE
		_unit.became_airborne()


func _fly(delta):
	var goal = _airborne_goal(delta)
	# The approach took over this tick (or aborted straight into a go-around).
	if goal.is_empty() or phase != Phase.AIRBORNE:
		return
	_steer(goal.heading, delta)
	airspeed = move_toward(airspeed, maxf(stall_speed, goal.speed), acceleration * delta)
	var target_height = goal.get("height", _cruise_height_at(_unit.global_position))
	vertical_speed = clampf((target_height - _unit.global_position.y) * 1.5, -sink_rate, climb_rate)
	_advance(delta)


func _airborne_goal(delta):
	var position = _unit.global_position
	if _outside_map(position):
		return {"heading": _bearing(position, _map_center()), "speed": cruise_speed}
	match mode:
		"strike":
			if _valid_target(strike_target):
				var point = _unit.strike_point(strike_target)
				return {"heading": _bearing(position, point), "speed": cruise_speed}
			mode = "station" if station.is_finite() else "return"
		"return":
			return _return_goal(delta)
		"idle":
			if not station.is_finite():
				station = _clamp_to_map(position)
	if not station.is_finite():
		station = _clamp_to_map(position)
	return {"heading": _orbit_heading(station, orbit_radius), "speed": cruise_speed}


func _orbit_heading(center, radius):
	var offset = (_unit.global_position - center) * Vector3(1, 0, 1)
	var distance = offset.length()
	if distance > radius * 2.0 or distance < 0.01:
		if distance <= radius + 1.0 and not _arrived:
			_mark_arrived()
		return _bearing(_unit.global_position, center)
	if not _arrived and distance <= radius + 1.0:
		_mark_arrived()
	var inward = -offset / distance
	var tangent = inward.rotated(Vector3.UP, -orbit_sign * PI / 2.0)
	var correction = inward * clampf((distance - radius) / radius * 1.4, -0.9, 0.9)
	return _heading_of(tangent + correction)


func _mark_arrived():
	_arrived = true
	if mode == "station" and _has_destination:
		_has_destination = false
		_finish_command.call_deferred(_command_revision)


func _return_goal(delta):
	if not _valid_airfield() or stand < 0 or airfield.stand_of(_unit) != stand:
		_airfield_retry -= delta
		if _airfield_retry <= 0.0:
			_airfield_retry = NO_AIRFIELD_RETRY
			_find_home()
	if not _valid_airfield() or stand < 0:
		# Nowhere to land: hold where we are until a stand frees up.
		if not station.is_finite():
			station = _clamp_to_map(_unit.global_position)
		return {"heading": _orbit_heading(station, orbit_radius), "speed": cruise_speed}
	if _landing_end < 0:
		_landing_end = _choose_landing_end()
	var threshold = airfield.landing_threshold(_landing_end)
	var direction = airfield.landing_direction(_landing_end)
	var outer = threshold - direction * (FINAL_LENGTH + OUTER_FIX)
	var position = _unit.global_position
	# A fix inside the turning circle can never be reached; capture it at a
	# distance scaled by the aircraft's own minimum turn radius.
	var capture = maxf(3.5, turn_radius() * 1.3 + 1.0)
	if not _approach_entry and _flat(position - outer).length() < capture:
		_approach_entry = true
	if _approach_entry:
		if airfield.take_runway(_unit):
			# Centerline guidance captures the final course from any heading.
			phase = Phase.APPROACH
			_approach(delta)
			return {}
		# Runway busy: hold in a racetrack-sized orbit around the outer fix.
		return {
			"heading": _orbit_heading(outer, capture + 1.5),
			"speed": _approach_speed() * 1.15,
			"height": _ground_height(position) + (FINAL_LENGTH + OUTER_FIX) * glide_slope,
		}
	return {
		"heading": _bearing(position, outer),
		"speed": lerpf(cruise_speed, _approach_speed(), 0.5),
		"height":
		(
			_ground_height(position)
			+ maxf(cruise_height * 0.6, (FINAL_LENGTH + OUTER_FIX) * glide_slope)
		),
	}


# Radius of the tightest coordinated turn at the current airspeed.
func turn_radius():
	return maxf(airspeed, stall_speed) ** 2 / (GRAVITY * tan(max_bank))


func _approach(delta):
	if not _valid_airfield():
		_go_around()
		return
	var threshold = airfield.landing_threshold(_landing_end)
	var direction = airfield.landing_direction(_landing_end)
	var position = _unit.global_position
	var relative = _flat(position - threshold)
	var along = relative.dot(direction)
	var left = direction.rotated(Vector3.UP, PI / 2.0)
	var lateral = relative.dot(left)
	var drift = _forward().dot(left) * airspeed
	var to_touchdown = -along
	# Fly the extended centerline. Steering on the predicted offset (offset plus
	# its rate) damps the capture so the aircraft settles instead of weaving.
	var correction = clampf(atan((lateral + drift * 0.55) * 0.5), -0.6, 0.6)
	_steer(_heading_of(direction) - correction, delta)
	airspeed = move_toward(airspeed, _approach_speed(), acceleration * delta)
	var ground = _ground_height(position)
	var height = position.y - ground
	var glide = ground + maxf(0.0, to_touchdown) * glide_slope
	# Clear landmarks under the approach path, then steepen onto the glide slope.
	if to_touchdown > 2.0 and _match.map != null and _match.map.has_method("flight_height_at"):
		var clearance = _match.map.flight_height_at(position, ground)
		if clearance > ground + 0.3:
			glide = maxf(glide, clearance)
	if height <= FLARE_HEIGHT and to_touchdown < 3.0:
		vertical_speed = move_toward(vertical_speed, -0.35, 4.0 * delta)
	else:
		vertical_speed = clampf((glide - position.y) * 2.0, -sink_rate, climb_rate * 0.5)
	if (
		(to_touchdown < 4.0 and (absf(lateral) > 1.6 or height > 2.4))
		or along > airfield.runway_length() * 0.5
	):
		_go_around()
		return
	_advance(delta)
	if _unit.global_position.y <= _ground_height(_unit.global_position):
		_unit.global_position.y = _ground_height(_unit.global_position)
		vertical_speed = 0.0
		bank = 0.0
		phase = Phase.ROLLOUT


func _go_around():
	go_arounds += 1
	if _valid_airfield():
		airfield.release_runway(_unit)
	_approach_entry = false
	_landing_end = -1
	phase = Phase.AIRBORNE
	vertical_speed = climb_rate


func _rollout(delta):
	bank = 0.0
	vertical_speed = 0.0
	if not _valid_airfield():
		phase = Phase.TAKEOFF
		return
	var direction = airfield.landing_direction(_landing_end)
	heading = _turn_toward_heading(_heading_of(direction), delta)
	airspeed = maxf(taxi_speed, airspeed - braking * delta)
	_advance_ground(delta)
	var exit = airfield.landing_exit(_landing_end)
	if _flat(_unit.global_position - exit).dot(direction) >= -0.2:
		airfield.release_runway(_unit)
		_route = airfield.taxi_in_route(stand, _landing_end)
		_landing_end = -1
		_route_after = "park"
		phase = Phase.TAXI


# --- Kinematics ---------------------------------------------------------------


func _steer(desired, delta):
	var error = angle_difference(heading, desired)
	var wanted = clampf(-error * TURN_GAIN, -max_bank, max_bank)
	bank = move_toward(bank, wanted, roll_rate * delta)
	var rate = GRAVITY * tan(bank) / maxf(airspeed, stall_speed)
	heading = wrapf(heading - rate * delta, -PI, PI)


func _turn_on_ground(desired, delta):
	heading = _turn_toward_heading(desired, delta)
	return angle_difference(heading, desired)


func _turn_toward_heading(desired, delta):
	var error = angle_difference(heading, desired)
	return wrapf(heading + clampf(error, -TAXI_TURN_RATE * delta, TAXI_TURN_RATE * delta), -PI, PI)


func _advance(delta):
	_unit.global_position += _forward() * airspeed * delta + Vector3.UP * vertical_speed * delta
	pitch = atan2(vertical_speed, maxf(airspeed, 1.0))


func _advance_ground(delta):
	var point = _unit.global_position + _forward() * airspeed * delta
	point.y = _ground_height(point)
	_unit.global_position = point
	pitch = 0.0


func _publish():
	_unit.global_basis = Basis(Vector3.UP, heading)
	velocity = flight_velocity()


func _forward():
	return Vector3(-sin(heading), 0, -cos(heading))


static func _heading_of(direction):
	return atan2(-direction.x, -direction.z)


static func _flat(vector):
	return vector * Vector3(1, 0, 1)


func _bearing(from, to):
	return _heading_of(_flat(to - from))


func _approach_speed():
	return stall_speed * 1.3


func _cruise_height_at(point):
	var baseline = _ground_height(point) + cruise_height
	if _match.map != null and _match.map.has_method("flight_height_at"):
		return maxf(baseline, _match.map.flight_height_at(point, baseline))
	return baseline


func _ground_height(point):
	var map = _match.map
	if map != null and map.has_method("height_at"):
		return map.height_at(Vector2(point.x, point.z))
	return 0.0


func _map_center():
	var size = _match.map.size if _match.map != null else Vector2(64, 64)
	return Vector3(size.x * 0.5, 0, size.y * 0.5)


func _outside_map(point):
	var size = _match.map.size if _match.map != null else Vector2(64, 64)
	return (
		point.x < -AIRSPACE_MARGIN
		or point.z < -AIRSPACE_MARGIN
		or point.x > size.x + AIRSPACE_MARGIN
		or point.z > size.y + AIRSPACE_MARGIN
	)


# Clearance of a point from the airspace edge (negative outside).
func _airspace_room(point):
	var size = _match.map.size if _match.map != null else Vector2(64, 64)
	return minf(minf(point.x, point.z), minf(size.x - point.x, size.y - point.z)) + AIRSPACE_MARGIN


func _choose_landing_end():
	var best = 0
	var best_room = -INF
	for end in [0, 1]:
		var direction = airfield.landing_direction(end)
		var outer = airfield.landing_threshold(end) - direction * (FINAL_LENGTH + OUTER_FIX)
		var room = _airspace_room(outer)
		if room > best_room:
			best = end
			best_room = room
	return best


func _clamp_to_map(point):
	var size = _match.map.size if _match.map != null else Vector2(64, 64)
	var margin = minf(MAP_MARGIN + orbit_radius, minf(size.x, size.y) * 0.25)
	return Vector3(
		clampf(point.x, margin, size.x - margin), point.y, clampf(point.z, margin, size.y - margin)
	)


func _valid_airfield():
	return (
		is_instance_valid(airfield)
		and not airfield.is_queued_for_deletion()
		and airfield.player == _unit.player
		and airfield.is_constructed()
	)


func _valid_target(target):
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.hp > 0


func _nearest_airfield(point, reach = INF):
	var best = null
	var best_distance = reach
	for field in _unit.player.get_children():
		if (
			not field.is_in_group("units")
			or field.type != "AircraftFactory"
			or field.is_queued_for_deletion()
			or not field.is_constructed()
		):
			continue
		var distance = field.global_position.distance_to(point)
		if (
			distance < best_distance
			and (field.stand_of(_unit) >= 0 or field.stands_for_production() > 0)
		):
			best = field
			best_distance = distance
	return best


func _find_home():
	if _valid_airfield() and airfield.stand_of(_unit) >= 0:
		stand = airfield.stand_of(_unit)
		return
	if is_instance_valid(airfield) and not airfield.is_queued_for_deletion():
		airfield.release_stand(_unit)
	airfield = _nearest_airfield(_unit.global_position)
	stand = airfield.claim_stand(_unit) if airfield != null else -1
	# The captured fix and landing direction belong to the old runway.
	_approach_entry = false
	_landing_end = -1


# --- Saves --------------------------------------------------------------------


func capture_flight(reference):
	return {
		"phase": phase,
		"heading": heading,
		"airspeed": airspeed,
		"bank": bank,
		"vertical_speed": vertical_speed,
		"mode": mode,
		"station": station if station.is_finite() else null,
		"strike_target": reference.call(strike_target),
		"airfield": reference.call(airfield),
		"stand": stand,
		"orbit_sign": orbit_sign,
		"ordered": ordered,
		"route": _route.duplicate(),
		"route_after": _route_after,
		"approach_entry": _approach_entry,
		"landing_end": _landing_end,
		"arrived": _arrived,
	}


func restore_flight(saved, entities):
	_restored_state = true
	phase = saved.phase
	heading = saved.heading
	airspeed = saved.airspeed
	bank = saved.bank
	vertical_speed = saved.vertical_speed
	mode = saved.mode
	station = saved.station if saved.station != null else Vector3.INF
	strike_target = entities.get(saved.strike_target)
	airfield = entities.get(saved.airfield)
	stand = saved.stand
	orbit_sign = saved.orbit_sign
	ordered = saved.ordered
	_route = saved.route.duplicate()
	_route_after = saved.route_after
	_approach_entry = saved.approach_entry
	_landing_end = saved.landing_end
	_arrived = saved.arrived
	if airfield != null and stand >= 0:
		airfield._stands[stand] = _unit
		if phase in [Phase.TAKEOFF, Phase.APPROACH, Phase.ROLLOUT]:
			airfield.take_runway(_unit)
	_publish()
