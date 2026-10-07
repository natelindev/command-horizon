extends "res://source/match/units/actions/Action.gd"

const Repairs = preload("res://source/match/combat/RepairService.gd")
const RETURN_HEALTH = 0.8
const ARRIVAL_RANGE = 4.5
const BLOCKED_SECONDS = 5.0

var _target = null
var _elapsed = 0.0
var _stalled = 0.0
var _blocked = false
var _retry_left = 0.0
var _last_progress = Vector3.ZERO

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(service):
	_target = service


func _ready():
	if restoring:
		return
	_last_progress = _unit.global_position_yless
	_refresh()


func _physics_process(delta):
	_retry_left = maxf(0.0, _retry_left - delta)
	if _unit.hp >= _unit.hp_max * RETURN_HEALTH:
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
	if _unit.global_position_yless.distance_to(_target.global_position_yless) <= ARRIVAL_RANGE:
		_stalled = 0.0
		_movement.stop()
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
		if _unit.global_position_yless.distance_to(_target.global_position_yless) > ARRIVAL_RANGE:
			_movement.move(_target.global_position_yless)
		else:
			_movement.stop()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()


func _to_string():
	if _blocked:
		return "Recovery blocked · waiting for safe service"
	if Repairs.facility_eligible(_target, _unit):
		if _unit.global_position_yless.distance_to(_target.global_position_yless) <= ARRIVAL_RANGE:
			return "Recovering · %d%% / 80%%" % roundi(_unit.hp * 100.0 / _unit.hp_max)
	return "Returning for repairs"
