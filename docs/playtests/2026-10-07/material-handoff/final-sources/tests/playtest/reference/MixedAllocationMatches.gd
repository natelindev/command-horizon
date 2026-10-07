extends "res://tests/playtest/reference/MixedStagedMatches.gd"


func _air_allowed():
	var counts = composition.inventory(plan_rules.owned_units(human))
	return (
		(
			counts.get("Infantry", 0)
			+ counts.get("Tank", 0)
			+ counts.get("CombatRobot", 0)
			+ counts.get("AdvancedTank", 0)
		)
		>= 12
	)


func _sample():
	var row = super()
	row.ground_before_air = 12
	return row
