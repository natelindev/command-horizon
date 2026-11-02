extends "res://tests/headless/SaveRestoreEdges.gd"


class SelectionBody:
	extends Area3D
	var movement_domain := 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in ["BastionDesert", "AlpineRelay"]:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name, false)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		var human = game._get_human_player()
		var worker = _units(human, "Worker")[0]
		var aircraft = load("res://source/match/units/Fighter.tscn").instantiate()
		game._setup_and_spawn_unit(aircraft, Transform3D.IDENTITY, human, false)
		aircraft.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = game.get_node("IsometricCamera3D")
		for zoom in [1.0, 15.0, 60.0]:
			camera.set_size_safely(zoom)
			for yaw in [0.0, 0.9]:
				camera.rotation.y = yaw
				camera.set_position_safely(Vector3(30, 0, 30))
				_selection_checks(camera, worker, aircraft, "%s/%s/%s" % [map_name, zoom, yaw])
		await _physics_selection_checks(camera, worker, aircraft, map_name)
		await _dense_selection_checks(camera, map_name)
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Areal selection: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _dense_selection_checks(camera, label):
	var selector = game.get_node("Handlers/ArealUnitSelectionHandler")
	var rect3d = game.get_node("RectangularSelection3D")
	var bodies: Array = []
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 2, 1)
	var center := root.get_visible_rect().size * .5
	for index in 520:
		var body := SelectionBody.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		collider.shape = shape
		collider.position.y = 1.0
		body.add_child(collider)
		game.add_child(body)
		body.add_to_group("controlled_units")
		bodies.append(body)
	for yaw in [0.0, .9]:
		camera.rotation.y = yaw
		for index in bodies.size():
			var screen := center + Vector2(index % 26 - 13, index / 26 - 10) * 12
			bodies[index].global_position = camera.project_position(screen, 20.0)
		await physics_frame
		await physics_frame
		for immediate in [false, true]:
			if immediate:
				# Input can query a unit immediately after a teleport, before a tick.
				for index in range(0, bodies.size(), 7):
					bodies[index].global_position = camera.project_position(center, 10.0)
			for rect in [
				Rect2(center - Vector2.ONE * 50, Vector2.ONE * 100),
				Rect2(center - Vector2.ONE * 8, Vector2.ONE * 16),
				Rect2(Vector2.ZERO, root.get_visible_rect().size),
			]:
				var polygon = rect3d._screen_rect_2d_to_topdown_polygon_2d(rect)
				selector._physics_candidates_enabled = false
				var expected = (
					selector
					. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
						-1, polygon
					)
				)
				selector._physics_candidates_enabled = true
				var actual = (
					selector
					. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
						-1, polygon
					)
				)
				_check(
					actual.iterate() == expected.iterate(),
					(
						"%s: dense selection differs yaw=%s immediate=%s rect=%s expected=%d actual=%d"
						% [
							label,
							yaw,
							immediate,
							rect,
							expected.iterate().size(),
							actual.iterate().size()
						]
					)
				)
	for body in bodies:
		body.free()
	print("Dense selection parity: ", label, " 520 bodies, rotations and immediate teleports")


