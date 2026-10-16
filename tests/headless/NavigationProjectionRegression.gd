extends "res://tests/headless/MapResourceBalanceRegression.gd"


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["BigArena", "BastionDesert", "CoastalFoundry"]:
		await _create("res://source/match/maps/" + map_name + ".tscn")
		_compare_projection(map_name)
		var terrain = game.navigation.terrain
		# Exercise the conservative path while new geometry is pending publication.
		terrain._on_schedule_navigation_rebake(constants.Match.Navigation.Domain.TERRAIN)
		_compare_projection(map_name + " pending")
		await _frames(120)
		for frame in 600:
			if terrain.is_synchronized():
				break
			await physics_frame
		_compare_projection(map_name + " rebaked")
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Navigation projection: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _compare_projection(label):
	var random = RandomNumberGenerator.new()
	random.seed = 1789
	var terrain = game.navigation.terrain
	for index in 1500:
		var point = Vector3(
			random.randf_range(-2, game.map.size.x + 2),
			[-2.0, 0.0, .6, 2.0, 8.0][index % 5],
			random.randf_range(-2, game.map.size.y + 2)
		)
		var expected = NavigationServer3D.map_get_closest_point(terrain.navigation_map_rid, point)
		var actual = terrain.closest_point(point)
		_check(
			actual.distance_to(expected) < .001, label + ": projection mismatch at " + str(point)
		)
