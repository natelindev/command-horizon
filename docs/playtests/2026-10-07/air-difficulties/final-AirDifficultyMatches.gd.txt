extends "res://tests/headless/AirCorridorRegression.gd"

var evidence_prefix = ""
var timeline = []
var next_sample = 0.0
var response = null


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = argument.trim_prefix("--difficulty=").to_int()
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	assert(difficulty in [0, 1, 2])
	if "--respond-to-threats" in OS.get_cmdline_user_args():
		response = load("res://tests/playtest/reference/AirResponse.gd").new()
	seed(13001)
	path = "user://air-difficulty-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _make_match()
	print("AIR DIFFICULTY ", difficulty)
	await _play_air()
	await _stage_capture("result", game.map.EXIT)
	var data = _sample()
	data.errors = errors.duplicate()
	data.timeline = timeline
	if not evidence_prefix.is_empty():
		FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
			JSON.stringify(data, "\t")
		)
		if not game.finished:
			paused = true
			var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
			var snapshot = capture.capture(game)
			_check(snapshot != null, "Unfinished air capture failed: " + capture.error)
			if snapshot != null:
				var archive = load("res://source/match/saves/SaveFile.gd").new()
				_check(
					archive.write_file(evidence_prefix + "-archive.json", snapshot), archive.error
				)
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Air difficulty: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _frames(count):
	await super(count)
	if response != null and is_instance_valid(game) and not paused and not game.finished:
		response.step(game)
	if is_instance_valid(game) and game.simulation_time >= next_sample:
		next_sample = game.simulation_time + 10
		timeline.append(_sample())


func _sample():
	var flights = []
	for entry in game.flights:
		var row = {
			"state": entry.state,
			"response_left": entry.response_left,
			"response_done": entry.response_done
		}
		if game._alive(entry.unit):
			row.hp = entry.unit.hp
			row.position = [entry.unit.position.x, entry.unit.position.z]
		flights.append(row)
	return {
		"difficulty": difficulty,
		"time": game.simulation_time,
		"result": game.result,
		"batteries": game.sites.map(func(site): return site.cleared),
		"rescued": game.rescued(),
		"flights": flights,
		"human": game._get_human_player().population(),
		"enemies": game._enemy.population() if game._enemy != null else 0
	}
