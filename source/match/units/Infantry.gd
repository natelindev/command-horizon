extends "res://source/match/units/Tank.gd"


func ability_definitions() -> Array:
	if type != "Infantry":
		return []
	return [
		{
			"id": "frag_grenade",
			"name": "Frag Grenade",
			"description": "Deal 35 damage to enemies in a 3.5 m radius.",
			"key": "Q",
			"target_type": "target_unit",
			"accepts_target_point": true,
			"cooldown": 12.0,
			"range": 10.0,
			"radius": 3.5,
		}
	]
