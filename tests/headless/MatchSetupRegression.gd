extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _setup_match()
	await _teams()
	await _platforms()
	paused = false
	game.queue_free()
	await _frames(3)
	for message in errors:
		push_error(message)
	print("Match setup and repair docking: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _setup_match():
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	menu.preferences_path = "user://match-setup-test-%d.cfg" % OS.get_process_id()
	root.add_child(menu)
	menu._map_list.select(9)
	menu._on_map_list_item_selected(9)
	menu._select_start(0, 3)
	menu._select_start(1, 2)
	_check(
		menu._slots.map(func(slot): return slot.location) == [3, 2, 1, 0],
		"Start selectors did not swap occupied locations"
	)
	menu._game_mode.select(1)
	menu._apply_teams(1)
	menu._enemy_faction.select(2)
	menu._difficulty.select(2)
	menu._save_preferences()
	menu._load_preferences()
	var settings = menu._create_match_settings()
	_check(
		settings.players.map(func(side): return side.spawn_index) == [3, 2, 1, 0],
		"Start preferences were lost"
	)
	_check(
		settings.players.map(func(side): return side.team) == [0, 0, 1, 1],
		"2v2 settings lost teams"
	)
	_check(
		settings.players[2].faction == "frontier" and settings.players[2].difficulty == 2,
		"Shared AI faction/difficulty choices were lost"
	)
	menu._game_mode.select(2)
	var outnumbered = menu._create_match_settings()
	_check(
		outnumbered.players.map(func(side): return side.team) == [0, 1, 1, 1], "1v3 teams changed"
	)
	menu._game_mode.select(0)
	var free_for_all = menu._create_match_settings()
	_check(free_for_all.players.all(func(side): return side.team == -1), "FFA retained alliances")
	# Retired preferences cannot silently change the rules behind the simplified UI.
	var legacy = ConfigFile.new()
	legacy.load(menu.preferences_path)
	for key in ["resources", "visibility", "doctrine", "events"]:
		legacy.set_value("setup", key, 2)
	legacy.set_value("setup", "random_starts", true)
	legacy.set_value("setup", "mode", 3)
	legacy.erase_section_key("setup", "locations")
	legacy.set_value("setup", "slots", [[1, 1, 3, 0], [1, 1, 2, 0], [1, 1, 1, 0], [1, 1, 0, 0]])
	legacy.save(menu.preferences_path)
	menu._load_preferences()
	var standard = menu._create_match_settings()
	_check(standard.starting_resources_multiplier == 1, "Hidden resource multiplier survived")
	_check(standard.visibility == 0, "Hidden visibility override survived")
	_check(standard.tactical_doctrine == "balanced", "Hidden doctrine override survived")
	_check(standard.battlefield_events, "Hidden event toggle survived")
	_check(
		standard.players.slice(1).all(
			func(side): return side.faction == "frontier" and side.difficulty == 2
		),
		"Hidden per-player overrides replaced the visible AI choices"
	)
	_check(
		standard.players.all(func(side): return side.team == -1), "Retired custom teams survived"
	)
	var starts = standard.players.map(func(side): return side.spawn_index)
	_check(starts == [3, 2, 1, 0], "Hidden random starts replaced selected locations")
	DirAccess.remove_absolute(menu.preferences_path)
	menu.queue_free()
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(90)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
		var hq = _units(side, "CommandCenter")[0]
		var start = game.map.find_child("SpawnPoints").get_child(side.start_index()).global_position
		_check(
			hq.global_position_yless.distance_to(start * Vector3(1, 0, 1)) < 1.0,
			"Actual HQ ignored selected start"
		)
	_check(game._get_human_player().resource_a == 60, "Starting resource multiplier ignored")


func _teams():
	var sides = get_nodes_in_group("players")
	var human = sides[0]
	var ally = sides[1]
	var enemy = sides[2]
	var rules = load("res://source/match/combat/CombatRules.gd")
	var infantry = _units(human, "Infantry")[0]
	var friend = _units(ally, "Infantry")[0]
	_check(not rules.can_target(infantry, friend), "Allies can attack each other")
	_check(
		rules.can_target(infantry, _units(enemy, "Infantry")[0]), "Team combat disallowed enemies"
	)
	_check(ally in game.visible_players, "Team vision omitted allied player")
	friend.position = Vector3(100, 0, 100)
	var contact = _units(enemy, "Infantry")[0]
	contact.position = friend.position + Vector3(1, 0, 0)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, contact), "Allied observation did not share contact")
	var goal = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")._enemy_start(
		game, ally
	)
	_check(
		(
			goal
			!= (
				game.map.find_child("SpawnPoints").get_child(human.start_index()).position
				* Vector3(1, 0, 1)
			)
		),
		"AI chose an allied start for attack"
	)
	paused = true
	var snapshot = Snapshot.new().capture(game)
	_check(snapshot != null, "Team snapshot capture failed")
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(snapshot), "Team snapshot invalid: " + schema.error)
	var corrupt = snapshot.duplicate(true)
	corrupt.settings.players[1].spawn_index = corrupt.settings.players[0].spawn_index
	_check(not schema.validate(corrupt), "Save validation allowed duplicate starts")
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Team restore failed: " + loaded.get("error", ""))
	if loaded.ok:
		game = loaded.game
		_check(
			game._get_human_player().is_allied_with(get_nodes_in_group("players")[1]),
			"Restore lost alliance"
		)
	paused = false


