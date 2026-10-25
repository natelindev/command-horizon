extends "res://source/match/units/actions/MovingToUnit.gd"


static func eligible(unit, wreck) -> bool:
	return (
		is_instance_valid(unit)
		and unit.has_method("can_scavenge")
		and unit.can_scavenge()
		and is_instance_valid(wreck)
		and not wreck.is_queued_for_deletion()
		and wreck.is_in_group("salvage_wrecks")
		and wreck.resource_a > 0
		and wreck.salvage_left > 0.0
		and wreck.known_to(unit.player)
	)


func _process(delta):
	if not eligible(_unit, _target_unit):
		queue_free()
		return
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		_unit.scavenge(_target_unit)
		queue_free()
		return
	super(delta)


func _on_movement_finished():
	if (
		eligible(_unit, _target_unit)
		and Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit)
	):
		_unit.scavenge(_target_unit)
	super()


func _to_string():
	return "Scavenging wreck"
