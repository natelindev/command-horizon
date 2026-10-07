extends "res://tests/headless/AirCorridorRegression.gd"


func _run():
	path = "user://air-holding-%d.json" % OS.get_process_id()
	var archive = load("res://source/match/saves/SaveFile.gd").new()
	var data = archive.read_file(
		"res://docs/playtests/2026-10-07/air-difficulties/preview-held-archive.json"
	)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Held flight archive failed: " + loaded.get("error", ""))
	if not loaded.ok:
		quit(2)
		return
	game = loaded.game
	game.progress_path = path
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp, "Held archive changed unit"
		)
	await _frames(10)
	var flight = game.flights[0]
	var ship = flight.unit
	var before = game.simulation_time
	var response_left = flight.response_left
	_check(paused and before == data.simulation_time, "Held restore advanced time")
	_check("Holding" in game.hud._flight_labels[0].text, "Stopped evacuation is labelled In flight")
	_check(
		"Continue flight" in game.hud._flight_labels[0].tooltip_text, "Holding lacks recovery hint"
	)
	_check("holding" in game.hud._status.text, "Mission guidance ignores held flight")
	await _review_held()
	await _continue_input()
	await _frames(5)
	_check(ship.get_node("Movement")._has_destination, "Continue failed to set destination")
	_check(paused and game.simulation_time == before, "Continue advanced paused clock")
	_check(flight.response_left == response_left, "Continue advanced response countdown")
	_check("In flight" in game.hud._flight_labels[0].text, "Moving flight retained Holding label")
	_check(
		game.hud._flight_labels[0].tooltip_text.is_empty(), "Moving flight retained holding hint"
	)
	game.hud._toggle_pause()
	while flight.state == "flying" and game.simulation_time - before < 70:
		await _frames(30)
	_check(flight.state == "extracted", "Continued earned flight did not reach safety")
	_check(flight.response_done, "Continued flight skipped live response")
	await _frames(2)
	_check("Safe" in game.hud._flight_labels[0].text, "Extracted flight has stale status")
	print("AIR HELD RECOVERY elapsed=", game.simulation_time - before, " state=", flight.state)
	await _review_safe()
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Air holding: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _continue_input():
	_check(game.continue_flight(), "Held mission rejected Continue")


func _review_held():
	pass


func _review_safe():
	pass