func _physics_selection_checks(camera, worker, aircraft, label):
	var selector = game.get_node("Handlers/ArealUnitSelectionHandler")
	var rect3d = game.get_node("RectangularSelection3D")
	camera.set_size_safely(15.0)
	camera.rotation.y = 0.0
	camera.set_position_safely(Vector3(30, 0, 30))
	var center = root.get_visible_rect().size * .5
	var enabled = selector._physics_candidates_enabled
	_check(
		(
			selector._selection_candidates(
				camera, PackedVector2Array([center, center, center, center])
			)
			== get_nodes_in_group("controlled_units")
		),
		label + ": degenerate marquee did not retain the screen scan"
	)
	# Keep the Area3Ds queryable while freezing simulation below their roots.
	for unit in [worker, aircraft]:
		for child in unit.get_children():
			child.process_mode = Node.PROCESS_MODE_DISABLED
		unit.process_mode = Node.PROCESS_MODE_ALWAYS
		unit.set_physics_process(false)
		unit.set_process(false)
		unit.show()
	worker.global_position = camera.project_position(center, 12.0)
	aircraft.global_position = camera.project_position(center + Vector2(40, -20), 6.0)
	await _frames(2)
	for rect in [
		Rect2(center - Vector2(8, 8), Vector2(16, 16)),
		Rect2(center - Vector2(100, 100), Vector2(200, 200)),
		Rect2(center + Vector2(300, 200), Vector2(20, 20))
	]:
		var polygon = rect3d._screen_rect_2d_to_topdown_polygon_2d(rect)
		selector._physics_candidates_enabled = false
		var expected = (
			selector
			. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(-1, polygon)
		)
		selector._physics_candidates_enabled = true
		var actual = (
			selector
			. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(-1, polygon)
		)
		_check(
			actual.iterate() == expected.iterate(),
			label + ": physics broadphase changed exact screen selection"
		)
	selector._physics_candidates_enabled = enabled
	for unit in [worker, aircraft]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _selection_checks(camera, worker, aircraft, label):
	var rect3d = game.get_node("RectangularSelection3D")
	var selector = game.get_node("Handlers/ArealUnitSelectionHandler")
	var viewport_size = root.get_visible_rect().size
	var center = viewport_size / 2.0
	var rect = Rect2(Vector2(20, 20), viewport_size - Vector2(40, 40))
	# A visible aircraft can sit above the lower corners' ray origins. Those
	# forward rays cannot intersect its altitude, even though it is inside the box.
	aircraft.global_position = camera.project_position(center, 0.2)
	aircraft.show()
	var plane = Plane(Vector3.UP, aircraft.global_position.y)
	_check(
		camera.get_ray_intersection_with_plane(rect.end, plane) == null,
		label + ": fixture must reproduce a missing altitude-plane intersection"
	)
	worker.global_position = camera.get_ray_intersection_with_plane(center, Plane(Vector3.UP, 0))
	worker.show()
	_drag(rect3d, rect.position, rect.end, aircraft, label)
	_check(worker.is_in_group("selected_units"), label + ": ground unit missed")
	_check(aircraft.is_in_group("selected_units"), label + ": high aircraft missed")
	_check(not aircraft.get_node("Highlight")._forced, label + ": release left highlight forced")
	# Reverse drags and live highlight must use the same rectangle.
	_drag(rect3d, rect.end, rect.position, aircraft, label)
	_check(aircraft.is_in_group("selected_units"), label + ": reverse drag missed aircraft")
	# Check actual displayed positions on both flat and elevated ground.
	for height in [0.0, 3.0, 8.0]:
		worker.global_position = camera.project_position(center, 10.0)
		worker.global_position += (
			camera.project_ray_normal(center)
			* ((height - worker.global_position.y) / camera.project_ray_normal(center).y)
		)
		var screen = camera.unproject_position(worker.global_position)
		var polygon = rect3d._screen_rect_2d_to_topdown_polygon_2d(
			Rect2(screen - Vector2(8, 8), Vector2(16, 16))
		)
		var result = (
			selector
			. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
				worker.movement_domain, polygon
			)
		)
		_check(result.has(worker), label + ": unit missed at height " + str(height))
	var polygon = rect3d._screen_rect_2d_to_topdown_polygon_2d(rect)
	_check(
		not _air_units(selector, polygon).has(worker), label + ": wrong movement domain included"
	)
	rect3d._start(center)
	rect3d._mouse_position = Vector2.ZERO
	rect3d._physics_process(0.1)
	_check(rect3d._selecting(), label + ": hitting screen edge interrupted marquee selection")
	rect3d._finish(Vector2.ZERO)
	aircraft.global_position = camera.project_position(center, 5.0)
	rect3d._start(rect.position)
	rect3d._mouse_position = rect.end
	rect3d._update()
	_check(aircraft.get_node("Highlight")._forced, label + ": drag failed to force highlight")
	rect3d._mouse_position = rect.position + Vector2(10, 10)
	rect3d._update()
	_check(not aircraft.get_node("Highlight")._forced, label + ": shrinking drag kept highlight")
	rect3d._mouse_position = rect.end
	rect3d._update()
	rect3d._interrupt()
	_check(not aircraft.get_node("Highlight")._forced, label + ": interruption kept highlight")
	_check(selector._highlighted_units.empty(), label + ": interruption kept highlighted set")
	aircraft.hide()
	_check(not _air_units(selector, polygon).has(aircraft), label + ": hidden aircraft included")
	aircraft.show()
	aircraft.global_position = camera.project_position(Vector2(-30, center.y), 5.0)
	_check(not _air_units(selector, polygon).has(aircraft), label + ": outside aircraft included")
	aircraft.global_position = camera.project_position(center, -5.0)
	_check(
		not _air_units(selector, polygon).has(aircraft), label + ": behind-camera aircraft included"
	)
	_check(_air_units(selector, null).empty(), label + ": null polygon selected units")
	_check(_air_units(selector, []).empty(), label + ": empty polygon selected units")
	_check(rect3d._screen_rect_2d_to_topdown_polygon_2d(null) == null, label + ": null rectangle")
	# An unavailable camera or parallel selection plane must fail without errors.
	camera.clear_current()
	_check(_air_units(selector, polygon).empty(), label + ": missing camera selected units")
	_check(
		rect3d._screen_rect_2d_to_topdown_polygon_2d(rect) == null,
		label + ": missing camera produced a polygon"
	)
	camera.make_current()
	var original_plane = rect3d.polygon_plane
	var direction = camera.project_ray_normal(center)
	rect3d.polygon_plane = Plane(direction.cross(Vector3.UP).normalized(), 1000)
	_check(
		rect3d._screen_rect_2d_to_topdown_polygon_2d(rect) == null,
		label + ": parallel rays produced a polygon"
	)
	rect3d.polygon_plane = original_plane


func _air_units(selector, polygon):
	return selector._get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
		root.get_node("Constants").Match.Navigation.Domain.AIR, polygon
	)


func _drag(rect3d, start, end, aircraft, label):
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	rect3d._unhandled_input(press)
	var motion = InputEventMouseMotion.new()
	motion.position = end
	rect3d._input(motion)
	rect3d._throttle_update(rect3d.changed_signal_interval_lower_bound)
	_check(aircraft.get_node("Highlight")._forced, label + ": live drag missed high aircraft")
	var release = press.duplicate()
	release.pressed = false
	release.position = end
	rect3d._unhandled_input(release)
