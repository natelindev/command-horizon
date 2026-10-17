extends "res://tests/headless/FrontierRegression.gd"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, FRONTIER)
		_enemy().set_process(false)
		await _frames(30)
		_geometry()
		await _flight_over_shelves()
		_check(
			await _frontier_routes(game._get_human_player()) == true,
			"Desert route/archive suite aborted"
		)
		_geometry()
		paused = false
		game.queue_free()
		await _frames(5)
		await _frontier_economy(faction)
	await _skirmish("bastion", "res://source/match/maps/PlainAndSimple.tscn")
	var overlay = game.get_node("FogOfWar/ScreenOverlay").material_override
	_check(
		(
			overlay.get_shader_parameter("exterior_visibility") == null
			or is_zero_approx(overlay.get_shader_parameter("exterior_visibility"))
		),
		"Desert backdrop visibility leaked to another map"
	)
	paused = false
	game.queue_free()
	await _frames(5)
	manager.autosaves_enabled = autosaves
	print("Desert environment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry():
	var map = game.map
	_check(map.get_node("Decorations").get_child_count() == 4, "Desert blocker count changed")
	for index in range(4):
		var shelf = map.get_node("Decorations").get_child(index)
		var blocker = shelf.get_node("MovementObstacle")
		_check(
			is_equal_approx(blocker.radius, 5.8) and is_equal_approx(blocker.sight_height, 1.15),
			"Shelf gameplay envelope changed"
		)
		var center = shelf.global_position
		_check(
			not game.battlefield.line_clear(
				center + Vector3(-7, 0.8, 0), center + Vector3(7, 0.8, 0)
			),
			"Shelf no longer blocks ground sight/fire"
		)
		_check(
			game.battlefield.line_clear(center + Vector3(-7, 1.5, 0), center + Vector3(7, 1.5, 0)),
			"Shelf incorrectly blocks elevated sight/fire"
		)
		_check(
			game.battlefield.line_clear(center + Vector3(-7, 0.8, 8), center + Vector3(7, 0.8, 8)),
			"Decorative geometry blocks the open flank"
		)
		var points = _vertices(shelf.get_node("Model"))
		_check(points.size() > 1000, "Detailed shelf geometry missing")
		var highest = 0.0
		var widest = 0.0
		for point in points:
			var local = point - shelf.global_position
			highest = maxf(highest, local.y)
			widest = maxf(widest, Vector2(local.x, local.z).length())
		_check(
			highest <= 1.15 and widest <= 5.8,
			"Imported shelf exceeds actual sight/navigation bounds"
		)
	var cover = map.get_node("DesertGroundCover")
	_check(cover.get_child_count() == 12, "Desert ground cover missing")
	var variants = {}
	for plant in cover.get_children():
		variants[plant.scene_file_path] = true
		_check(
			plant.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Decorative trees gained physics"
		)
		var height = 0.0
		for vertex in _vertices(plant):
			height = maxf(height, vertex.y)
		_check(height > 6.2 and height < 7.5, "Desert trees lost their intended world scale")
	_check(variants.size() == 4, "Desert trees lack four distinct authored variants")
	var exterior = map.exterior
	_check(exterior.models.size() == 28, "Exterior landmarks or vegetation missing")
	for model in exterior.models:
		var point = model.position
		var radius = model.get_meta("exterior_radius")
		_check(
			(
				point.x + radius < 0
				or point.z + radius < 0
				or point.x - radius > 128
				or point.z - radius > 96
			),
			"Exterior asset footprint enters playable terrain"
		)
		_check(
			model.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Scenic geometry gained physics"
		)
		for vertex in _vertices(model):
			_check(
				vertex.x < 0 or vertex.z < 0 or vertex.x > 128 or vertex.z > 96,
				"Imported exterior mesh enters map"
			)
	var arrays = exterior.ground.mesh.surface_get_arrays(0)
	for point in arrays[Mesh.ARRAY_VERTEX]:
		_check(
			point.x < 0 or point.z < 0 or point.x > 128 or point.z > 96,
			"Backdrop terrain changes playable ground"
		)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var point = arrays[Mesh.ARRAY_VERTEX][index]
		var inner_edge = (
			(
				(is_equal_approx(point.x, -2) or is_equal_approx(point.x, 130))
				and point.z >= -2
				and point.z <= 98
			)
			or (
				(is_equal_approx(point.z, -2) or is_equal_approx(point.z, 98))
				and point.x >= -2
				and point.x <= 130
			)
		)
		if inner_edge:
			_check(
				is_zero_approx(point.y) and arrays[Mesh.ARRAY_NORMAL][index].y > 0.999,
				"Backdrop has a height or lighting seam at the playable plane"
			)
	var minimum_normal_y = 1.0
	for normal in arrays[Mesh.ARRAY_NORMAL]:
		minimum_normal_y = minf(minimum_normal_y, normal.y)
	_check(minimum_normal_y > 0.2, "Backdrop terrain has inverted normals")
	var human = game._get_human_player()
	_check(
		not game.battlefield.is_observed(human, _units(_enemy(), "CommandCenter")[0]),
		"Backdrop revealed hidden enemy"
	)
	print("PASS: shelf geometry/sight/fire, exterior bounds/seams/normals and hidden enemy")


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points


func _flight_over_shelves():
	var human = game._get_human_player()
	for role in ["Drone", "Helicopter"]:
		for z in [31, 65]:
			var aircraft = _spawn_alpine(role, human, Vector3(42, 1.5, z))
			aircraft.issue_manual_order(moving.new(Vector3(87, 1.5, z)))
			var crossed = false
			for frame in range(1100):
				await physics_frame
				for shelf in game.map.get_node("Decorations").get_children():
					if (
						(
							Vector2(
								aircraft.position.x - shelf.position.x,
								aircraft.position.z - shelf.position.z
							)
							. length()
						)
						< 5.8
					):
						crossed = true
						_check(aircraft.position.y >= 1.45, "Aircraft clipped new shelf geometry")
				if aircraft.position.x > 86:
					break
			_check(crossed and aircraft.position.x > 86, role + " did not cross the shelves")
			aircraft.queue_free()
			await _frames(3)
	print("PASS: real drone and strike-aircraft transit over all four shelves")
