extends "res://tests/headless/AirCorridorRegression.gd"

const EVIDENCE = "res://docs/playtests/2026-10-07/air-environment/"


func _run():
	path = "user://air-environment-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	await _make_match()
	paused = true
	var report = _geometry()
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	if not baseline:
		var original = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE + "baseline.json"))
		_check(report.blockers.size() == 13, "Quarry obstacle count changed")
		for index in report.blockers.size():
			var old = original.blockers[index]
			var item = report.blockers[index]
			_check(
				(
					Vector3(item.position[0], item.position[1], item.position[2]).is_equal_approx(
						Vector3(old.position[0], old.position[1], old.position[2])
					)
					and is_equal_approx(item.radius, old.radius)
					and is_equal_approx(item.sight, old.sight)
				),
				"Quarry obstacle contract changed"
			)
			_check(
				item.mesh_radius <= item.radius and item.mesh_height <= item.sight,
				"Quarry visual exceeds gameplay envelope"
			)
		for index in report.routes.size():
			_check(
				absf(report.routes[index] - original.routes[index]) < .05,
				"Quarry route length changed"
			)
		var exterior = game.map.get_node("QuarryExterior")
		for point in _vertices(exterior):
			_check(
				point.x < 0 or point.x > 144 or point.z < 0 or point.z > 104,
				"Quarry exterior enters playable space"
			)
		_check(
			exterior.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Exterior gained physics"
		)
		_check(
			exterior.find_children("*", "NavigationObstacle3D", true, false).is_empty(),
			"Exterior gained navigation"
		)
		for point in [Vector2(-2, 52), Vector2(146, 52), Vector2(72, -2), Vector2(72, 106)]:
			_check(is_zero_approx(exterior.height_at(point)), "Exterior terrain seam is raised")
	for unit in game._enemy.get_children():
		if unit.is_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.position = Vector3(48, scout.position.y, 51)
	scout.issue_manual_order(moving.new(Vector3(84, 0, 51)))
	var minimum = INF
	var start = game.simulation_time
	while scout.position.x < 83 and game.simulation_time - start < 30:
		await physics_frame
		if absf(scout.position.x - 66) < 2:
			minimum = minf(minimum, scout.position.y)
	_check(minimum < INF and scout.position.x >= 83, "Aircraft crossing failed")
	if not baseline:
		_check(minimum >= 4.0, "Aircraft still crosses inside quarry geometry")
	report.crossing_root_y = minimum
	print("AIR ENVIRONMENT ", JSON.stringify(report))
	(
		FileAccess
		. open(EVIDENCE + ("baseline.json" if baseline else "geometry.json"), FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	await _close()
	for message in errors:
		push_error(message)
	print("Air environment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry():
	var report = {"blockers": [], "routes": []}
	for obstacle in game.map.get_node("Decorations").find_children(
		"*", "NavigationObstacle3D", true, false
	):
		var body = obstacle.get_parent()
		var center = body.global_position
		var reach = obstacle.radius + .25
		_check(
			not game.battlefield.line_clear(
				center + Vector3(-reach, 1, 0), center + Vector3(reach, 1, 0)
			),
			"Quarry no longer blocks ground fire"
		)
		_check(
			game.battlefield.line_clear(
				center + Vector3(-reach, 3.2, 0), center + Vector3(reach, 3.2, 0)
			),
			"Quarry blocks sight above its envelope"
		)
		var radius = 0.0
		var height = 0.0
		for point in _vertices(body):
			var offset = point - body.global_position
			radius = maxf(radius, Vector2(offset.x, offset.z).length())
			height = maxf(height, offset.y)
		report.blockers.append(
			{
				"position": [body.position.x, body.position.y, body.position.z],
				"radius": obstacle.radius,
				"sight": obstacle.sight_height,
				"mesh_radius": radius,
				"mesh_height": height
			}
		)
	var nav = game.navigation.get_navigation_map_rid_by_domain(1)
	for pair in [
		[Vector3(36, 0, 52), game.map.SCREEN],
		[game.map.LAUNCH, game.map.SITES[0]],
		[game.map.LAUNCH, game.map.SITES[1]]
	]:
		var route = NavigationServer3D.map_get_path(nav, pair[0], pair[1], true)
		_check(route.size() >= 2, "Quarry ground route missing")
		report.routes.append(_length(route))
	var air = game.navigation.get_navigation_map_rid_by_domain(0)
	report.routes.append(
		_length(NavigationServer3D.map_get_path(air, game.map.LAUNCH, game.map.EXIT, true))
	)
	return report


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points
