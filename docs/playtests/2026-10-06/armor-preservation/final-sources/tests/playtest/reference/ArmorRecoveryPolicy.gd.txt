extends "res://tests/playtest/reference/ConventionalRecoveryPolicy.gd"


func _eligible(unit):
	return (
		unit.type == "Tank"
		and unit.program != null
		and not unit.program.installed
		and unit.program.install_left <= 0
		and unit.program.mode == "Manual"
		and unit.manual_orders.pending.is_empty()
	)


func _threshold(regrouping):
	return Recover.RETURN_HEALTH if regrouping else .6
