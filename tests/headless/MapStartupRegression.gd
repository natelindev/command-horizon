extends "res://tests/headless/Skirmish.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var previous_rid = RID()
	for map_name in ["PlainAndSimple", "BigArena", "PlainAndSimple", "BigArena"]:
		var settings = _settings("bastion", "helix", false)
		settings.map_path = "res://source/match/maps/%s.tscn" % map_name
		settings.players[1].spawn_index_offset = (
			constants.Match.MAPS[settings.map_path].players / 2 - 1
		)
		var game = load("res://source/match/Skirmish.tscn").instantiate()
		game.settings = settings
		game.map = load(settings.map_path).instantiate()
		var expected = {}
		for deposit in game.map.get_node("Resources").find_children("*", "Area3D", true, false):
			expected[deposit] = deposit.position
		print(
			"MAP INITIAL ",
			map_name,
			" size=",
			game.map.size,
			" mesh=",
			game.map.get_node("Geometry/Terrain").mesh.size
		)
		root.add_child(game)
		current_scene = game
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		await _frames(120)
		var nav = game.navigation.terrain.navigation_map_rid
		print("MAP READY ", map_name, " nav=", nav, " previous=", previous_rid)
		for deposit in expected:
			var displacement = (deposit.position - expected[deposit]) * Vector3(1, 0, 1)
			_check(
				displacement.length() < .01,
				(
					"Map switch moved authored deposit: %s %s -> %s"
					% [map_name, expected[deposit], deposit.position]
				)
			)
		# Open middle-right ground, away from spawn HQs and the perimeter rocks.
		var endpoint = Vector3(game.map.size.x * .8, 0, game.map.size.y * .5)
		var closest = NavigationServer3D.map_get_closest_point(nav, endpoint)
		_check(
			(closest * Vector3(1, 0, 1)).distance_to(endpoint) < 3,
			"New map retained old navigation bounds"
		)
		previous_rid = nav
		game.queue_free()
		# Menu transitions may create the next scene before the server has flushed
		# the previous world's navigation polygons. Exercise that exact ordering.
		await game.tree_exited
	for message in _errors:
		push_error(message)
	print("Map startup: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
