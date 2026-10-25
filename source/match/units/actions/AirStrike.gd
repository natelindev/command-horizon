extends "res://source/match/units/actions/Action.gd"

# Attack one target: fighters pursue it, bombers line up passes over it. When
# the target is gone the aircraft resumes its station; with empty stores it
# returns to its airfield to rearm.

var force_attack = false
var _target_unit = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _flight = _unit.get_node("Movement")


func _init(target_unit, forced = false):
	_target_unit = target_unit
	force_attack = forced


func _ready():
	if restoring:
		return
	if not _unit.can_strike(_target_unit):
		queue_free()
		return
	_unit.aim_target = _target_unit
	_flight.strike(_target_unit)


func weapons_free():
	return true


func _physics_process(_delta):
	if not _unit.can_strike(_target_unit) or not _unit.has_stores():
		queue_free()


func _exit_tree():
	if is_instance_valid(_unit) and _unit.aim_target == _target_unit:
		_unit.aim_target = null
	if is_instance_valid(_flight) and _flight.mode == "strike":
		_flight.idle()
