extends "res://source/match/units/Tank.gd"


func ability_definitions() -> Array:
	if type != "Infantry":
		return []
	return [
		{
			"id": "frag_grenade",
			"name": "Frag Grenade",
			"description": "Breach a garrisoned hostile building, dealing 42 damage to occupants and 28 to nearby enemies.",
			"key": "Q",
			"target_type": "target_unit",
			"accepts_target_point": false,
			"cooldown": 12.0,
			"range": 10.0,
			"radius": 3.5,
		}
	]
