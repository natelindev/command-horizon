extends "res://source/match/units/actions/Action.gd"

const RepairRobot = preload("res://source/match/units/RepairRobot.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")

var _target = null
var _elapsed = 0.0
var _finish_when_repaired = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


static func is_applicable(source_unit, target_unit):
	return source_unit is RepairRobot and Repairs.mobile_eligible(source_unit, target_unit)


func repair_target():
	return _target


func _init(target, finish_when_repaired = false):
	_target = target
	_finish_when_repaired = finish_when_repaired


func _ready():
	if restoring:
		return
	_target.tree_exiting.connect(queue_free)


func _physics_process(delta):
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		queue_free()
		return
	if _finish_when_repaired and _target.hp >= _target.hp_max:
		queue_free()
		return
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var repair_range = 3.0
	if Repairs.mobile_distance(_unit, _target) > repair_range:
		_movement.move(_target.global_position)
	else:
		_movement.stop()


func _exit_tree():
	if is_instance_valid(_movement):
		_movement.stop()
