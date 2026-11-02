extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var production


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	production = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		_check(await _procurement(faction) == true, faction + ": procurement did not finish")
		# A failed fixture must not leave a second live match for the next faction.
		if is_instance_valid(game):
			paused = false
			game.queue_free()
			await _frames(5)
	for message in errors:
		push_error(message)
	print("Frontier AI production: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _procurement(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	var human = game._get_human_player()
	var player = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type == "Worker":
			unit.issue_manual_order(null)
	await _frames(60)
	paused = true
	var factory = _units(player, "VehicleFactory")[0]
	var lab = _units(player, "CommandLab")[0]
	factory.production_queue.cancel_all()
	player._production_index = 0
	# This exact-price fixture isolates hardware procurement. Research saving
	# has its own live-income and priority checks in ResearchEconomyRegression.
	player.coordination_unlocked = true
	var cost = factions.production_cost(player, "Tank")
	var units = [factory, lab]
	_check(player._research_candidate(units).is_empty(), "Procurement fixture reserves research")
	var requests = production.requests(game, player, units)
	_check(requests.size() == 1 and requests[0].role == "Tank", "Expected one tank request")
	if requests.size() != 1:
		return false
	_check(requests[0].cost == cost, faction + ": AI forecast differs from the factory price")
	_check(factory.production_queue.size() == 0, "Read-only forecast changed the queue")
	player.resource_a = cost.resource_a
	player.resource_b = cost.resource_b - 1
	player._train(units, "")
	_check(factory.production_queue.size() == 0, "AI bought a tank it could not afford")
	_check(
		player.resource_a == cost.resource_a and player.resource_b == cost.resource_b - 1,
		"Unfunded purchase partially spent resources"
	)
	player.resource_b = cost.resource_b
	player._train(units, "")
	var queue = factory.production_queue.get_elements()
	_check(queue.size() == 1, "Funded AI job was not purchased")
	if queue.size() != 1:
		return false
	var job = queue[0]
	_check(job.paid_cost == cost, "Actual AI charge differs from forecast")
	_check(player.resource_a == 0 and player.resource_b == 0, "AI purchase did not use exact funds")
	_check(
		job.time_total == factions.duration(player, "Tank"),
		"AI purchase did not use actual factory duration"
	)
	var previous = _units(player, "Tank")
	paused = false
	for frame in 3600:
		await physics_frame
		if factory.production_queue.size() == 0:
			break
	paused = true
	var built = _units(player, "Tank").filter(func(tank): return tank not in previous)
	if built.size() != factions.batch_size(faction, "Tank"):
		print(
			"AI DELIVERY ",
			faction,
			" queued=",
			factory.production_queue.size(),
			" left=",
			job.time_left,
			" reason=",
			factory.production_queue.blocked_reason(),
			" producer=",
			factory.position,
			" power=",
			player.production_factor()
		)
	_check(built.size() == factions.batch_size(faction, "Tank"), "Paid factory job did not deliver the faction batch")
	if faction == "frontier":
		lab.hp = 0
		await _frames(3)
		player._production_index = 0
		player.resource_a = cost.resource_a
		player.resource_b = cost.resource_b
		player._train([factory], "")
		queue = factory.production_queue.get_elements()
		_check(queue.size() == 1, "Lost lab blocked tank production")
		_check(player.resource_a == 0 and player.resource_b == 0, "Lab-loss purchase charged extra")
		factory.production_queue.cancel_all()
		_check(
			player.resource_a == cost.resource_a and player.resource_b == cost.resource_b,
			"Fallback refund differs"
		)
	paused = false
	game.queue_free()
	await _frames(5)
	return true
