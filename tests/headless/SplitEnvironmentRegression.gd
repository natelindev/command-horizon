extends "res://tests/headless/SplitSignalRegression.gd"

const EVIDENCE = "res://docs/playtests/2026-10-07/split-environment/"
# Current navigation contract; the dated playtest evidence remains historical.
const GEOMETRY_FIXTURE = "res://tests/fixtures/split-environment-geometry.json"


func _run():
	path = "user://split-environment-%d.json" % OS.get_process_id()
	await _make_match()
	paused = true
	var report = _geometry()
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	if not baseline:
		var original = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_FIXTURE))
		_check(report.blockers.size() == original.blockers.size(), "Split blocker count changed")
		for index in report.blockers.size():
			var item = report.blockers[index]
			var old = original.blockers[index]
			for key in ["radius", "sight", "mesh_radius", "mesh_height"]:
				_check(is_equal_approx(item[key], old[key]), "Split blocker geometry changed")
			for axis in 3:
				_check(
					is_equal_approx(item.position[axis], old.position[axis]), "Split blocker moved"
				)
		for index in report.routes.size():
			_check(absf(report.routes[index] - original.routes[index]) < .01, "Split route changed")
		var exterior = game.map.exterior
		for point in _vertices(exterior):
			_check(
				point.x < 0 or point.x > 108 or point.z < 0 or point.z > 88,
				"Exterior enters playable space"
			)
		_check(
			exterior.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Scenery gained physics"
		)
		_check(
			exterior.find_children("*", "NavigationObstacle3D", true, false).is_empty(),
			"Scenery gained navigation"
		)
		for point in [Vector2(-2, 44), Vector2(110, 44), Vector2(54, -2), Vector2(54, 90)]:
			_check(is_zero_approx(exterior.height_at(point)), "Raised terrain seam")
		_check(
			game.map.get_node("SplitGroundCover").get_child_count() == 12, "Ground cover missing"
		)
		var human = game._get_human_player()
		_check(
			not game.battlefield.is_observed(human, _units(game._enemy, "Infantry")[0]),
			"Scenery exposed opposition"
		)
	(
		FileAccess
		. open(GEOMETRY_FIXTURE if baseline else EVIDENCE + "geometry.json", FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Split environment: %d failures" % errors.size())
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
				center + Vector3(-reach, .8, 0), center + Vector3(reach, .8, 0)
			),
			"Shelf no longer blocks low sight"
		)
		_check(
			game.battlefield.line_clear(
				center + Vector3(-reach, 3.2, 0), center + Vector3(reach, 3.2, 0)
			),
			"Shelf blocks overhead sight"
		)
		var radius = 0.0
		var height = 0.0
		for point in _vertices(body):
			var offset = point - body.global_position
			radius = maxf(radius, Vector2(offset.x, offset.z).length())
			height = maxf(height, offset.y)
		_check(
			radius <= obstacle.radius and height <= obstacle.sight_height,
			"Shelf exceeds gameplay envelope"
		)
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
		[Vector3(18, 0, 44), Vector3(44, 0, 23)],
		[Vector3(18, 0, 44), Vector3(44, 0, 65)],
		[Vector3(46, 0, 23), Vector3(68, 0, 44)],
		[Vector3(46, 0, 65), Vector3(68, 0, 44)]
	]:
		var route = NavigationServer3D.map_get_path(nav, pair[0], pair[1], true)
		_check(route.size() >= 2, "Split route missing")
		report.routes.append(_length(route))
	return report


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points


func _length(route):
	var distance = 0.0
	for index in range(1, route.size()):
		distance += route[index - 1].distance_to(route[index])
	return distance
