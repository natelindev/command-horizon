extends "res://tests/playtest/SupplyDifficultyMatches.gd"

var response = null


func _run():
	path = "user://supply-contest-%d.json" % OS.get_process_id()
	seed(12801)
	var files = load("res://source/match/saves/SaveFile.gd").new()
	var data = files.read_file(
		"res://docs/playtests/2026-10-07/supply-difficulties/preview-archive.json"
	)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Earned convoy archive failed: " + result.get("error", ""))
	if not result.ok:
		quit(2)
		return
	game = result.game
	game.progress_path = path
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp,
			"Convoy restore changed position or health"
		)
	await _frames(30)
	_check(paused and game.simulation_time == data.simulation_time, "Convoy restore advanced time")
	for label in game.hud._truck_labels:
		_check("Contested" in label.text, "Stopped clearance does not explain enemy contest")
		_check(
			"progress is retained" in label.tooltip_text, "Contest guidance omits retained progress"
		)
	game.advance_convoy()
	await _frames(2)
	for label in game.hud._truck_labels:
		_check("Hold to clear" in label.text, "Travelling truck lost its stop instruction")
	game.hold_convoy()
	await _frames(2)
	_check(
		game.simulation_time == data.simulation_time, "Paused convoy controls advanced clearance"
	)
	await _review_contest()
	var truck = game.convoy[2].unit
	var damaged = truck.hp
	response = load("res://tests/playtest/reference/SupplyResponse.gd").new()
	game.hud._toggle_pause()
	var start = game.simulation_time
	while not game.finished and game.simulation_time - start < 60 and not _stage_done(0):
		response.step(game)
		await _frames(15)
	_check(_stage_done(0), "Ordinary escort response did not restore checkpoint clearance")
	_check(is_instance_valid(truck) and truck.hp > damaged, "Ordered repair did not recover truck")
	_check(game.trucks().size() == 3, "Earned recovery lost a truck")
	await _frames(2)
	for label in game.hud._truck_labels:
		_check("Contested" not in label.text, "Cleared checkpoint retained stale contest status")
		_check(label.tooltip_text.is_empty(), "Cleared checkpoint retained stale contest tooltip")
	print(
		"CONVOY CONTEST RECOVERY elapsed=",
		game.simulation_time - start,
		" truck_hp=",
		truck.hp if is_instance_valid(truck) else -1,
		" responses=",
		response.responses
	)
	await _review_recovered()
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Supply contest: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_contest():
	pass


func _review_recovered():
	pass
