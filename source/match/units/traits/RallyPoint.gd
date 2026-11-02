extends Node3D

var target_unit = null:
	set(a_target_unit):
		if target_unit == a_target_unit:
			return
		if (
			is_instance_valid(target_unit)
			and target_unit.tree_exited.is_connected(_on_target_unit_tree_exited)
		):
			target_unit.tree_exited.disconnect(_on_target_unit_tree_exited)
		target_unit = a_target_unit
		if is_instance_valid(target_unit):
			target_unit.tree_exited.connect(_on_target_unit_tree_exited)
			global_position = target_unit.global_position
			visible = is_instance_valid(_unit) and _unit.is_in_group("selected_units")
		else:
			target_unit = null
			# Keep the last known rally location if its resource or leader disappears.
			# Only an explicit Stop clears a factory rally.
			visible = is_instance_valid(_unit) and _unit.is_in_group("selected_units")

@onready var _unit = get_parent()


func _ready():
	visible = _unit.is_in_group("selected_units")
	_unit.selected.connect(_show)
	_unit.deselected.connect(hide)


func _physics_process(_delta):
	if is_instance_valid(target_unit) and not target_unit.is_queued_for_deletion():
		global_position = target_unit.global_position


func _show():
	show()
	if is_instance_valid(target_unit):
		var targetability = target_unit.find_child("Targetability")
		if targetability != null:
			targetability.animate()


func is_assigned():
	return is_instance_valid(target_unit) or position != Vector3.ZERO


func clear_assignment():
	var gate = load("res://source/match/network/NetworkGate.gd")
	if gate.intercept(
		_unit,
		{
			"kind": "rally",
			"unit": gate.id_for(_unit),
			"point": gate.Protocol.quantize(_unit.global_position)
		}
	):
		return
	target_unit = null
	_reset_position_to_parent()
	visible = _unit.is_in_group("selected_units")


func _reset_position_to_parent():
	position = Vector3.ZERO


func _on_target_unit_tree_exited():
	target_unit = null
