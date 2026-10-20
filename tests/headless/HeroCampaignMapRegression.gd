extends "res://tests/headless/HeroCampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://hero-map-%d.json" % OS.get_process_id()
	for id in Campaigns.stories():
		paused = false
		await _make_operation(id)
		for frame in 600:
			if game.navigation.terrain.is_synchronized():
				break
			await process_frame
		_check(game.navigation.terrain.is_synchronized(), "Map bake did not finish: " + id)
		var nav = game.navigation.terrain.navigation_map_rid
		var start = NavigationServer3D.map_get_closest_point(nav, game.campaign_hero.unit.position)
		var fields = get_nodes_in_group("resource_units")
		_check(fields.size() >= 32, "Campaign lost its resource fields: " + id)
		for field in fields:
			_check(
				_reachable(nav, start, field.position, 3),
				"Unreachable resource: %s %s" % [id, field.position]
			)
		for objective in Campaigns.stories()[id].objectives:
			_check(
				_reachable(nav, start, game._point(objective.point), 5),
				"Unreachable objective: %s %s" % [id, objective.title]
			)
			if objective.kind == "escort":
				_check(
					_reachable(nav, start, game._point(objective.destination), 3),
					"Unreachable extraction: " + id
				)
		print("Campaign map routes: ", id, " fields=", fields.size())
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Campaign map access: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _reachable(nav, start: Vector3, target: Vector3, radius: float):
	for index in 12:
		var angle = index * TAU / 12
		var side = target + Vector3(cos(angle), 0, sin(angle)) * radius
		var closest = NavigationServer3D.map_get_closest_point(nav, side)
		if Vector2(closest.x, closest.z).distance_to(Vector2(side.x, side.z)) > .25:
			continue
		var route = NavigationServer3D.map_get_path(nav, start, closest, true)
		if not route.is_empty() and route[-1].distance_to(closest) < .1:
			return true
	return false
