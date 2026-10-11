extends "res://source/match/units/actions/Action.gd"

const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
var _target_unit
var _shot = null
var _elapsed = 0.0
@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target):
	_target_unit = target


func _physics_process(delta):
	_elapsed += delta
	if _elapsed < .2:
		return
	_elapsed = 0
	if not is_instance_valid(_target_unit) or _target_unit.hp <= 0:
		queue_free()
		return
	if _unit.has_meta("garrison_host") and _unit.get_meta("garrison_host") == _target_unit:
		if not is_instance_valid(_shot) or _shot.is_queued_for_deletion():
			var enemies = _unit._match.battlefield.fireable_targets(_unit)
			if not enemies.is_empty():
				enemies.sort_custom(
					func(a, b):
						return (
							_unit.global_position.distance_squared_to(a.global_position)
							< _unit.global_position.distance_squared_to(b.global_position)
						)
				)
				_shot = Shooting.new(enemies[0])
				add_child(_shot)
		return
	if not _target_unit.can_garrison(_unit):
		queue_free()
		return
	var direction = (_unit.global_position_yless - _target_unit.global_position_yless).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var distance = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if distance <= _target_unit.radius + _unit.radius + 1.0:
		_target_unit.enter(_unit)
	else:
		_unit.get_node("Movement").move(
			_target_unit.global_position + direction * (_target_unit.radius + .7)
		)


func _exit_tree():
	if is_instance_valid(_target_unit) and is_instance_valid(_unit):
		_target_unit.leave(_unit)
		_unit.get_node("Movement").stop()


func _to_string():
	return tr("Garrisoned · Move to leave")
