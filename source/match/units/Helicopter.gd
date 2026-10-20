extends "res://source/match/units/Unit.gd"

# Attack helicopter: hovers and holds position against ground targets with a
# limited rocket load. When the rockets run out it returns to a helipad of its
# airfield, settles, rearms and then attack-moves back to where it ran dry.
# Rotors and airframe motion are animated by BastionVisuals.

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const Recovering = preload("res://source/match/units/actions/RecoveringAtService.gd")
const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const ROCKET_CAPACITY = 12
const REARM_INTERVAL = 0.5

var rockets = ROCKET_CAPACITY
# Scenario patrols without an airfield fly with unlimited rockets.
var unlimited_stores = false
var resume_point = Vector3.INF
var _rearm_left = REARM_INTERVAL


func _ready():
	await super()
	action_changed.connect(_on_action_changed)
	if action == null:
		action = WaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action != null or not is_inside_tree() or is_queued_for_deletion():
		return
	if resume_point.is_finite() and armed():
		var point = resume_point
		resume_point = Vector3.INF
		action = AttackMoving.new(point)
		return
	action = WaitingForTargets.new()


func armed():
	return unlimited_stores or rockets > 0


func expend_round():
	if not unlimited_stores:
		rockets = maxi(0, rockets - 1)


func needs_rearm():
	return not unlimited_stores and rockets < ROCKET_CAPACITY


func _physics_process(delta):
	if _match == null:
		return
	if not armed() and not action is Recovering:
		var field = _home_airfield()
		if field != null:
			resume_point = global_position * Vector3(1, 0, 1)
			action = Recovering.new(field)
	if needs_rearm():
		_rearm(delta)


func _rearm(delta):
	var field = _home_airfield()
	if field == null or not field.services(self) or not Repairs.stationary(self):
		return
	_rearm_left -= delta
	if _rearm_left <= 0.0:
		_rearm_left = REARM_INTERVAL
		rockets = mini(ROCKET_CAPACITY, rockets + 1)


func _home_airfield():
	var best = null
	var best_distance = INF
	for field in player.get_children():
		if (
			not field.is_in_group("units")
			or field.type != "AircraftFactory"
			or field.is_queued_for_deletion()
			or not field.is_constructed()
		):
			continue
		var distance = field.global_position.distance_to(global_position)
		if distance < best_distance:
			best = field
			best_distance = distance
	return best


func capture_air(_reference):
	return {
		"stores": {"rockets": rockets},
		"rearm_left": _rearm_left,
		"resume_station": resume_point if resume_point.is_finite() else null,
		"unlimited": unlimited_stores,
	}


func restore_air(saved, _entities):
	rockets = clampi(saved.stores.get("rockets", ROCKET_CAPACITY), 0, ROCKET_CAPACITY)
	_rearm_left = saved.rearm_left
	resume_point = saved.resume_station if saved.resume_station != null else Vector3.INF
	unlimited_stores = saved.unlimited
