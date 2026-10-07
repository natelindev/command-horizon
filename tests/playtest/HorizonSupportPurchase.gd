extends "res://tests/playtest/HorizonDifficultyMatches.gd"


func _buy_assault_support(factory, repair_scene):
	var human = game._get_human_player()
	var start = game.simulation_time
	var before = [human.resource_a, human.resource_b]
	var cost = load("res://source/match/FactionCatalog.gd").cost(human, "RepairRobot")
	var report = {
		"time": start,
		"funds": before,
		"queue": factory.size(),
		"population": human.population(true),
		"cost": cost,
		"wait_enabled": "--wait-assault-support" in OS.get_cmdline_user_args()
	}
	var job = factory.produce(repair_scene)
	report.initially_admitted = job != null
	if job == null:
		# Retain the earned blocked-purchase world before any change of orders or spending policy.
		game.hud._toggle_pause()
		var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
		var store = load("res://source/match/saves/SaveFile.gd").new()
		_check(
			store.write_file(evidence_prefix + "-purchase-archive.json", capture.capture(game)),
			"Blocked support archive failed"
		)
		game.hud._toggle_pause()
	if report.wait_enabled:
		while job == null and not game.finished and game.simulation_time - start < 60:
			# Existing orders, production and harvesting continue. Hold new discretionary
			# guard purchases until this support job can be funded through the ordinary queue.
			_track_air()
			_keep_capturers()
			await _frames(30)
			job = factory.produce(repair_scene)
	report.admitted = job != null
	report.wait_seconds = game.simulation_time - start
	report.funds_after = [human.resource_a, human.resource_b]
	report.paid_cost = job.paid_cost if job != null else {}
	FileAccess.open(evidence_prefix + "-purchase.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("HORIZON SUPPORT ", JSON.stringify(report))
	return job != null
