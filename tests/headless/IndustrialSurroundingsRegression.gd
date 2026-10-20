extends "res://tests/headless/IndustrialRegression.gd"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, INDUSTRIAL)
		_enemy().set_process(false)
		await _frames(40)
		_geometry()
		_check(await _industrial_routes() == true, "Industrial routes/archive aborted")
		_geometry()
		_check(await _infantry_access() == true, "Relay access aborted")
		_check(
			await _relay_and_restore(game._get_human_player(), _enemy()) == true,
			"Relay archive aborted"
		)
		paused = false
		game.queue_free()
		await _frames(5)
		_check(await _industrial_economy(faction) == true, "Economy aborted")
	await _skirmish("bastion", "res://source/match/maps/PlainAndSimple.tscn")
	var overlay = game.get_node("FogOfWar/ScreenOverlay").material_override
	_check(
		(
			overlay.get_shader_parameter("exterior_visibility") == null
			or is_zero_approx(overlay.get_shader_parameter("exterior_visibility"))
		),
		"Public scenery setting leaked"
	)
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Industrial surroundings: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry():
	var map = game.map
	var exterior = map.exterior
	_check(exterior.models.size() == 23, "Industrial perimeter composition changed")
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string("res://art/environment/industrial-surroundings-manifest.json")
	)
	_check(manifest.size() == 5, "Perimeter kit missing")
	for asset in manifest.values():
		_check(
			asset.radius <= asset.radius_limit and asset.height <= asset.height_limit,
			"Asset exceeds declared envelope"
		)
	for model in exterior.models:
		var point = model.position
		var radius = model.get_meta("exterior_radius")
		_check(
			(
				point.x + radius < 0
				or point.z + radius < 0
				or point.x - radius > 128
				or point.z - radius > 104
			),
			"Scenic envelope enters playable rectangle"
		)
	for x in range(-16, 145, 2):
		for z in [-17.5, -15.0, -12.5]:
			_check(
				is_zero_approx(exterior.height_at(Vector2(x, z))), "Embankment covers rail ballast"
			)
	for entry in exterior.LANDMARKS:
		for angle in 12:
			var point = entry[1] + Vector2.from_angle(angle * TAU / 12) * entry[2] * entry[4]
			_check(
				absf(exterior.height_at(point) - exterior.height_at(entry[1])) < .001,
				"Exterior structure has an uneven foundation"
			)
	_check(
		exterior.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Scenery acquired physics"
	)
	for node in exterior.find_children("*", "Node3D", true, false):
		_check(not node.is_in_group("terrain_navigation_input"), "Scenery entered navigation")
	for point in _vertices(exterior):
		_check(
			point.x <= 0 or point.z <= 0 or point.x >= 128 or point.z >= 104,
			"Imported scenery enters battlefield"
		)
	for body in map.flight_obstacles:
		var obstacle = body.get_node("MovementObstacle")
		# Garrisonable neutral buildings carry flat targeting/selection ground quads;
		# only the imported model shares the navigation and sight envelope.
		var points = PackedVector3Array()
		for child in body.get_children():
			if child.name != "NeutralBuilding":
				points.append_array(_vertices(child))
		for point in points:
			var offset = point - body.position
			_check(
				Vector2(offset.x, offset.z).length() <= obstacle.radius + .002,
				"Industrial model exceeds ground envelope"
			)
			_check(
				offset.y <= obstacle.sight_height + .002, "Industrial model exceeds roof envelope"
			)
	var arrays = exterior.ground.mesh.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var point = arrays[Mesh.ARRAY_VERTEX][index]
		_check(arrays[Mesh.ARRAY_NORMAL][index].y > .2, "Terrain normal inverted")
		var edge = (
			(
				(is_zero_approx(point.x) or is_equal_approx(point.x, 128))
				and point.z >= 0
				and point.z <= 104
			)
			or (
				(is_zero_approx(point.z) or is_equal_approx(point.z, 104))
				and point.x >= 0
				and point.x <= 128
			)
		)
		if edge:
			_check(
				absf(point.y) < .001 and arrays[Mesh.ARRAY_NORMAL][index].y > .999,
				"Terrain edge seam"
			)
	print("PASS imported industrial envelopes, exterior mesh, seam and navigation isolation")


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points
