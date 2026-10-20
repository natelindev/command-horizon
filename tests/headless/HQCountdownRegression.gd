extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _countdown_case(faction)
	for outcome in ["Victory", "Defeat", "Draw"]:
		await _outcome_case(outcome)
	for message in errors:
		push_error(message)
	print("HQ countdowns: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _mirror(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = false
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(60)
	game.hud.pause_after_load()


func _countdown_case(faction):
	await _mirror(faction)
	var sides = get_nodes_in_group("players")
	var human = game._get_human_player()
	var enemy = sides.filter(func(side): return side != human)[0]
	_check("Relays" in game.objective_text(), "Normal regional objective lost relays")
	_units(human, "CommandCenter")[0].hp = 0
	await _frames(3)
	_check(
		"Your HQ" in game.objective_text() and "60s" in game.objective_text(),
		"Paused own HQ loss has no full recovery window"
	)
	_check(not "Enemy HQ" in game.objective_text(), "Intact enemy HQ has a recovery deadline")
	await _review_countdown(faction + "-own")
	paused = false
	await _frames(90)
	game.hud.pause_after_load()
	_units(enemy, "CommandCenter")[0].hp = 0
	await _frames(3)
	_check("Enemy HQ" in game.objective_text(), "Paused simultaneous HQ loss hides enemy window")
	paused = false
	await _frames(180)
	game.hud.pause_after_load()
	var text = game.objective_text()
	_check(text.count("HQ") == 2, faction + ": simultaneous countdown omits a side")
	_check(
		text.begins_with("Your HQ") and "Enemy HQ" in text,
		"Mirror match has ambiguous recovery ownership"
	)
	_check("complete" in text.to_lower(), "HQ warning does not require a completed rebuild")
	var times = [game._defeat_timers[human], game._defeat_timers[enemy]]
	_check(times[0] < times[1] - 1, "Staggered HQ losses did not create distinct timers")
	_check(
		(
			("Your HQ · complete a rebuild within %ds." % ceili(times[0])) in text
			and ("Enemy HQ · prevent a rebuild for %ds." % ceili(times[1])) in text
		),
		"Objective does not show each side's independent countdown"
	)
	await _frames(30)
	_check(
		times == [game._defeat_timers[human], game._defeat_timers[enemy]],
		"Paused countdown advanced"
	)
	await _review_countdown(faction + "-both")
	var file = "user://hq-countdowns-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(file, Snapshot.new().capture(game)), "Simultaneous HQ save failed")
	var loaded = await Restore.new().restore(self, store.read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Simultaneous HQ restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for side in [human, enemy]:
		side.set_process(false)
	_check(game.objective_text() == text, "Archive changed simultaneous objective feedback")
	_check(
		times == [game._defeat_timers[human], game._defeat_timers[enemy]],
		"Archive changed recovery timers"
	)
	await _review_countdown(faction + "-restored")
	# A paid foundation is not sufficient. The existing construction action
	# must complete it before the ordinary outcome loop resets the countdown.
	var cost = load("res://source/match/FactionCatalog.gd").cost(human, "CommandCenter", true)
	human.resource_a = cost.resource_a
	human.resource_b = cost.resource_b
	var worker = _units(human, "Worker")[0]
	var handler = human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/CommandCenter.tscn"))
	handler._active_blueprint_node.position = Vector3(14, 0, 50)
	_check(
		handler._calculate_blueprint_position_validity() == handler.BlueprintPositionValidity.VALID,
		"HQ rebuild fixture has no legal site"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	worker.get_node("Selection").select()
	handler._finish_structure_placement()
	await _frames(3)
	var foundations = _units(human, "CommandCenter")
	_check(not foundations.is_empty(), "Paid HQ foundation missing")
	if foundations.is_empty():
		return
	_check(human.resource_a == 0 and human.resource_b == 0, "HQ foundation was not fully paid")
	_check(
		not foundations[0].is_constructed() and "Your HQ" in game.objective_text(),
		"Foundation hid own recovery deadline"
	)
	await _review_countdown(faction + "-foundation")
	paused = false
	for frame in 3300:
		await _frames(1)
		if human.has_completed_structure("CommandCenter") or game.finished:
			break
	_check(
		human.has_completed_structure("CommandCenter"),
		"Paid HQ reconstruction did not complete in time"
	)
	await _frames(3)
	game.hud.pause_after_load()
	_check(
		not "Your HQ" in game.objective_text() and "Enemy HQ" in game.objective_text(),
		"Completed own HQ did not leave enemy deadline visible"
	)
	_check(
		game._defeat_timers[human] == 60.0 and not game.finished,
		"Successful rebuild failed to reset defeat clock"
	)
	await _review_countdown(faction + "-rebuilt")
	paused = false
	# Wait out the enemy's remaining recovery window (plus one second) rather
	# than a fixed span that depends on how quickly the own HQ was rebuilt.
	for frame in ceili(game._defeat_timers[enemy] * 60) + 60:
		await _frames(1)
		if game.finished:
			break
	_check(game.result == "Victory", "Enemy's unrecovered HQ did not resolve to Victory")
	print("HQ RECOVERY ", faction, " paid rebuild, two timers, archive and victory")
	paused = false
	game.queue_free()
	await _frames(5)


func _outcome_case(outcome):
	await _mirror("frontier")
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var victims = [human, enemy] if outcome == "Draw" else [human if outcome == "Defeat" else enemy]
	for side in victims:
		_units(side, "CommandCenter")[0].hp = 0
		game._defeat_timers[side] = 0.1
	await _frames(3)
	paused = false
	await _frames(12)
	_check(game.finished and game.result == outcome, "HQ expiry changed outcome: " + outcome)
	paused = false
	game.queue_free()
	await _frames(5)


func _review_countdown(_label):
	pass
