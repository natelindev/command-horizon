extends "res://tests/headless/ResourceMapEconomyRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	for entry in load("res://source/main-menu/Play.gd").MAPS:
		var map_name = entry[0].get_file().get_basename()
		await _create(entry[0], "bastion")
		_check_playable_ground(map_name)
		await _close()
	for message in _errors:
		push_error(message)
	print("Map playability: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _check_playable_ground(map_name):
	var nav = game.navigation.terrain.navigation_map_rid
	var polygon = PackedVector2Array(game.map.get_topdown_polygon_2d())
	var origin = game.map.get_node("SpawnPoints").get_child(0).position + Vector3(0, 0, 12)
	origin = NavigationServer3D.map_get_closest_point(nav, origin)
	var space = game.get_world_3d().direct_space_state
	var camera = game.get_node("IsometricCamera3D")
	var land = 0
	var navigable = 0
	var reachable = 0
	# Authored terrain deliberately leaves water, rock, cliffs and inaccessible
	# tops unwalkable; only open ground counts as land there.
	var terrain = game.map.get("terrain")
	for x in range(8, int(game.map.size.x), 8):
		for z in range(8, int(game.map.size.y), 8):
			if not Geometry2D.is_point_in_polygon(Vector2(x, z), polygon):
				continue
			var flat = Vector2(x, z)
			var point = game.map.ground_point(flat)
			var query = PhysicsRayQueryParameters3D.create(
				point + Vector3(0, 50, 0), point - Vector3.UP * 3.0, 1
			)
			_check(
				not space.intersect_ray(query).is_empty(),
				"Visible land cannot receive mouse clicks: %s %s" % [map_name, point]
			)
			camera.set_position_safely(point * Vector3(1, 0, 1))
			_check(
				camera._calculate_pivot_point().distance_to(point * Vector3(1, 0, 1)) < .05,
				"Camera cannot reach map interior: %s %s" % [map_name, point]
			)
			if terrain != null:
				var i = clampi(int(x / terrain.RESOLUTION), 0, terrain.columns - 1)
				var j = clampi(int(z / terrain.RESOLUTION), 0, terrain.rows - 1)
				if not terrain.is_walkable_cell(i, j):
					continue
			land += 1
			var nearest = NavigationServer3D.map_get_closest_point(nav, point + Vector3.UP * .5)
			if (nearest * Vector3(1, 0, 1)).distance_to(point * Vector3(1, 0, 1)) > 1:
				continue
			navigable += 1
			var route = NavigationServer3D.map_get_path(nav, origin, nearest, true)
			if not route.is_empty() and route[-1].distance_to(nearest) < 1:
				reachable += 1
	# Water, structures and ridges deliberately occupy some land. Tiny pockets
	# between deposits may be isolated; missing regions or disconnected sectors may not.
	_check(navigable > land * .85, "Navigation covers too little land: " + map_name)
	_check(reachable > navigable * .99, "Disconnected battlefield sector: " + map_name)
	print(
		"PLAYABILITY %s land=%d navigable=%d reachable=%d" % [map_name, land, navigable, reachable]
	)
