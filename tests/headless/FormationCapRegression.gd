extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var utility = load("res://source/match/utils/UnitMovementUtils.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		var members = []
		for index in 100:
			members.append(
				_spawn("Tank" if index % 2 == 0 else "AdvancedTank", _human, Vector3(30, 0, 30))
			)
		await _frames(30)
		for unit in members:
			unit.position = Vector3(30, 0, 30)
		var extent = _game.map.size
		for point in [
			Vector3(0.1, 0, 0.1),
			Vector3(extent.x - 0.1, 0, extent.y - 0.1),
			Vector3(extent.x / 2, 0, extent.y / 2)
		]:
			var pairs = utility.crowd_moved_to_new_pivot(members, point)
			_check(pairs.size() == 100, "Full formation lost members")
			var overlaps = 0
			for index in pairs.size():
				var unit = pairs[index][0]
				var destination = pairs[index][1]
				var nav = unit.get_node("Movement").get_navigation_map()
				var projected = NavigationServer3D.map_get_closest_point(nav, destination)
				_check(destination.y == 0, "Formation leaked navigation bake height")
				_check(
					destination.distance_to(projected * Vector3(1, 0, 1)) < 0.1,
					"Full formation contains an off-mesh destination"
				)
				for earlier in index:
					if (
						destination.distance_to(pairs[earlier][1])
						< unit.radius + pairs[earlier][0].radius
					):
						overlaps += 1
			_check(overlaps == 0, "Full formation collapses into overlapping destinations")
			print("FORMATION CAP ", faction, " point=", point, " overlaps=", overlaps)
		await _clear()
		_game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Formation cap regression: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
