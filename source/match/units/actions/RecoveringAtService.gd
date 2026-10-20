extends "res://source/match/units/actions/Action.gd"

const Repairs = preload("res://source/match/combat/RepairService.gd")
const RETURN_HEALTH = 0.8
const ARRIVAL_RANGE = 4.5
const BLOCKED_SECONDS = 5.0

var _target = null
var _full_recovery = false
var _elapsed = 0.0
var _stalled = 0.0
var _blocked = false
var _retry_left = 0.0
var _last_progress = Vector3.ZERO

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(service, full_recovery = false):
	_target = service
	_full_recovery = full_recovery


func _ready():
	if restoring:
		return
	_last_progress = _unit.global_position_yless
	_refresh()


func _physics_process(delta):
	_retry_left = maxf(0.0, _retry_left - delta)
	if (
		_unit.hp >= _unit.hp_max * (1.0 if _full_recovery else RETURN_HEALTH)
		and not (_unit.has_method("needs_rearm") and _unit.needs_rearm())
	):
		queue_free()
		return
	_elapsed += delta
	if _elapsed < 0.25:
		return
	var elapsed = _elapsed
	_elapsed = 0.0
	if not Repairs.facility_eligible(_target, _unit):
		block()
		return
	if _blocked:
		return
	if _unit.global_position_yless.distance_to(_destination()) <= _arrival_range():
		_stalled = 0.0
		_movement.stop()
		if _target.has_method("service_height"):
			# Rotorcraft settle onto the helipad deck while serviced.
			_movement.settle_height = _target.service_height(_unit)
		return
	if _unit.global_position_yless.distance_to(_last_progress) >= 0.35:
		_last_progress = _unit.global_position_yless
		_stalled = 0.0
	else:
		_stalled += elapsed
	if _stalled >= BLOCKED_SECONDS:
		block()
		return
	_refresh()


func block():
	if not _blocked:
		_retry_left = 10.0
	_blocked = true
	_movement.stop()


func _refresh():
	if Repairs.facility_eligible(_target, _unit):
		if _unit.global_position_yless.distance_to(_destination()) > _arrival_range():
			_movement.move(_destination())
		else:
			_movement.stop()


# Facilities with service points (airfield helipads and stands) receive the
# aircraft there; others service anything near their center.
func _destination():
	if _target.has_method("service_point"):
		return _target.service_point(_unit) * Vector3(1, 0, 1)
	return _target.global_position_yless


func _arrival_range():
	return _target.service_reach() if _target.has_method("service_reach") else ARRIVAL_RANGE


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()
		if "settle_height" in _movement:
			_movement.settle_height = INF


func _to_string():
	if _blocked:
		return (
			"Recovery blocked · Skip or issue a new order."
			if _full_recovery
			else "Recovery blocked · waiting for safe service"
		)
	if Repairs.facility_eligible(_target, _unit):
		if _unit.global_position_yless.distance_to(_target.global_position_yless) <= ARRIVAL_RANGE:
			return (
				"Recovering · %d%% / %d%%"
				% [roundi(_unit.hp * 100.0 / _unit.hp_max), 100 if _full_recovery else 80]
			)
	return "Returning for repairs"
