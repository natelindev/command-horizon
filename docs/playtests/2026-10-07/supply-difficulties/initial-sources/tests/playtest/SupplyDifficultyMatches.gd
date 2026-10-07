extends "res://tests/headless/SupplyLineRegression.gd"

var evidence_prefix = ""
var timeline = []
var next_sample = 0.0


func _initialize():
	create_timer(1800).timeout.connect(
		func():
			push_error("Supply difficulty timeout")
			quit(2)
	)
	_run.call_deferred()


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = argument.trim_prefix("--difficulty=").to_int()
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	assert(difficulty in [0, 1, 2])
	seed(12801)
	path = "user://supply-difficulty-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _make_match()
	print("SUPPLY DIFFICULTY ", difficulty)
	await _play()
	var data = _sample()
	data.errors = errors.duplicate()
	data.timeline = timeline
	if not evidence_prefix.is_empty():
		FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
			JSON.stringify(data, "\t")
		)
		if not game.finished:
			paused = true
			var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
			var state = snapshot.capture(game)
			_check(state != null, "Unfinished convoy capture failed: " + snapshot.error)
			if state != null:
				var archive = load("res://source/match/saves/SaveFile.gd").new()
				_check(archive.write_file(evidence_prefix + "-archive.json", state), archive.error)
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Supply difficulty: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _frames(count):
	await super(count)
	if is_instance_valid(game) and game.simulation_time >= next_sample:
		next_sample = game.simulation_time + 10
		timeline.append(_sample())


func _sample():
	var trucks = []
	for entry in game.convoy:
		var row = {
			"leg": entry.leg,
			"clearance": entry.clearance,
			"delivered": entry.delivered,
			"alive": game._alive(entry)
		}
		if row.alive:
			row.hp = entry.unit.hp
			row.position = [entry.unit.position.x, entry.unit.position.z]
			row.travelling = entry.unit.get_node("Movement")._has_destination
		trucks.append(row)
	return {
		"difficulty": difficulty,
		"result": game.result,
		"time": game.simulation_time,
		"responses": game.resolved.duplicate(),
		"trucks": trucks,
		"escorts": game.escorts().size(),
		"enemies": game._enemy.population() if game._enemy != null else 0
	}
