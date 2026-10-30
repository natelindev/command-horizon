extends "res://source/match/units/Infantry.gd"


func ability_definitions() -> Array:
	return [
		{
			"id": "shield_wall",
			"name": "Shield Wall",
			"description":
			(
				"Brace behind ballistic shield: 40% damage resistance, "
				+ "suppression immunity, -30% speed for 6 s."
			),
			"key": "Q",
			"target_type": "instant",
			"cooldown": 18.0,
			"duration": 6.0,
		}
	]
