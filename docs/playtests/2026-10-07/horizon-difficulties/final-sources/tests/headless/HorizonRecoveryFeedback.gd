extends "res://tests/headless/CommandHorizonRules.gd"


func _run():
	path = "user://horizon-feedback-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	await _make_match()
	_isolate()
	game.target_command.hp = 0
	await _frames(2)
	_check(
		game.command_destroyed and not game.finished,
		"Early command destruction bypassed deployment"
	)
	_check(
		game.objective_text() == "Command destroyed · secure deployment · 0 / 30 s",
		"Early HQ destruction did not explain remaining deployment"
	)
	_check(
		"command destroyed" in game.hud._assignment_hint.text,
		"HQ destruction did not announce deployment recovery"
	)
	game.deployed = true
	game.hold_seconds = 30
	game.defence_started = true
	_check(
		game.objective_text() == "Command destroyed · retake deployment with infantry",
		"Lost deployment still obscures completed HQ objective"
	)
	game.command_left = 20
	_check(
		game.objective_text() == "Rebuild HQ · 20s remaining",
		"Command destruction hid urgent own-HQ recovery"
	)
	game.command_left = 60
	await _round_trip()
	_check(
		game.objective_text() == "Command destroyed · retake deployment with infantry",
		"Paused archive lost recovery objective"
	)
	var human = game._get_human_player()
	game.map.relay.captured_by = human
	game.map.relay.contested = false
	_units(human, "Infantry")[0].position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	game._check_outcome(0)
	_check(game.finished and game.result == "Victory", "Retaken deployment did not finish")
	_check(
		game.objective_text() == "Command destroyed · deployment secured",
		"Completed deployment still asks for recovery"
	)
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Horizon recovery feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
