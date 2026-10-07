extends "res://tests/headless/CommandHorizonRules.gd"


func _run():
	path = "user://horizon-environment-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	await _make_match()
	_check(game.map.flight_obstacles.size() == 15, "Environment changed obstacle count")
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string("res://art/environment/manifest.json")
	)
	for asset in manifest:
		_check(
			manifest[asset].radius <= 5.6 and manifest[asset].height <= 7,
			"Art exceeds blocker: " + asset
		)
	_check(await _economy() == true, "Economy assertions aborted")
	_check(await _flight() == true, "Flight assertions aborted")
	await _close()
	await _routes(false)
	await _routes(true)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Horizon environment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _flight():
	_isolate()
	var human = game._get_human_player()
	for role in ["Drone", "Helicopter"]:
		var aircraft = _units(human, role)[0]
		aircraft.process_mode = Node.PROCESS_MODE_INHERIT
		for endpoints in [
			[Vector3(96, 0, 63), Vector3(136, 0, 63)],
			[Vector3(72, 0, 92), Vector3(104, 0, 92)],
			[Vector3(36, 0, 91), Vector3(68, 0, 91)],
			[Vector3(36, 0, 44), Vector3(68, 0, 44)]
		]:
			aircraft.position = endpoints[0]
			aircraft.get_node("Movement")._align_unit_position_to_navigation()
			aircraft.issue_manual_order(moving.new(endpoints[1]))
			var start = game.simulation_time
			var crossed = false
			while game.simulation_time - start < 18:
				await physics_frame
				var point = aircraft.position
				var close = false
				for obstacle in game.map.flight_obstacles:
					if (
						(
							Vector2(point.x - obstacle.position.x, point.z - obstacle.position.z)
							. length()
						)
						< 6.5
					):
						close = true
				if close:
					crossed = true
					_check(point.y >= 7.9, role + " clipped a landmark")
				if Vector2(point.x - endpoints[1].x, point.z - endpoints[1].z).length() < .5:
					break
			print(
				(
					"Flight %s: %s -> %s, %.2fs"
					% [role, endpoints[0], aircraft.position, game.simulation_time - start]
				)
			)
			_check(crossed, role + " never crossed the obstacle")
			_check(game.simulation_time - start < 18, role + " flight stalled")
		aircraft.process_mode = Node.PROCESS_MODE_DISABLED
	# Archive an aircraft above a solid berm and preserve its targeting/selection height.
	var aircraft = _units(human, "Helicopter")[0]
	aircraft.position = Vector3(116, 8, 63)
	aircraft.get_node("Movement").stop()
	var before = aircraft.position
	await _round_trip()
	human = game._get_human_player()
	aircraft = _units(human, "Helicopter")[0]
	_check(aircraft.position.distance_to(before) < .05, "Archive changed flight clearance position")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(116, 0, 63))
	var screen = camera.unproject_position(aircraft.position)
	var polygon = []
	for offset in [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]:
		var point = camera.get_ray_intersection_with_plane(screen + offset, Plane(Vector3.UP, 0))
		polygon.append(Vector2(point.x, point.z))
	aircraft.show()
	var selector = game.get_node("Handlers/ArealUnitSelectionHandler")
	var selected = selector._get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
		0, polygon
	)
	_check(
		selected.iterate().has(aircraft),
		"Elevated aircraft cannot be box-selected at its visible position"
	)
	# Native injected events may precede the viewport's sampled mouse position.
	# The full selection signal path must use press/release coordinates directly.
	var rect3d = game.get_node("RectangularSelection3D")
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen - Vector2(9, 9)
	var release = press.duplicate()
	release.pressed = false
	release.position = screen + Vector2(9, 9)
	rect3d._unhandled_input(press)
	rect3d._unhandled_input(release)
	_check(
		get_nodes_in_group("selected_units").has(aircraft),
		"Mouse-event rectangle failed to select elevated aircraft"
	)
	var rect2d = (
		load("res://source/generic-scenes-and-nodes/control/RectangularSelection2D.tscn")
		. instantiate()
	)
	root.add_child(rect2d)
	var recorded = []
	rect2d.finished.connect(func(rect): recorded.append(rect))
	# Reverse drag uses the same absolute rectangle as the world selection.
	press.position = screen + Vector2(9, 9)
	release.position = screen - Vector2(9, 9)
	rect2d._unhandled_input(press)
	rect2d._unhandled_input(release)
	_check(
		recorded.size() == 1 and recorded[0] == Rect2(screen - Vector2(9, 9), Vector2(18, 18)),
		"Visible selection rectangle ignored event coordinates"
	)
	rect2d.queue_free()
	# Fire down from a clear approach: actual projectile damage must still resolve.
	aircraft.position = Vector3(100, 0, 63)
	aircraft.get_node("Movement")._align_unit_position_to_navigation()
	var enemy = _units(game._enemy, "Tank")[0]
	enemy.position = Vector3(104, 0, 63)
	var hp = enemy.hp
	aircraft.process_mode = Node.PROCESS_MODE_INHERIT
	aircraft.action = load("res://source/match/units/actions/AutoAttacking.gd").new(
		aircraft.attack_range
	)
	game.battlefield.invalidate()
	for tick in 240:
		await physics_frame
	_check(enemy.hp < hp, "Aircraft failed to damage ground target after altitude change")
	_check(
		not game.battlefield.line_clear(Vector3(109, 1, 63), Vector3(123, 1, 63)),
		"Berm stopped blocking ground sight/fire"
	)

	return true


func _economy():
	_isolate()
	var human = game._get_human_player()
	var workers = _units(human, "Worker")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var loaded = [false, false, false, false]
	var returned = [false, false, false, false]
	for index in 4:
		var kind = "resource_a" if index % 2 == 0 else "resource_b"
		var deposits = get_nodes_in_group("resource_units").filter(
			func(unit):
				return (
					kind in unit and (unit.position.x < 20 if index < 2 else unit.position.x > 70)
				)
		)
		workers[index].position = deposits[0].position + Vector3(-3, 0, 3)
		workers[index].process_mode = Node.PROCESS_MODE_INHERIT
		workers[index].get_node("Movement")._align_unit_position_to_navigation()
		workers[index].issue_manual_order(harvest.new(deposits[0]))
	var start = game.simulation_time
	while game.simulation_time - start < 75 and returned.has(false):
		await physics_frame
		for index in 4:
			var cargo = workers[index].resource_a + workers[index].resource_b
			loaded[index] = loaded[index] or cargo > 0
			if loaded[index] and cargo == 0:
				returned[index] = true
	_check(
		not returned.has(false), "Landmarks obstruct home/forward material or electronics delivery"
	)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(1)
	for obstacle in game.map.flight_obstacles:
		_check(
			(
				placement.validate_agent_placement_position(obstacle.position, 2.0, [], nav)
				== placement.NOT_NAVIGABLE
			),
			"Construction accepted solid environment: " + obstacle.name
		)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(65, 0, 105), 2.0, [], nav)
			== placement.VALID
		),
		"Environment removed open construction ground"
	)
	print(
		"PASS: both resource fields deliver; solid art blocks construction; open ground permits it"
	)
	return true
