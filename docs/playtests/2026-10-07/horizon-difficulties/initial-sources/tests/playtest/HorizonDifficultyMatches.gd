extends "res://tests/headless/CommandHorizonRegression.gd"

var evidence_prefix = ""


func _make_match():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = argument.trim_prefix("--difficulty=").to_int()
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	assert(difficulty in [0, 1, 2])
	seed(12701)
	await super()
	print("HORIZON DIFFICULTY ", difficulty)


func _report():
	super()
	var data = {
		"difficulty": difficulty,
		"challenge": challenge,
		"alternate_route": game.alternate_route,
		"result": game.result,
		"time": game.simulation_time,
		"deployed": game.deployed,
		"command_destroyed": game.command_destroyed,
		"zone_held": game.zone_held(),
		"waves": game.waves_sent,
		"errors": errors.duplicate(),
		"sides": []
	}
	for side in [game._get_human_player(), game._enemy]:
		var counts = {}
		for unit in side.get_children():
			if unit.is_in_group("units") and game._alive(unit):
				counts[unit.type] = counts.get(unit.type, 0) + 1
		data.sides.append(
			{
				"faction": side.faction,
				"materials": side.resource_a,
				"electronics": side.resource_b,
				"units": counts
			}
		)
	if evidence_prefix.is_empty():
		return
	FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
		JSON.stringify(data, "\t")
	)
	if not game.finished:
		paused = true
		var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
		var state = snapshot.capture(game)
		_check(state != null, "Unresolved finale capture failed: " + snapshot.error)
		if state != null:
			var archive = load("res://source/match/saves/SaveFile.gd").new()
			_check(archive.write_file(evidence_prefix + "-archive.json", state), archive.error)
