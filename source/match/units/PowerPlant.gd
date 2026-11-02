extends "res://source/match/units/Structure.gd"


func ability_definitions() -> Array:
	var result = [
		{
			"id": "grid_surge",
			"name": "Generator Surge",
			"key": "Q",
			"description":
			(
				"Increase this generator's power output by 50% for 30 seconds, "
				+ "followed by a 10 second cooldown."
			),
			"target_type": "instant",
			"cooldown": 40.0,
			"duration": 30.0,
		}
	]
	if player.faction != "helix":
		return result
	(
		result
		. append(
			{
				"id": "power_overdrive",
				"name": "Grid Overdrive",
				"key": "E",
				"description":
				(
					"Use 3 extra power to double nearby shield recharge and speed nearby factories by 50%. "
					+ "Suspends during brownouts."
				),
				"target_type": "toggle",
				"cooldown": 0.0,
				"radius": 12.0,
			}
		)
	)
	return result
