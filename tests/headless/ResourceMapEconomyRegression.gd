extends "res://tests/headless/Skirmish.gd"

var game
var harvest
var progress_path


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	progress_path = "user://resource-map-economy-%d.json" % OS.get_process_id()
	for faction in ["bastion", "helix"]:
		for map_name in [
			"BastionDesert",
			"DesertFrontier",
			"AlpineRelay",
			"IndustrialCrossroads",
			"CoastalFoundry",
			"PlainAndSimple",
			"BigArena"
		]:
			if "--coastal-only" in OS.get_cmdline_user_args() and map_name != "CoastalFoundry":
				continue
			await _create(map_name, faction)
			_check(await _fields() == true, "Map field check aborted: " + map_name)
			await _close()
	for mission in [
		"first_orders", "split_signal", "air_corridor", "broken_foundry", "command_horizon"
	]:
		if "--coastal-only" in OS.get_cmdline_user_args():
			continue
		await _create("", "bastion", mission)
		_check(await _fields() == true, "Mission field check aborted: " + mission)
		await _close()
	DirAccess.remove_absolute(progress_path)
	for message in _errors:
		push_error(message)
	print("Authored resource fields: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _create(map_name, faction, mission = ""):
	var settings = _settings(faction, "helix" if faction == "bastion" else "bastion", false)
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	var scene = "res://source/match/Skirmish.tscn"
	if not mission.is_empty():
		var operation = load("res://source/match/campaign/CampaignCatalog.gd").OPERATIONS[mission]
		settings.mission_id = mission
		settings.map_path = operation.map
		scene = operation.scene
	else:
		settings.players[1].spawn_index_offset = (
			constants.Match.MAPS[settings.map_path].players / 2 - 1
		)
	game = load(scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	if "progress_path" in game:
		game.progress_path = progress_path
	root.add_child(game)
	current_scene = game
	# Keep authored buildings and stationary armies, but isolate the resource routes
	# from combat, mission responses, automatic orders and paid production.
	game.set_process(false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.issue_manual_order(null)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(120)


func _fields():
	var human = game._get_human_player()
	var hqs = get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.type == "CommandCenter"
				and (game.settings.mission_id.is_empty() or unit.player == human)
			)
	)
	var fields = get_nodes_in_group("resource_units").filter(
		func(deposit): return "resource_b" in deposit
	)
	var failed_before = _errors.size()
	for field in fields:
		hqs.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(field.position)
					< b.position.distance_squared_to(field.position)
				)
		)
		var hq = hqs[0]
		var side = hq.player
		var materials = get_nodes_in_group("resource_units").filter(
			func(deposit): return "resource_a" in deposit
		)
		materials.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(field.position)
					< b.position.distance_squared_to(field.position)
				)
		)
		var workers = []
		for index in 2:
			var worker = load(Catalog.scene_path("Worker")).instantiate()
			game._setup_and_spawn_unit(
				worker,
				Transform3D(Basis(), hq.position + Vector3(-2 + index * 4, 0, -5)),
				side,
				false
			)
			workers.append(worker)
		await _frames(60)
		var balance = Vector2(side.resource_a, side.resource_b)
		workers[0].issue_manual_order(harvest.new(materials[0]))
		workers[1].issue_manual_order(harvest.new(field))
		var started = game.simulation_time
		for frame in 7200:
			await physics_frame
			if side.resource_a >= balance.x + 4 and side.resource_b >= balance.y + 4:
				break
		var delivered = side.resource_a >= balance.x + 4 and side.resource_b >= balance.y + 4
		var label = (
			"%s %s field %s" % [game.settings.map_path.get_file(), side.faction, field.position]
		)
		_check(delivered, label + " failed materials/electronics return")
		print(
			"FIELD ", label, " delivered=", delivered, " seconds=", game.simulation_time - started
		)
		if not delivered:
			for worker in workers:
				print(
					"  ",
					worker.position,
					" cargo=",
					worker.resource_a,
					"/",
					worker.resource_b,
					" ",
					worker.action
				)
		for worker in workers:
			worker.queue_free()
		await _frames(5)
	print(
		"MAP ECONOMY ",
		game.settings.map_path.get_file(),
		" ",
		human.faction,
		" fields=",
		fields.size(),
		" failures=",
		_errors.size() - failed_before
	)
	return true


func _close():
	paused = false
	game.queue_free()
	await _frames(5)
