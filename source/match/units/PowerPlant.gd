extends "res://source/match/units/Structure.gd"


func ability_definitions() -> Array:
	if player.faction != "helix":
		return []
	return [
		{
			"id": "power_overdrive",
			"name": "Grid Overdrive",
			"key": "E",
			"description":
			(
				"Use 3 extra power to increase nearby shield recharge by 50%. "
				+ "Requires Plasma Shields. Suspends during low power."
			),
			"target_type": "toggle",
			"cooldown": 0.0,
			"radius": 12.0,
		}
	]
