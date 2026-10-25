extends "res://source/match/units/Infantry.gd"


func ability_definitions() -> Array:
	return [
		{
			"id": "combat_sprint",
			"name": "Combat Sprint",
			"description": "Move 50% faster for 4 seconds.",
			"key": "W",
			"target_type": "instant",
			"cooldown": 15.0,
			"duration": 4.0,
		}
	]
