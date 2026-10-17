extends "res://tests/headless/SaveRestoreEdges.gd"

const Vegetation = preload("res://source/match/maps/Vegetation.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in [
		"DesertFrontier",
		"AlpineRelay",
		"CoastalFoundry",
		"ExpandedDesertFrontier",
		"ExpandedAlpineRelay",
		"ExpandedCoastalFoundry"
	]:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		paused = true
		var plants = game.map.find_children("*", "Node3D", true, false).filter(
			func(node): return node.has_meta("vegetation_kind")
		)
		_check(not plants.is_empty(), map_name + ": no mature vegetation")
		for plant in plants:
			_check(
				plant.find_children("*", "CollisionObject3D", true, false).is_empty(),
				map_name + ": scenic plant acquired physics"
			)
			_check(
				not plant.is_in_group("terrain_navigation_input"),
				map_name + ": scenic plant changes routes"
			)
			_check(Vegetation.bounds(plant).size.y >= 1.5, map_name + ": miniature plant")
		for scatter in game.map.find_children("*", "MultiMeshInstance3D", true, false):
			if not scatter.name.ends_with("Cover"):
				continue
			_check(
				not scatter.name.contains("Sage") and not scatter.name.contains("DryScrub"),
				map_name + ": flat placeholder returned"
			)
			_check(
				scatter.multimesh.mesh.get_aabb().size.y >= 1.5,
				map_name + ": batched plant is flat"
			)
		var nav = game.navigation.get_navigation_map_rid_by_domain(1)
		_check(
			NavigationServer3D.map_get_iteration_id(nav) > 0,
			map_name + ": navigation never became ready"
		)
		var starts = game.map.get_node("SpawnPoints").get_children()
		var route = NavigationServer3D.map_get_path(
			nav, starts[0].global_position, starts[1].global_position, true
		)
		_check(route.size() >= 2, map_name + ": home-to-home route blocked")
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Vegetation maps: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
