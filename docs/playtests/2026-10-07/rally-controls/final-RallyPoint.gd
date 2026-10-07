extends Node3D

var target_unit = null:
	set(a_target_unit):
		if target_unit == a_target_unit:
			return
		if is_instance_valid(target_unit):
			target_unit.tree_exited.disconnect(_on_target_unit_tree_exited)
		target_unit = a_target_unit
		if is_instance_valid(target_unit):
			target_unit.tree_exited.connect(_on_target_unit_tree_exited)
			hide()
		else:
			target_unit = null
			_reset_position_to_parent()
			visible = _unit.is_in_group("selected_units")

@onready var _unit = get_parent()
@onready var _animation_player = find_child("AnimationPlayer")


func _ready():
	_animation_player.play("idle")
	visible = _unit.is_in_group("selected_units")
	_unit.selected.connect(_show)
	_unit.deselected.connect(hide)


func _physics_process(_delta):
	if target_unit != null:
		global_position = target_unit.global_position


func _show():
	if target_unit == null:
		show()
	else:
		var targetability = target_unit.find_child("Targetability")
		if targetability != null:
			targetability.animate()


func is_assigned():
	return is_instance_valid(target_unit) or position != Vector3.ZERO


func clear_assignment():
	target_unit = null
	_reset_position_to_parent()
	visible = _unit.is_in_group("selected_units")


func _reset_position_to_parent():
	position = Vector3.ZERO


func _on_target_unit_tree_exited():
	target_unit = null