func _platforms():
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var human = game._get_human_player()
	var recovery = load("res://source/match/units/actions/RecoveringAtService.gd")
	var context = load("res://source/match/players/human/UnitActionsController.gd")
	for faction in ["bastion", "helix", "frontier"]:
		human.faction = faction
		var base = _units(human, "CommandCenter")[0].global_position + Vector3(8, 0, 8)
		var depot = load("res://source/match/units/RepairDepot.tscn").instantiate()
		game._setup_and_spawn_unit(depot, Transform3D(Basis(), base), human, false)
		var tank = load("res://source/match/units/Tank.tscn").instantiate()
		game._setup_and_spawn_unit(
			tank, Transform3D(Basis(), base + Vector3(0, 0, -5)), human, false
		)
		await _frames(60)
		tank.hp = tank.hp_max * 0.4
		var before = tank.hp
		game.repair_service.service(1.0)
		_check(tank.hp == before, faction + ": depot repaired a vehicle beside the platform")
		_check(context.context_kind(tank, depot) == "recover", "Right-click depot did not recover")
		tank.issue_manual_order(recovery.new(depot, true))
		await _frames(260)
		print(
			"DOCK ",
			faction,
			" point=",
			tank.position,
			" depot=",
			depot.position,
			" hp=",
			tank.hp,
			" action=",
			tank.action,
			" move=",
			tank.get_node("Movement")._has_destination,
			" paused=",
			paused
		)
		_check(depot.services(tank), faction + ": vehicle failed to board platform")
		_check(
			tank.global_position.y > depot.global_position.y + 0.08,
			faction + ": vehicle did not rise onto deck"
		)
		_check(tank.hp > before, faction + ": docked vehicle did not repair")
		paused = true
		var position_before = tank.position
		before = tank.hp
		await _frames(15)
		_check(tank.hp == before and tank.position == position_before, "Paused docking advanced")
		paused = false
		tank.hp = tank.hp_max
		await _frames(130)
		print("EXIT ", faction, " point=", tank.position, " action=", tank.action)
		_check(
			tank.global_position_yless.distance_to(depot.global_position_yless) >= 3.0,
			"Repaired vehicle did not vacate bay"
		)
		tank.queue_free()
		depot.queue_free()
		await _frames(10)
	# A team wins after the final opponent falls, even if the human HQ fell first.
	var sides = get_nodes_in_group("players")
	for index in [0, 2, 3]:
		game._eliminate(
			sides[index], sides[index].get_children().filter(func(unit): return "type" in unit)
		)
	game._check_outcome(0.0)
	_check(game.finished and game.result == "Victory", "Victory did not follow surviving team")
