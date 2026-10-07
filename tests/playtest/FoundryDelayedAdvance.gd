extends "res://tests/playtest/FoundryDifficultyMatches.gd"


func _play_foundry():
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.issue_manual_order(moving.new(Vector3(47, 0, 58)))
	var start = game.simulation_time
	while not game.alarm and game.simulation_time - start < 15:
		await _frames(15)
	_check(game.alarm, "Delayed assault did not trigger factory production")
	scout.issue_manual_order(moving.new(Vector3(35, 0, 58)))
	start = game.simulation_time
	while game.simulation_time - start < 125:
		await _frames(30)
	_check(
		game.nodes.all(func(entry): return entry.batches == 3),
		"Delayed assault did not expose every batch"
	)
	print(
		"FOUNDRY DELAYED start=",
		game.simulation_time,
		" funds=",
		[game._enemy.resource_a, game._enemy.resource_b]
	)
	await super()
