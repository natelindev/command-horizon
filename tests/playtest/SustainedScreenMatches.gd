extends "res://tests/playtest/SustainPressureMatches.gd"


func _air_allowed():
	if army_policy != "screened-air" or _unit(human, "AircraftFactory") != null:
		return super()
	return super() and _screen_armor().size() >= _opening_tank_target()


func _screen_armor():
	return economy_policy.guards(plan_rules.owned_units(human)).filter(
		func(unit): return unit.type in ["Tank", "CombatRobot", "AdvancedTank"]
	)


func _sample():
	var row = super()
	row.sustained_armor_screen = {
		"ready": _screen_armor().size(), "required": _opening_tank_target()
	}
	return row
