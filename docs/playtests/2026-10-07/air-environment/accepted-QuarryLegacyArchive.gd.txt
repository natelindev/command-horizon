extends "res://tests/headless/AirEnvironmentRegression.gd"


func _run():
	path = "user://quarry-legacy-%d.json" % OS.get_process_id()
	await _make_match()
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.position = Vector3(48, scout.position.y, 51)
	scout.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(84, 0, 51))
	)
	var start = game.simulation_time
	while scout.position.x < 65.7 and game.simulation_time - start < 12:
		await physics_frame
	paused = true
	_check(
		absf(scout.position.x - 66) < 1 and is_equal_approx(scout.position.y, 1.5),
		"Legacy crossing did not reproduce low flight"
	)
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	var archive = load("res://source/match/saves/SaveFile.gd").new()
	_check(archive.write_file(EVIDENCE + "legacy-flight.json", data), archive.error)
	FileAccess.open(EVIDENCE + "legacy-flight-id.json", FileAccess.WRITE).store_string(
		JSON.stringify({"id": capture._reference(scout)})
	)
	print("LEGACY FLIGHT ", scout.position)
	await _close()
	for message in errors:
		push_error(message)
	print("Quarry legacy capture: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
