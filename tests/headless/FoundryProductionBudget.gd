extends "res://tests/headless/BrokenFoundryRegression.gd"

var prefix = "res://docs/playtests/2026-10-07/foundry-production/budget"
var paid = [0, 0]
var completed = [0, 0]
var peak = [0, 0]
var events = []
var reports = []
var captured_late = false
var modes = [0, 1, 2]


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
		if argument.begins_with("--mode="):
			modes = [argument.trim_prefix("--mode=").to_int()]
	path = "user://foundry-production-%d.json" % OS.get_process_id()
	root.get_node("MatchSignals").unit_production_started.connect(_started)
	root.get_node("MatchSignals").unit_production_finished.connect(_completed)
	for mode in modes:
		difficulty = mode
		paid = [0, 0]
		completed = [0, 0]
		peak = [0, 0]
		events = []
		captured_late = false
		await _make_match()
		var scout = _units(game._get_human_player(), "Drone")[0]
		scout.issue_manual_order(
			load("res://source/match/units/actions/Moving.gd").new(Vector3(47, 0, 58))
		)
		while game.simulation_time < 300 and not game.finished:
			await _frames(30)
			for index in 2:
				peak[index] = maxi(
					peak[index], game.nodes[index].unit.get_node("ProductionQueue").size()
				)
			if mode == 2 and game.simulation_time >= 105 and not captured_late:
				captured_late = true
				var was_paused = paused
				paused = true
				var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
				var store = load("res://source/match/saves/SaveFile.gd").new()
				_check(
					store.write_file(prefix + "-late.json", capture.capture(game)),
					"Late production archive failed"
				)
				paused = was_paused
		var expected = (mode + 1) * 3
		_check(
			paid == [expected, expected], "Difficulty %d lost paid batch jobs: %s" % [mode, paid]
		)
		_check(
			completed == [expected, expected],
			"Difficulty %d lost completed jobs: %s" % [mode, completed]
		)
		_check(peak.max() <= 5, "Campaign bypassed producer capacity")
		_check(game.nodes.all(func(entry): return entry.batches == 3), "Batch schedule incomplete")
		var funds = [game._enemy.resource_a, game._enemy.resource_b]
		_check(
			funds == [600 - expected * 2 * 22, 300 - expected * 2 * 14],
			"Production spending differs from all promised jobs"
		)
		reports.append(
			{
				"difficulty": mode,
				"mission_source_sha256": game.get_script().get_source_code().sha256_text(),
				"paid": paid.duplicate(),
				"completed": completed.duplicate(),
				"peak": peak.duplicate(),
				"funds": funds,
				"events": events.duplicate(true)
			}
		)
		print("FOUNDRY BUDGET ", JSON.stringify(reports[-1]))
		await _close()
	FileAccess.open(prefix + ".json", FileAccess.WRITE).store_string(
		JSON.stringify({"reports": reports, "errors": errors}, "\t")
	)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Foundry production budget: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _index(factory):
	if not is_instance_valid(game) or not game.is_node_ready():
		return -1
	for index in game.nodes.size():
		if game.nodes[index].unit == factory:
			return index
	return -1


func _started(_prototype, factory):
	var index = _index(factory)
	if index >= 0:
		paid[index] += 1
		events.append(
			{
				"kind": "paid",
				"node": index,
				"time": game.simulation_time,
				"queue": factory.get_node("ProductionQueue").size()
			}
		)


func _completed(_unit, factory):
	var index = _index(factory)
	if index >= 0:
		completed[index] += 1
		events.append({"kind": "completed", "node": index, "time": game.simulation_time})


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "broken_foundry"
	settings.map_path = "res://source/match/maps/BrokenFoundryMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = difficulty
		settings.players.append(side)
	game = load("res://source/match/campaign/BrokenFoundry.tscn").instantiate()
	if "--legacy" in OS.get_cmdline_user_args():
		game.set_script(
			load("res://docs/playtests/2026-10-07/foundry-production/original-mission.gd")
		)
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)
