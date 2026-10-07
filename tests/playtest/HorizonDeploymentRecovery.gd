extends "res://tests/playtest/HorizonDifficultyMatches.gd"

var deployment_recovery = preload("res://tests/playtest/reference/HorizonRecovery.gd").new()


func _run():
	var source = "res://docs/playtests/2026-10-07/horizon-difficulties/initial-2-archive.json"
	evidence_prefix = "res://docs/playtests/2026-10-07/horizon-difficulties/earned-retake"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			source = argument.trim_prefix("--archive=")
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	path = "user://horizon-recovery-%d.json" % OS.get_process_id()
	seed(12701)
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var data = store.read_file(source)
	_check(data != null, "Could not read earned finale: " + store.error)
	if data == null:
		quit(2)
		return
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Could not restore earned finale: " + result.get("error", ""))
	if not result.ok:
		quit(2)
		return
	game = result.game
	game.progress_path = path
	difficulty = game._enemy.difficulty
	challenge = game.settings.campaign_challenge
	var human = game._get_human_player()
	var funds = Vector2(human.resource_a, human.resource_b)
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp,
			"Earned restoration changed position or health"
		)
	await _frames(30)
	_check(
		paused and game.simulation_time == data.simulation_time,
		"Earned restoration advanced the clock"
	)
	_check(Vector2(human.resource_a, human.resource_b) == funds, "Earned restoration changed funds")
	_check(
		game.command_destroyed and not game.zone_held(),
		"Recovery source is not the lost-deployment scenario"
	)
	var library = load("res://source/match/programs/ProgramLibrary.gd").new()
	var config = library.defaults("hold_service")
	config.radius = 12.0
	service = library.save_version("Deployment recovery", config, path + ".programs")
	_check(service != null, "Recovery service doctrine was not saved")
	await _review_restored()
	game.hud._toggle_pause()
	var start = game.simulation_time
	while not game.finished and game.simulation_time - start < 300:
		_retake()
		await _frames(30)
	_check(game.finished and game.result == "Victory", "Earned deployment recovery did not win")
	print(
		"HORIZON RECOVERY elapsed=",
		game.simulation_time - start,
		" paid_infantry=",
		deployment_recovery.replacements
	)
	_report()
	await _review_finished()
	await _close()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".programs")
	for message in errors:
		push_error(message)
	print("Horizon deployment recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _retake():
	deployment_recovery.step(game, service)


func _review_restored():
	pass


func _review_finished():
	pass
