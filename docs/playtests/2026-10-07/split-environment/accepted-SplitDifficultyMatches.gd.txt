extends "res://tests/headless/SplitSignalRegression.gd"

var difficulty = 1
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
	seed(13201)
	path = "user://split-difficulty-%d.json" % OS.get_process_id()
	await _make_match()
	game._enemy.difficulty = difficulty
	game.settings.players[1].difficulty = difficulty
	await _preset_victory()
	await _review_result()
	var data = _sample()
	data.errors = errors.duplicate()
	data.timeline = timeline
	if not evidence_prefix.is_empty():
		FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
			JSON.stringify(data, "\t")
		)
		if not game.finished:
			paused = true
			var capture = Snapshot.new()
			var snapshot = capture.capture(game)
			_check(snapshot != null, "Unfinished Split capture failed")
			if snapshot != null:
				_check(
					Store.new().write_file(evidence_prefix + "-archive.json", snapshot),
					"Archive write failed"
				)
	await _cleanup()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Split difficulty: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _process(_delta):
	if is_instance_valid(game) and game.is_node_ready() and game.simulation_time >= next_sample:
		next_sample = game.simulation_time + 10
		timeline.append(_sample())
	return false


func _sample():
	return {
		"difficulty": difficulty,
		"time": game.simulation_time,
		"result": game.result,
		"control": game.control_seconds,
		"network": game.network_seconds,
		"waves": game.waves_sent,
		"human": game._get_human_player().population(),
		"relays": game.map.relays.map(_relay_sample)
	}


func _relay_sample(relay):
	var owner = "none"
	if relay.captured_by == game._get_human_player():
		owner = "human"
	elif relay.captured_by == game._enemy:
		owner = "enemy"
	return {
		"owner": owner,
		"progress": relay.progress,
		"contested": relay.contested,
		"status": game.hud._relay_labels[game.map.relays.find(relay)].text
	}


func _review_result():
	pass


func _clearance_helper():
	return super() if "--clear-contests" in OS.get_cmdline_user_args() else null
