extends "res://source/match/units/Infantry.gd"


func ability_definitions() -> Array:
	return [
		{
			"id": "emp_rocket",
			"name": "Disruptor Rocket",
			"description":
			(
				"Fire EMP rocket dealing 35 damage, draining 50 shields, "
				+ "and slowing the target for 4 s."
			),
			"key": "Q",
			"target_type": "target_unit",
			"accepts_target_point": false,
			"cooldown": 18.0,
			"range": 12.0,
			"duration": 4.0,
		}
	]
