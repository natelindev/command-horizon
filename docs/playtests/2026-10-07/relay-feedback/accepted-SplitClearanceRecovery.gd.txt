extends "res://tests/playtest/SplitDifficultyMatches.gd"

var reinforcements = null
var clearance = preload("res://tests/playtest/reference/SplitClearance.gd").new()


func _run():
	var source = "res://docs/playtests/2026-10-07/relay-feedback/mode-0-archive.json"
	evidence_prefix = "res://docs/playtests/2026-10-07/relay-feedback/recovery-0"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			source = argument.trim_prefix("--archive=")
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
	if "--reinforce" in OS.get_cmdline_user_args():
		reinforcements = load("res://tests/playtest/reference/SplitReinforcements.gd").new()
	path = "user://split-clearance-%d.json" % OS.get_process_id()
	await _prepare_display()
	var data = Store.new().read_file(source)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Contested uplink restore failed")
	if not loaded.ok:
		quit(2)
		return
	game = loaded.game
	game.progress_path = path
	difficulty = game._enemy.difficulty
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp,
			"Recovery changed position/HP"
		)
	await _frames(10)
	_check(
		paused and game.simulation_time == data.simulation_time, "Restored contested clock advanced"
	)
	_check(
		game.controlled_relays() < 2 and game.waves_sent == 6, "Archive is not earned final contest"
	)
	await _review_recovery("loaded")
	game.hud._toggle_pause()
	var start = game.simulation_time
	while not game.finished and game.simulation_time - start < 180:
		if reinforcements != null:
			reinforcements.step(game)
			if reinforcements.retake_changed:
				clearance.targets.clear()
		clearance.step(game)
		await _frames(30)
	_check(
		game.finished and game.result == "Victory",
		"Explicit clearance failed to finish earned uplink"
	)
	await _review_recovery("result")
	var result = _sample()
	result.elapsed = game.simulation_time - start
	result.orders = clearance.orders
	if reinforcements != null:
		result.paid = [reinforcements.spent.x, reinforcements.spent.y]
		result.dispatched = reinforcements.dispatched.size()
		result.replacements = reinforcements.replacements
		_check(
			reinforcements.spent == Vector2(88 + 6 * reinforcements.replacements, 20),
			"Paid recovery budget differs from queued force"
		)
	result.errors = errors.duplicate()
	result.timeline = timeline
	FileAccess.open(evidence_prefix + ".json", FileAccess.WRITE).store_string(
		JSON.stringify(result, "\t")
	)
	print(
		"SPLIT RECOVERY result=",
		game.result,
		" elapsed=",
		result.elapsed,
		" orders=",
		clearance.orders
	)
	await _cleanup()
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Split clearance recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _prepare_display():
	pass


func _restore_display():
	pass


func _review_recovery(_label):
	pass
