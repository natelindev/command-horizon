extends "res://tests/headless/BrokenFoundryRegression.gd"

const EVIDENCE = "res://docs/playtests/2026-10-07/foundry-environment/"


func _run():
	path = "user://foundry-environment-%d.json" % OS.get_process_id()
	await _make_match()
	paused = true
	var report = _geometry()
	var baseline = "--baseline" in OS.get_cmdline_user_args()
	if not baseline:
		var original = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE + "baseline.json"))
		_check(report.blockers.size() == original.blockers.size(), "Foundry blocker count changed")
		for index in report.blockers.size():
			var item = report.blockers[index]
			var old = original.blockers[index]
			for key in ["radius", "sight", "mesh_radius", "mesh_height"]:
				_check(is_equal_approx(item[key], old[key]), "Foundry blocker geometry changed")
			for axis in 3:
				_check(
					is_equal_approx(item.position[axis], old.position[axis]),
					"Foundry blocker moved"
				)
		for index in report.routes.size():
			_check(
				absf(report.routes[index] - original.routes[index]) < .01, "Foundry route changed"
			)
		var exterior = game.map.exterior
		for point in _vertices(exterior):
			_check(
				point.x < 0 or point.x > 160 or point.z < 0 or point.z > 116,
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
		for point in [Vector2(-2, 58), Vector2(162, 58), Vector2(80, -2), Vector2(80, 118)]:
			_check(is_zero_approx(exterior.height_at(point)), "Raised terrain seam")
		_check(
			game.map.get_node("FoundryGroundCover").get_child_count() == 8, "Ground cover missing"
		)
		var cover = game.map.get_node("FoundryGroundCover")
		for model in cover.get_children():
			_check(model.get_meta("vegetation_height", 0) >= 1.6, "Shrub remains miniature")
		for branch in [exterior, cover]:
			for child in branch.find_children("*", "Node", true, false):
				_check(
					not child.is_in_group("terrain_navigation_input"),
					"Scenery joined navigation input"
				)
		_check(
			(
				exterior.ground.mesh.surface_get_material(0)
				== game.map.get_node("Geometry/Terrain").mesh.material
			),
			"Exterior ground material is discontinuous"
		)
		var human = game._get_human_player()
		_check(
			not game.battlefield.is_observed(human, _units(game._enemy, "Infantry")[0]),
			"Scenery exposed opposition"
		)
	(
		FileAccess
		. open(EVIDENCE + ("baseline.json" if baseline else "geometry.json"), FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	if not baseline:
		await _archives()
	await _close()
	for message in errors:
		push_error(message)
	print("Foundry environment: %d failures" % errors.size())
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
			"Landmark no longer blocks low sight"
		)
		_check(
			game.battlefield.line_clear(
				center + Vector3(-reach, 8.0, 0), center + Vector3(reach, 8.0, 0)
			),
			"Landmark blocks overhead sight"
		)
		var radius = 0.0
		var height = 0.0
		for point in _vertices(body):
			var offset = point - body.global_position
			radius = maxf(radius, Vector2(offset.x, offset.z).length())
			height = maxf(height, offset.y)
		_check(
			radius <= obstacle.radius and height <= obstacle.sight_height,
			"Landmark exceeds gameplay envelope"
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
		[Vector3(35, 0, 26), Vector3(72, 0, 26)],
		[Vector3(35, 0, 90), Vector3(72, 0, 90)],
		[Vector3(76, 0, 26), Vector3(118, 0, 58)],
		[Vector3(76, 0, 90), Vector3(118, 0, 58)],
		[Vector3(42, 0, 43), Vector3(68, 0, 43)]
	]:
		var route = NavigationServer3D.map_get_path(nav, pair[0], pair[1], true)
		_check(route.size() >= 2, "Foundry route missing")
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


func _archives():
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var current = capture.capture(game)
	_check(
		store.write_file(EVIDENCE + "current-archive.json", current),
		"Environment archive write failed"
	)
	for source in [
		EVIDENCE + "current-archive.json",
		"res://docs/playtests/2026-10-07/foundry-production/verified-budget-late.json"
	]:
		var saved = store.read_file(source)
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var result = await restore.restore(self, saved)
		_check(result.ok, "Environment archive rejected")
		if not result.ok:
			return
		game = result.game
		game.progress_path = path
		await _frames(6)
		var again = capture.capture(game)
		_check(
			(
				paused
				and again.mission == saved.mission
				and again.simulation_time == saved.simulation_time
			),
			"Environment changed paused mission state"
		)
		_check(again.players == saved.players, "Environment changed saved player economy")
		for unit in saved.units:
			var matches = again.units.filter(func(candidate): return candidate.id == unit.id)
			_check(matches.size() == 1, "Saved unit lost")
			if matches.size() != 1:
				continue
			for field in ["position", "hp", "production"]:
				if unit.has(field):
					_check(
						matches[0].get(field) == unit[field], "Environment changed saved " + field
					)
		_check(game.map.exterior != null, "Restored mission lacks exterior")
		print("FOUNDRY ENVIRONMENT ARCHIVE ", source)
