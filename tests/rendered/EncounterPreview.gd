extends "res://tests/headless/EncounterProbe.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _encounter(
		{
			"name": "lancers_vs_armor",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["CombatRobot", "CombatRobot", "CombatRobot"]
		},
		false
	)
	await _encounter(
		{
			"name": "infantry_swarm",
			"left":
			[
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry"
			],
			"right": ["CombatRobot", "CombatRobot", "CombatRobot"]
		},
		false
	)
	_check(observations[0].remaining[0].is_empty(), "Rendered Lancers failed their armor role")
	_check(
		observations[1].remaining[1].is_empty(), "Rendered Lancers defeated their infantry counter"
	)
	print("Encounter rendering: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
