extends "res://tests/headless/AirEnvironmentRegression.gd"


func _run():
	path = "user://quarry-legacy-recovery-%d.json" % OS.get_process_id()
	var archive = load("res://source/match/saves/SaveFile.gd").new()
	var data = archive.read_file(EVIDENCE + "legacy-flight.json")
	var id = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE + "legacy-flight-id.json")).id
	var record = data.units.filter(func(unit): return unit.id == id)[0]
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Legacy low flight failed to restore")
	if not loaded.ok:
		quit(2)
		return
	game = loaded.game
	game.progress_path = path
	var scout = restore.entities[id]
	_check(paused and scout.position == record.position, "Legacy load rewrote aircraft position")
	await _frames(10)
	_check(game.simulation_time == data.simulation_time, "Legacy paused flight advanced time")
	game.hud._toggle_pause()
	await _frames(2)
	_check(scout.position.y >= 4, "Legacy aircraft did not gain clearance on movement")
	print("LEGACY RESUME old=", record.position.y, " raised=", scout.position.y)
	await _frames(240)
	_check(
		is_instance_valid(scout) and scout.position.x > 83,
		"Legacy aircraft did not complete its route"
	)
	await _close()
	for message in errors:
		push_error(message)
	print("Quarry legacy recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
