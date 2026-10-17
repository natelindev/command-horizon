extends "res://tests/headless/Skirmish.gd"

const Battlefields = preload("res://source/match/maps/BattlefieldCatalog.gd")
var harvest


func _run():
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["RedrockDivide", "SunkenExchange", "FrostboundCrown"]:
		var settings = _settings("bastion", "helix", true)
		settings.map_path = "res://source/match/maps/%s.tscn" % map_name
		for index in range(2, Battlefields.MAPS[map_name].players):
			var side = settings.players[1].duplicate()
			side.faction = "frontier" if index == 2 else "bastion"
			settings.players.append(side)
		var game = await _start(settings)
		var players = get_nodes_in_group("players")
		var resources = game.map.get_node("Resources").get_children()
		var funds = []
		var initial_tanks = []
		for index in players.size():
			var player = players[index]
			player.set_process(false)
			for unit in player.get_children():
				if "type" in unit and unit.movement_speed > 0:
					unit.issue_manual_order(null)
			var workers = player.get_children().filter(
				func(unit): return "type" in unit and unit.type == "Worker"
			)
			workers[0].issue_manual_order(harvest.new(resources[index * 7]))
			workers[1].issue_manual_order(harvest.new(resources[index * 7 + 5]))
			var factory = _unit(player, "VehicleFactory")
			initial_tanks.append(
				player.get_children().filter(
					func(unit): return "type" in unit and unit.type == "Tank"
				)
			)
			_check(
				factory.production_queue.produce(load(Catalog.scene_path("Tank"))) != null,
				"Could not queue paid tank"
			)
			funds.append(Vector2i(player.resource_a, player.resource_b))
		await _frames(2400)
		for index in players.size():
			var player = players[index]
			_check(
				player.resource_a > funds[index].x,
				"%s side %d cannot return materials" % [map_name, index]
			)
			_check(
				player.resource_b > funds[index].y,
				"%s side %d cannot return electronics" % [map_name, index]
			)
			var produced = player.get_children().filter(
				func(unit):
					return (
						"type" in unit and unit.type == "Tank" and unit not in initial_tanks[index]
					)
			)
			_check(produced.size() == 1, "%s side %d factory exit blocked" % [map_name, index])
			if produced.size() == 1:
				var start = game.map.get_node("SpawnPoints").get_child(index).position
				var target = start + Vector3(0, 0, 26 if start.z < game.map.size.y / 2 else -26)
				produced[0].issue_manual_order(
					load("res://source/match/units/actions/Moving.gd").new(target)
				)
		await _frames(900)
		for index in players.size():
			var produced = players[index].get_children().filter(
				func(unit):
					return (
						"type" in unit and unit.type == "Tank" and unit not in initial_tanks[index]
					)
			)
			if produced.size() == 1:
				var start = game.map.get_node("SpawnPoints").get_child(index).position
				var target = start + Vector3(0, 0, 26 if start.z < game.map.size.y / 2 else -26)
				_check(
					(produced[0].position * Vector3(1, 0, 1)).distance_to(target) < 2,
					"%s side %d produced tank cannot leave base" % [map_name, index]
				)
		print("OPENING ", map_name, " sides=", players.size())
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Battlefield opening economy and production: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
