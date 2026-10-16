extends "res://tests/headless/HeroCampaignMapRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://interior-%d.json" % OS.get_process_id()
	for id in Campaigns.OPERATIONS:
		paused = false
		await _make_operation(id)
		for frame in 600:
			if game.navigation.terrain.is_synchronized():
				break
			await process_frame
		_check(game.navigation.terrain.is_synchronized(), "Interior bake did not finish: " + id)
		var interior = game.map.get_node("CampaignInterior")
		var count = game.map.interior_obstacles.size()
		_check(count >= (2 if game.map.size.x < 120 else 6), "Sparse campaign interior: " + id)
		var quadrants = {}
		for building in game.map.interior_obstacles:
			var point = Vector2(building.position.x, building.position.z)
			quadrants[Vector2i(int(point.x > game.map.size.x / 2), int(point.y > game.map.size.y / 2))] = true
			var obstacle = building.get_node("MovementObstacle")
			_check(obstacle.is_in_group("sight_blockers"), "Scenery does not block sight: " + id)
			var height = game.map.flight_height_at(building.position, 1.5)
			_check(height >= obstacle.sight_height + 1, "Aircraft clips interior: " + id)
		_check(quadrants.size() >= 2, "Interior remains confined to one edge: " + id)
		var nav = game.navigation.terrain.navigation_map_rid
		var start = NavigationServer3D.map_get_closest_point(nav, game.campaign_hero.unit.position)
		for field in get_nodes_in_group("resource_units"):
			_check(_reachable(nav, start, field.position, 3), "Interior blocks resources: " + id)
		var life = game.map.get_node("CampaignInteriorLife")
		_check(not life.actors.is_empty(), "Interior has no ambient life: " + id)
		game.simulation_time = 20
		life._physics_process(0)
		var poses = life.actors.map(func(actor): return actor.position)
		game.simulation_time = 23
		life._physics_process(0)
		_check(
			poses != life.actors.map(func(actor): return actor.position),
			"Residents never move: " + id
		)
		game.simulation_time = 20
		life._physics_process(0)
		_check(
			poses == life.actors.map(func(actor): return actor.position),
			"Restored clock changes residents: " + id
		)
		print(
			"INTERIOR ",
			id,
			" buildings=",
			count,
			" quadrants=",
			quadrants.size(),
			" actors=",
			life.actors.size(),
			" batches=",
			interior.get_child_count() - count
		)
		game.queue_free()
		await _frames(5)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign interiors: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
