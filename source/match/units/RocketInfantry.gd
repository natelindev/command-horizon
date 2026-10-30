extends "res://source/match/units/Infantry.gd"


func ability_definitions() -> Array:
	return [
		{
			"id": "guided_salvo",
			"name": "Guided Salvo",
			"description": "Fire a heavy rocket that deals 34 damage.",
			"key": "Q",
			"target_type": "target_unit",
			"accepts_target_point": true,
			"cooldown": 14.0,
			"range": 14.0,
		}
	]
