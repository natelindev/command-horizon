extends "res://tests/headless/SupplyLineRegression.gd"

const EVIDENCE = "res://docs/playtests/2026-10-07/supply-environment/"


func _run():
	path = "user://supply-environment-%d.json" % OS.get_process_id()
	await _make_match()
	paused = true
	var report = _geometry()
	if "--baseline" in OS.get_cmdline_user_args():
		FileAccess.open(EVIDENCE + "baseline.json", FileAccess.WRITE).store_string(
			JSON.stringify(report, "\t")
		)
	else:
		var baseline = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE + "baseline.json"))
		_check(report.blockers.size() == 4, "Environment changed blocker count")
		for index in report.blockers.size():
			var old = baseline.blockers[index]
			var item = report.blockers[index]
			_check(
				(
					Vector3(item.position[0], item.position[1], item.position[2]).is_equal_approx(
						Vector3(old.position[0], old.position[1], old.position[2])
					)
					and is_equal_approx(item.radius, old.radius)
					and is_equal_approx(item.sight, old.sight)
				),
				"Environment changed a blocker contract"
			)
			_check(
				item.mesh_radius <= 5.0 and item.mesh_height <= 3.0,
				"Imported landmark exceeds collision/sight envelope"
			)
		for index in report.routes.size():
			_check(
				absf(report.routes[index] - baseline.routes[index]) < 0.05,
				"Environment changed a convoy navigation route"
			)
		var details = game.map.get_node("RoadsideDetails")
		for vertex in _vertices(details):
			_check(vertex.y <= 0.32, "Passable roadside detail is too tall")
		var exterior = game.map.get_node("SupplyExterior")
		for point in [Vector2(-2, 0), Vector2(194, 64), Vector2(96, -2), Vector2(96, 130)]:
			_check(is_zero_approx(exterior.height_at(point)), "Exterior terrain seam is raised")
		for normal in exterior.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			_check(normal.y > 0.0, "Exterior ground normal points downward")
		for vertex in _vertices(exterior):
			_check(
				vertex.x < 0 or vertex.x > 192 or vertex.z < 0 or vertex.z > 128,
				"Exterior scenery entered the playable rectangle"
			)
		for node in [details, exterior]:
			_check(
				node.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"Scenic details gained physics"
			)
			_check(
				node.find_children("*", "NavigationObstacle3D", true, false).is_empty(),
				"Scenic details gained navigation blockers"
			)
		FileAccess.open(EVIDENCE + "final-geometry.json", FileAccess.WRITE).store_string(
			JSON.stringify(report, "\t")
		)
	await _close()
	for message in errors:
		push_error(message)
	print("Supply environment geometry: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry():
	var report = {"blockers": [], "routes": []}
	for node in game.map.get_node("Decorations").get_children():
		var blocker = node.get_node("MovementObstacle")
		var radius = 0.0
		var height = 0.0
		for vertex in _vertices(node):
			var local = vertex - node.global_position
			radius = maxf(radius, Vector2(local.x, local.z).length())
			height = maxf(height, local.y)
		report.blockers.append(
			{
				"position": [node.position.x, node.position.y, node.position.z],
				"radius": blocker.radius,
				"sight": blocker.sight_height,
				"mesh_radius": radius,
				"mesh_height": height
			}
		)
		var center = node.global_position
		_check(
			not game.battlefield.line_clear(center + Vector3(-7, 1, 0), center + Vector3(7, 1, 0)),
			"Landmark no longer blocks ground fire"
		)
		_check(
			game.battlefield.line_clear(center + Vector3(-7, 3.2, 0), center + Vector3(7, 3.2, 0)),
			"Landmark blocks sight above its envelope"
		)
	var nav = game.navigation.get_navigation_map_rid_by_domain(1)
	var points = [Vector3(18, 0, 100)] + game.map.POINTS
	for index in 3:
		var route = NavigationServer3D.map_get_path(nav, points[index], points[index + 1], true)
		_check(route.size() >= 2, "Convoy route disappeared")
		var length = 0.0
		for leg in range(1, route.size()):
			length += route[leg - 1].distance_to(route[leg])
		report.routes.append(length)
	print("SUPPLY GEOMETRY ", JSON.stringify(report))
	return report


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points
