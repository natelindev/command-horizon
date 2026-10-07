extends "res://tests/headless/CoastalRegression.gd"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, COASTAL)
		_enemy().set_process(false)
		await _frames(40)
		_geometry()
		_check(await _coastal_routes() == true, "Coastal routes/archive check aborted")
		_geometry()
		paused = false
		game.queue_free()
		await _frames(5)
		_check(await _coastal_economy(faction) == true, "Coastal economy check aborted")
	await _skirmish("bastion", "res://source/match/maps/PlainAndSimple.tscn")
	var overlay = game.get_node("FogOfWar/ScreenOverlay").material_override
	_check(
		(
			overlay.get_shader_parameter("exterior_visibility") == null
			or is_zero_approx(overlay.get_shader_parameter("exterior_visibility"))
		),
		"Coastal public scenery setting leaked into another map"
	)
	game.queue_free()
	await _frames(5)
	for error in errors:
		push_error(error)
	print("Coastal environment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry():
	var map = game.map
	var exterior = map.exterior
	_check(exterior.models.size() == 28, "Coastal landmark composition changed")
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string("res://art/environment/coastal-environment-manifest.json")
	)
	_check(manifest.size() == 6, "Coastal environment kit missing")
	for asset in manifest.values():
		_check(asset.radius <= asset.radius_limit, "Coastal kit exceeds radius contract")
		_check(asset.height <= asset.height_limit, "Coastal kit exceeds height contract")
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
			"Exterior footprint enters playable rectangle: " + model.name
		)
		_check(
			model.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Scenic model acquired physics"
		)
		_check(not model.is_in_group("terrain_navigation_input"), "Scenic model changes navigation")
		for point_in_world in _vertices(model):
			_check(
				(
					point_in_world.x < 0
					or point_in_world.z < 0
					or point_in_world.x > 128
					or point_in_world.z > 104
				),
				"Imported exterior mesh enters battlefield: " + model.name
			)
	for body in map.flight_obstacles:
		var center = body.global_position
		var radius = body.get_meta("clearance_radius")
		var height = body.get_meta("clearance_height")
		for point in _vertices(body.get_node("Model")):
			var offset = point - center
			_check(
				Vector2(offset.x, offset.z).length() <= radius + .002,
				"Imported coastal model exceeds ground envelope: " + body.name
			)
			_check(offset.y <= height + .002, "Imported coastal model exceeds air envelope")
		_check(
			not game.battlefield.line_clear(
				center + Vector3(-radius - 2, .7, 0), center + Vector3(radius + 2, .7, 0)
			),
			"Coastal landmark lost sight/fire obstruction"
		)
	# Every newly placed interior detail stays within an existing blocker.
	for detail in map.get_node("Decorations").get_children():
		if not detail is MeshInstance3D or detail.position.y < .3:
			continue
		for local in detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point = detail.global_transform * local
			var covered = map.flight_obstacles.any(
				func(body):
					return (
						(
							Vector2(point.x - body.position.x, point.z - body.position.z).length()
							< body.get_meta("clearance_radius")
						)
						and point.y <= body.get_meta("clearance_height")
					)
			)
			_check(covered, "New interior equipment encroaches on a route")
	var arrays = exterior.ground.mesh.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var point = arrays[Mesh.ARRAY_VERTEX][index]
		_check(
			point.x <= 0 or point.z <= 0 or point.x >= 128 or point.z >= 104,
			"Exterior terrain changed playable ground"
		)
		_check(arrays[Mesh.ARRAY_NORMAL][index].y > .2, "Coastal terrain has inverted normals")
		var side_edge = (
			(is_zero_approx(point.x) or is_equal_approx(point.x, 128))
			and point.z >= 17
			and point.z <= 104
		)
		var rear_edge = is_equal_approx(point.z, 104) and point.x >= 0 and point.x <= 128
		if side_edge or rear_edge:
			_check(
				absf(point.y) < .001 and arrays[Mesh.ARRAY_NORMAL][index].y > .999,
				"Coastal terrain has a height or lighting seam"
			)
	var human = game._get_human_player()
	_check(
		not game.battlefield.is_observed(human, _units(_enemy(), "CommandCenter")[0]),
		"Scenic coast revealed hidden enemy"
	)
	_check(
		map.get_node("Geometry/HarborWater").mesh.size == Vector2(220, 196),
		"Sea no longer spans coastal surroundings"
	)
	print("PASS coastal imported envelopes, exterior terrain/seams, sight/fire and fog isolation")


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points
