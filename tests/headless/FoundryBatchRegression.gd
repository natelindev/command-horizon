extends "res://tests/headless/BrokenFoundryRegression.gd"

var prefix = "res://docs/playtests/2026-10-07/foundry-production/blocked"


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
	path = "user://foundry-batch-%d.json" % OS.get_process_id()
	difficulty = 2
	await _prepare_display()
	await _make_match()
	game.hud._toggle_pause()
	game.alarm = true
	game._check_outcome(10.1)
	var funds = _funds()
	game._check_outcome(45)
	for entry in game.nodes:
		_check(
			(
				entry.batches == 1
				and entry.left == 0
				and entry.unit.get_node("ProductionQueue").size() == 3
			),
			"Capacity rejection consumed a batch or admitted partial jobs"
		)
		_check(game.batch_wait_reason(entry) == "Queue space needed", "Capacity reason missing")
	_check(_funds() == funds, "Waiting batch charged resources")
	await _frames(6)
	_check(
		(
			"Waiting" in game.hud._node_labels[0].text
			and "Queue space" in game.hud._node_labels[0].tooltip_text
		),
		"HUD hides waiting batch reason"
	)
	await _review("queue-wait")
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var data = capture.capture(game)
	_check(store.write_file(prefix + "-archive.json", data), "Waiting archive write failed")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var restored = await restore.restore(self, store.read_file(prefix + "-archive.json"))
	_check(restored.ok, "Waiting archive restore failed")
	if not restored.ok:
		quit(2)
		return
	game = restored.game
	game.progress_path = path
	await _frames(30)
	var again = capture.capture(game)
	_check(
		(
			again.mission == data.mission
			and paused
			and game.simulation_time == data.simulation_time
			and _funds() == funds
		),
		"Paused archive changed pending batch or funds"
	)
	for saved in data.units:
		if saved.role == "VehicleFactory":
			var actual = again.units.filter(func(unit): return unit.id == saved.id)[0]
			_check(actual.production == saved.production, "Restoration changed paid queue/timers")
	await _review("loaded")
	game.hud._toggle_pause()
	var start = game.simulation_time
	while (
		game.nodes.any(func(entry): return entry.batches < 2) and game.simulation_time - start < 30
	):
		await _frames(15)
	for entry in game.nodes:
		var queue_size = entry.unit.get_node("ProductionQueue").size()
		_check(entry.batches == 2 and queue_size == 5, "Space release missed full batch")

	# Twelve paid Helix tanks at 22 M / 10 E each; foundry tanks pay no chip fee.
	_check(_funds() == [336, 180], "Resumed full batches charged wrong amounts")
	print("FOUNDRY BATCH RESUME elapsed=", game.simulation_time - start)
	game.hud._toggle_pause()
	await _review("resumed")
	game._check_outcome(45)
	var doomed = game.nodes[0].unit
	var before_death = _funds()
	doomed.hp = 0
	game._check_outcome(0)
	game.hud._toggle_pause()
	await _frames(120)
	_check(
		game.nodes[0].disabled and game.nodes[0].unit == null and game.nodes[0].batches == 2,
		"Destroyed waiting node retained future production"
	)
	_check(not is_instance_valid(doomed), "Destroyed factory retained paid jobs")
	_check(_funds() == before_death, "Factory destruction refunded or charged jobs")
	await _close()
	for reason in ["Funds needed", "Lab required", "Unit limit"]:
		await _denial(reason)
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Foundry batch regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _denial(reason):
	await _make_match()
	game.hud._toggle_pause()
	game.alarm = true
	var entry = game.nodes[0]
	entry.left = 0
	var extras = []
	if reason == "Funds needed":
		game._enemy.resource_a = 44
		game._enemy.resource_b = 28
	elif reason == "Lab required":
		_units(game._enemy, "CommandLab")[0].queue_free()
		await _frames(6)
	else:
		while game._enemy.population(true) < 98:
			var unit = game._spawn("Infantry", game._enemy, Vector3(145, 0, 105))
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			extras.append(unit)
	var funds = _funds()
	game._start_batch(entry)
	await _frames(6)
	_check(game.batch_wait_reason(entry) == reason, "Wrong denial reason: " + reason)
	_check(
		(
			entry.batches == 0
			and entry.left == 0
			and entry.unit.get_node("ProductionQueue").size() == 0
			and _funds() == funds
		),
		"Denied batch consumed jobs/funds: " + reason
	)
	_check(
		(
			"Waiting" in game.hud._node_labels[0].text
			and reason in game.hud._node_labels[0].tooltip_text
		),
		"Waiting reason missing in HUD: " + reason
	)
	await _review(reason.to_lower().replace(" ", "-"))
	if reason == "Funds needed":
		game._enemy.resource_a = 600
		game._enemy.resource_b = 300
	elif reason == "Lab required":
		game._spawn("CommandLab", game._enemy, Vector3(145, 0, 87))
	else:
		for unit in extras:
			unit.queue_free()
		await _frames(6)
	game._start_batch(entry)
	_check(
		(
			entry.batches == 1
			and entry.unit.get_node("ProductionQueue").size() == 3
			and _funds() == [534, 270]
		),
		"Cleared constraint did not admit exactly one paid batch"
	)
	await _close()


func _funds():
	return [game._enemy.resource_a, game._enemy.resource_b]


func _review(_label):
	pass


func _prepare_display():
	pass


func _restore_display():
	pass
