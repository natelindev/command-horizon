extends "res://tests/headless/Skirmish.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("helix", "bastion", false)
	settings.map_path = "res://source/match/maps/battlefields/PinebreakValleyMap.tscn"
	var game = await _start(settings)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var player = get_nodes_in_group("players").filter(func(side): return side.faction == "bastion")[0]
	var expansion = load("res://source/match/players/skirmish-ai/SkirmishExpansion.gd")
	var economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	var units = player._units()
	var hq = units.filter(func(unit): return unit.type == "CommandCenter")[0]
	game.simulation_time = 30.0
	_check(
		not expansion.field_depleted(game, [hq]),
		"Untouched elevated home field was treated as depleted"
	)
	_check(
		expansion.next_site(game, player, units, []) == null,
		"AI expanded before depletion or its scheduled timing"
	)
	var home = game.map.layout.bases[player.start_index()]
	var field_origin = game.map.ground_point(home.field)
	for deposit in get_nodes_in_group("resource_units"):
		if deposit.harvest_origin.is_equal_approx(field_origin):
			var property = "resource_a" if "resource_a" in deposit else "resource_b"
			deposit.set(property, floori(deposit.get(property) * .4))
	_check(
		expansion.field_depleted(game, [hq]),
		"AI missed the 60% depletion threshold on elevated terrain"
	)
	var position = expansion.next_site(game, player, units, [])
	_check(position != null, "AI did not open a safe secondary field after 60% depletion")
	if position != null:
		for role in ["Barracks", "VehicleFactory"]:
			var structure = load(factions.scene_path("bastion", role)).instantiate()
			game._setup_and_spawn_unit(
				structure,
				Transform3D(Basis(), hq.global_position + Vector3(7, 0, 5)),
				player,
				false
			)
		await _frames(5)
		_check(
			player._next_building(player._units()) == "ForwardRefinery",
			"Bastion AI did not choose its forward refinery for expansion"
		)
		var refinery = load(Catalog.scene_path("ForwardRefinery")).instantiate()
		game._setup_and_spawn_unit(refinery, Transform3D(Basis(), position), player, false)
		await _frames(5)
		units = player._units()
		_check(
			(
				economy.headquarters(units, refinery.global_position_yless + Vector3(3, 0, 0))
				== refinery
			),
			"AI ignored the nearest completed forward drop-off"
		)
		_check(
			expansion.worker_bonus(units) == 5,
			"AI failed to budget workers for its forward refinery"
		)
		_check(
			not expansion.field_depleted(game, expansion.headquarters(units)),
			"Depleted home triggered another expansion before the new field was mined"
		)
		_check(
			expansion.next_site(game, player, units, []) == null,
			"AI chained expansions from the first exhausted field"
		)
	await _capture_economic_site(game, player)
	game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Economic AI: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _capture_economic_site(game, player):
	var sites = load("res://source/match/players/skirmish-ai/SkirmishSites.gd")
	var refinery = game.map.points_of_interest.filter(func(site): return site.kind == "refinery")[0]
	var soldiers = []
	for index in 4:
		var infantry = load(factions.scene_path("bastion", "Infantry")).instantiate()
		game._setup_and_spawn_unit(
			infantry,
			Transform3D(Basis(), refinery.global_position + Vector3(3.0 + index, 0, 0)),
			player,
			false
		)
		infantry.stance = infantry.Stance.HOLD_FIRE
		soldiers.append(infantry)
	await _frames(90)
	var prior = {}
	for soldier in soldiers:
		prior[soldier] = soldier.action
	var assigned = sites.command(game, player, player._units(), soldiers, [])
	_check(assigned.size() == 1, "Economic AI failed to assign one capture detachment")
	if assigned.is_empty():
		return
	var target = assigned[0].action._target_unit
	_check(target == refinery, "Economic AI ignored the nearest undefended refinery")
	_check(
		(
			(
				soldiers
				. filter(func(unit): return unit not in assigned and unit.action == prior[unit])
				. size()
			)
			== 3
		),
		"Economic AI stripped the entire home infantry screen"
	)
	await _frames(850)
	_check(refinery.player == player, "Economic AI's capture order did not acquire refinery")
	_check(
		sites.command(game, player, player._units(), soldiers, []).all(
			func(unit): return unit.action._target_unit != refinery
		),
		"Economic AI reassigned an already friendly refinery"
	)
