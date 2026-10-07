extends "res://tests/playtest/SustainPressureMatches.gd"

# Match the reference commander's existing minimum ground force for an assault.
const GROUND_SCREEN = 9


func _air_allowed():
	if army_policy != "screened-air" or _unit(human, "AircraftFactory") != null:
		return super()
	return super() and economy_policy.guards(plan_rules.owned_units(human)).size() >= GROUND_SCREEN


func _sample():
	var row = super()
	row.assault_screen = {
		"ready": economy_policy.guards(plan_rules.owned_units(human)).size(),
		"required": GROUND_SCREEN
	}
	return row
