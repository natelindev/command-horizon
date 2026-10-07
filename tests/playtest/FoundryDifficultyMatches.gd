extends "res://tests/headless/BrokenFoundryRegression.gd"

var evidence_prefix = ""
var timeline = []
var next_sample = 0.0


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = argument.trim_prefix("--difficulty=").to_int()
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	assert(difficulty in [0, 1, 2])
	seed(13501)
	path = "user://foundry-difficulty-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _prepare_display()
	await _make_match()
	await _play_foundry()
	var data = _sample()
	data.timeline = timeline
	data.errors = errors.duplicate()
	if not evidence_prefix.is_empty():
		FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
			JSON.stringify(data, "\t")
		)
		if not game.finished:
			game.hud._toggle_pause()
			var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
			var store = load("res://source/match/saves/SaveFile.gd").new()
			_check(
				store.write_file(evidence_prefix + "-archive.json", capture.capture(game)),
				"Unfinished archive failed"
			)
	await _close()
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Foundry difficulty: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _frames(count):
	await super(count)
	if is_instance_valid(game) and game.is_node_ready() and not paused:
		if game.simulation_time >= next_sample:
			next_sample = game.simulation_time + 10
			timeline.append(_sample())


func _sample():
	var human = game._get_human_player()
	return {
		"difficulty": difficulty,
		"time": game.simulation_time,
		"result": game.result,
		"hold": game.hold_seconds,
		"capture": game.map.relay.progress,
		"contested": game.map.relay.contested,
		"owner":
		(
			"human"
			if game.map.relay.captured_by == human
			else "enemy" if game.map.relay.captured_by != null else "none"
		),
		"human": human.population(),
		"infantry": _units(human, "Infantry").size(),
		"resources": [human.resource_a, human.resource_b],
		"response_done": game.response_done,
		"nodes":
		game.nodes.map(func(entry): return {"disabled": entry.disabled, "batches": entry.batches}),
		"status": game.hud._capture.text
	}


func _prepare_display():
	pass


func _restore_display():
	pass
