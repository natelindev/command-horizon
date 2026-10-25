extends "res://source/match/units/actions/MovingToUnit.gd"

var elapsed = 0.0


func _process(delta):
	if not is_instance_valid(_target_unit) or not _target_unit.can_collect(_unit):
		queue_free()
		return
	if (
		_unit.global_position_yless.distance_to(_target_unit.global_position_yless)
		<= _unit.radius + _target_unit.radius + .7
	):
		_movement_trait.stop()
		elapsed += delta
		if _target_unit.collect(_unit, elapsed):
			queue_free()
		return
	elapsed = 0.0
	super(delta)


func _on_movement_finished():
	# The interaction owns completion; MovingToUnit's arrival must not delete
	# the action before a two-second repair-crate channel can finish.
	if not is_instance_valid(_target_unit):
		queue_free()
	elif (
		_unit.global_position_yless.distance_to(_target_unit.global_position_yless)
		> _unit.radius + _target_unit.radius + .7
	):
		super()


func _to_string():
	return "Collect supplies"
