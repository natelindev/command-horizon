extends "res://tests/headless/MacroEconomyRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var fields = load("res://source/match/economy/LegacyHomeFields.gd")
	for map_name in fields.MAPS:
		var settings = _settings("bastion", "helix", false)
		settings.map_path = "res://source/match/maps/%s.tscn" % map_name
		game = await _start(settings)
		human = game._get_human_player()
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		var worker = _unit(human, "Worker")
		var plans = game.map.get_meta("home_field_plans", [])
		_check(
			plans.size() == game.map.get_node("SpawnPoints").get_child_count(),
			map_name + " lacks a safe plan per start"
		)
		if plans.is_empty():
			game.queue_free()
			await _frames(6)
			continue
		if "--native-crowd-runtime" in OS.get_cmdline_user_args():
			_check(
				worker.get_node("Movement")._native_handle >= 0,
				"Home save fixture disabled native binding"
			)
		var origin = game.map.ground_point(plans[0].origin)
		var deposits = get_nodes_in_group("resource_units").filter(
			func(deposit): return deposit.harvest_origin.is_equal_approx(origin)
		)
		_check(deposits.size() == 7, map_name + " lost its five-material/two-electronics home")
		var materials = deposits.filter(func(deposit): return "resource_a" in deposit)
		_check(
			materials.all(func(deposit): return deposit.resource_a == 600),
			map_name + " changed faction-neutral home stock"
		)
		worker.issue_manual_order(harvest.new(materials[0]))
		paused = true
		var speed = worker.movement_speed
		var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
		var saved = capture.capture(game)
		_check(saved != null, map_name + " capture failed: " + capture.error)
		if saved != null:
			var worker_id = capture._reference(worker)
			game.restoring = true
			_check(fields.standardize(game), "Restore guard rejected the match")
			game.restoring = false
			game.settings.mission_id = "campaign_guard_probe"
			_check(fields.standardize(game), "Campaign guard rejected the match")
			game.settings.mission_id = ""
			_check(
				capture.capture(game).resources == saved.resources,
				"Restore/campaign guard rewrote resource state"
			)
			var restore = load("res://source/match/saves/MatchRestore.gd").new()
			var loaded = await restore.restore(self, saved)
			_check(loaded.ok, map_name + " restore failed: " + loaded.get("error", ""))
			if loaded.ok:
				game = loaded.game
				worker = restore.entities[worker_id]
				var after = capture.capture(game)
				_check(
					after != null and after.resources == saved.resources,
					map_name + " changed resource IDs/positions/stocks/origins on restore"
				)
				_check(
					is_equal_approx(worker.movement_speed, speed),
					map_name + " applied Mule travel factor twice on restore"
				)
				_check(
					worker.action.get_resource_unit().harvest_origin.is_equal_approx(origin),
					map_name + " lost the archived field assignment"
				)
		paused = false
		game.queue_free()
		await _frames(6)
	for error in _errors:
		push_error(error)
	print("Legacy home save: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
