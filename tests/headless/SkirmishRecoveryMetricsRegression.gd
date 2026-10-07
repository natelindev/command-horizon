extends "res://tests/headless/SkirmishRecoveryRegression.gd"


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	opponent._command_army(opponent._units())
	var probe = load("res://tests/headless/SkirmishRecoveryMetrics.gd").new()
	probe.sample(game, opponent)
	_check(probe.records.size() == 5, "Recovery metrics missed the five staged roles")
	game.simulation_time += 0.5
	wounded[0].hp = wounded[0].hp_max * 0.8
	wounded[0].issue_manual_order(null)
	probe.sample(game, opponent)
	_check(
		probe.records[0].outcome == "recovered" and probe.records[0].end_health >= 0.8,
		"Recovery metrics did not record a healthy release"
	)
	wounded[1].action.block()
	game.simulation_time += 0.5
	probe.sample(game, opponent)
	_check(
		probe.records[1].sampled_blocked_seconds == 0.5,
		"Recovery metrics accumulated the wrong blocked interval"
	)
	root.get_node("MatchSignals").unit_destroying.connect(probe.loss.bind(game))
	wounded[2].hp = 0
	await _frames(3)
	_check(probe.records[2].outcome == "lost", "Actual destruction did not end recovery metrics")
	wounded[3].issue_manual_order(null)
	probe.sample(game, opponent)
	_check(
		probe.records[3].outcome == "interrupted" and probe.records[4].outcome == "active",
		"Interrupted and ongoing recoveries were conflated"
	)
	paused = false
	game.queue_free()
	await _frames(3)
	for message in errors:
		push_error(message)
	print("Recovery metrics: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
