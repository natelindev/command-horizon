extends "res://source/match/units/Infantry.gd"


func ability_definitions() -> Array:
	return [
		{
			"id": "target_flare",
			"name": "Spotter Flare",
			"description":
			(
				"Launch flare revealing fog and marking targets for +20% damage "
				+ "in a 6 m radius for 8 s."
			),
			"key": "Q",
			"target_type": "target_point",
			"accepts_target_point": true,
			"cooldown": 16.0,
			"range": 16.0,
			"radius": 6.0,
			"duration": 8.0,
		}
	]
