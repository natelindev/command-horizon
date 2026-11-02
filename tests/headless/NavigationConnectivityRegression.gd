extends "res://tests/headless/MapResourceBalanceRegression.gd"


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var connectivity = load("res://source/match/orders/NavigationConnectivity.gd")
	var random = RandomNumberGenerator.new()
	random.seed = 741923
	var queries = 0
	for map_path in constants.Match.MAPS:
		await _create(map_path)
		for hovering in [false, true]:
			var movement = null
			for unit in get_nodes_in_group("units"):
				var candidate = unit.get_node_or_null("Movement")
				if candidate != null and candidate.domain == 1 and candidate._hovering == hovering:
					movement = candidate
					break
			_check(movement != null, "Missing navigation oracle fixture: " + map_path)
			if movement == null:
				continue
			var nav = movement.get_navigation_map()
			var context = connectivity.context(movement)
			for index in 240:
				var origin = Vector3(
					random.randf_range(-2, game.map.size.x + 2),
					random.randf_range(-1, 5),
					random.randf_range(-2, game.map.size.y + 2)
				)
				var target = Vector3(
					random.randf_range(-2, game.map.size.x + 2),
					random.randf_range(-1, 5),
					random.randf_range(-2, game.map.size.y + 2)
				)
				var command_projection = movement.project_command_point(target)
				var script_projection = movement._closest_navigation_point(target)
				_check(
					command_projection.distance_to(script_projection) <= .01,
					(
						"Command projection differs from steering surface: %s hover=%s point=%s native=%s script=%s"
						% [map_path, hovering, target, command_projection, script_projection]
					)
				)
				target = NavigationServer3D.map_get_closest_point(nav, target)
				var path = NavigationServer3D.map_get_path(nav, origin, target, true)
				var expected = not path.is_empty() and path[-1].distance_to(target) <= .1
				var actual = connectivity.can_reach(movement, origin, target, context)
				_check(
					actual == expected,
					(
						"Connectivity differs from NavigationServer: %s hover=%s from=%s to=%s"
						% [map_path, hovering, origin, target]
					)
				)
				queries += 1
		print("CONNECTIVITY ORACLE ", map_path.get_file(), " queries=", queries)
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Navigation connectivity: %d comparisons, %d failures" % [queries, _errors.size()])
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
