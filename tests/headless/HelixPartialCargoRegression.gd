extends "res://tests/headless/ResourceFieldRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	seed(1441)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	game = await _start(_settings("helix", "bastion", false))
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	workers = get_nodes_in_group("units").filter(
		func(unit): return unit.player == human and unit.type == "Worker"
	)
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(15)
	var worker = workers[0]
	if "--enable-native-kernels" in OS.get_cmdline_user_args():
		_check(
			worker._native_state != null and worker.get_node("Movement")._native_runtime != null,
			"Partial cargo test did not bind native movement"
		)
	# A depleted one-unit field must drive home; only a full skimmer may phase.
	await _depletion_and_archive()
	# Carried partial cargo survives a restored field order and a destroyed HQ,
	# then delivers once to the replacement before advancing its queued move.
	await _hq_and_queue()
	game.queue_free()
	await _frames(5)
	for error in _errors:
		push_error(error)
	print("Helix partial cargo: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
