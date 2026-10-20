# gdlint: disable=max-public-methods
extends "res://source/match/units/Structure.gd"

# Runway airfield. Fixed-wing aircraft park on stands, taxi along a parallel
# taxiway, take off and land on one runway in the airfield's -Z direction, and
# rearm on their stand. Helicopters and drones use the helipads.
#
# Local layout in metres (x across, -z is the take-off direction):
#   runway centerline x = RUNWAY_X from THRESHOLD_Z to RUNWAY_END_Z
#   taxiway x = TAXIWAY_X, stands beside it at x = STAND_X

const Layout = preload("res://source/match/units/AirfieldLayout.gd")
const Catalog = preload("res://source/match/BastionCatalog.gd")
const RUNWAY_X = Layout.RUNWAY_X
const THRESHOLD_Z = Layout.THRESHOLD_Z
const RUNWAY_END_Z = Layout.RUNWAY_END_Z
const TAXIWAY_X = Layout.TAXIWAY_X
const STAND_X = Layout.STAND_X
const STAND_Z = Layout.STAND_Z
const PAD_POINTS = Layout.PAD_POINTS
const EXIT_Z = Layout.EXIT_Z

# Aircraft are serviced on stands and helipads, all within this reach of center.
const SERVICE_REACH = 14.0
const PAD_REACH = 1.6

var _stands = []
var _runway_user = null


func _init():
	_stands.resize(STAND_Z.size())
	# Range, sight and contact measure this structure from its outline.
	add_to_group("footprinted_structures")


func service_slots():
	return STAND_Z.size() + PAD_POINTS.size()


func pad_point(index):
	return to_global(PAD_POINTS[index])


# Parked jets on their own stand, and rotorcraft settled on a helipad.
func services(aircraft):
	if aircraft.movement_domain != Constants.Match.Navigation.Domain.AIR:
		return false
	var flight = aircraft.get_node_or_null("Movement")
	if flight != null and flight.has_method("is_parked"):
		return flight.is_parked() and flight.airfield == self and stand_of(aircraft) >= 0
	for index in range(PAD_POINTS.size()):
		var offset = (aircraft.global_position - pad_point(index)) * Vector3(1, 0, 1)
		if offset.length() <= PAD_REACH:
			return true
	return false


# Where an aircraft recovers: a jet's own stand, otherwise the nearest helipad
# not already holding another aircraft.
func service_point(aircraft):
	var index = stand_of(aircraft)
	if index >= 0:
		return stand_point(index)
	var best = pad_point(0)
	var best_distance = INF
	for pad in range(PAD_POINTS.size()):
		var point = pad_point(pad)
		if _pad_taken(point, aircraft):
			continue
		var distance = point.distance_to(aircraft.global_position * Vector3(1, 0, 1))
		if distance < best_distance:
			best = point
			best_distance = distance
	return best


# Deck height of the helipad nearest the aircraft.
func service_height(aircraft):
	var best = 0
	for index in range(PAD_POINTS.size()):
		if (
			pad_point(index).distance_to(aircraft.global_position * Vector3(1, 0, 1))
			< pad_point(best).distance_to(aircraft.global_position * Vector3(1, 0, 1))
		):
			best = index
	return global_position.y + Layout.pad_height(player.faction, best)


func service_reach():
	return PAD_REACH * 0.6


func _pad_taken(point, aircraft):
	for other in _match.battlefield.nearby_units(point, PAD_REACH, player):
		if other != aircraft and other.movement_domain == Constants.Match.Navigation.Domain.AIR:
			return true
	return false


func runway_threshold():
	return to_global(Vector3(RUNWAY_X, 0, THRESHOLD_Z))


func runway_end():
	return to_global(Vector3(RUNWAY_X, 0, RUNWAY_END_Z))


func runway_direction():
	var direction = (runway_end() - runway_threshold()) * Vector3(1, 0, 1)
	return direction.normalized()


func runway_length():
	return THRESHOLD_Z - RUNWAY_END_Z


func stand_point(index):
	return to_global(Vector3(STAND_X, 0, STAND_Z[index]))


# Parked aircraft face the taxiway.
func stand_direction():
	return (to_global(Vector3(-1, 0, 0)) - to_global(Vector3.ZERO)).normalized()


func taxi_out_route(index):
	return [
		to_global(Vector3(TAXIWAY_X, 0, STAND_Z[index])),
		to_global(Vector3(TAXIWAY_X, 0, THRESHOLD_Z - 0.5)),
		runway_threshold(),
	]


# Aircraft land on whichever end has room for the approach: end 0 lands in the
# take-off direction, end 1 lands from the far end toward the threshold.
func landing_threshold(end):
	return runway_threshold() if end == 0 else runway_end()


func landing_direction(end):
	return runway_direction() if end == 0 else -runway_direction()


func landing_exit(end):
	return to_global(Vector3(RUNWAY_X, 0, EXIT_Z if end == 0 else -EXIT_Z))


func taxi_in_route(index, end):
	var exit_z = EXIT_Z - 0.5 if end == 0 else -EXIT_Z + 0.5
	return [
		to_global(Vector3(TAXIWAY_X, 0, exit_z)),
		to_global(Vector3(TAXIWAY_X, 0, STAND_Z[index])),
		stand_point(index),
	]


func stand_of(aircraft):
	for index in range(_stands.size()):
		if _stands[index] == aircraft:
			return index
	return -1


func claim_stand(aircraft):
	var current = stand_of(aircraft)
	if current >= 0:
		return current
	# Paid jobs already own the remaining capacity. A visitor may only use
	# an unpromised stand; production releases its promise before spawning.
	if stands_for_production() <= 0:
		return -1
	_forget_lost()
	for index in range(_stands.size()):
		if _stands[index] == null:
			_stands[index] = aircraft
			return index
	return -1


func first_free_stand():
	_forget_lost()
	return _stands.find(null)


func release_stand(aircraft):
	var index = stand_of(aircraft)
	if index >= 0:
		_stands[index] = null


func free_stands():
	_forget_lost()
	return _stands.count(null)


# Stands not yet promised: queued jets each hold one until they roll out.
func stands_for_production():
	var queued = 0
	if production_queue != null:
		for element in production_queue.get_elements():
			if Catalog.is_fixed_wing(Catalog.type_from_path(element.unit_prototype.resource_path)):
				queued += 1
	return free_stands() - queued


func stand_transform(index):
	return Transform3D(Basis.looking_at(stand_direction(), Vector3.UP), stand_point(index))


func _forget_lost():
	for index in range(_stands.size()):
		var aircraft = _stands[index]
		if (
			aircraft != null
			and (not is_instance_valid(aircraft) or aircraft.is_queued_for_deletion())
		):
			_stands[index] = null


# One aircraft at a time rolls on the runway; others hold short or keep orbiting.
func take_runway(aircraft):
	if (
		_runway_user != null
		and _runway_user != aircraft
		and is_instance_valid(_runway_user)
		and not _runway_user.is_queued_for_deletion()
	):
		return false
	_runway_user = aircraft
	return true


func release_runway(aircraft):
	if _runway_user == aircraft:
		_runway_user = null


func runway_user():
	return _runway_user if is_instance_valid(_runway_user) else null
