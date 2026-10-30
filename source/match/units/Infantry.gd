extends "res://source/match/units/Tank.gd"


func ability_definitions() -> Array:
	if type != "Infantry":
		return []
	return [
		{
			"id": "frag_grenade",
			"name": "Frag Grenade",
			"description":
			(
				"Target an enemy-garrisoned neutral building. "
				+ "Deal 15 damage to each occupant and force survivors out. No exterior damage."
			),
			"key": "Q",
			"target_type": "target_unit",
			"accepts_target_point": false,
			"cooldown": 12.0,
			"range": 10.0,
			"radius": 3.5,
		}
	]
