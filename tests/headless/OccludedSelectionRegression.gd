extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/battlefields/AlpineRelayMap.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	_check(camera != null, "Missing IsometricCamera3D")

	# 1. Place a building and a unit behind it (further along camera view vector).
	var barracks = _units(human, "Barracks")[0]
	var worker = _units(human, "Worker")[0]
	var view_dir = -camera.global_transform.basis.z.normalized()
	# Position worker behind the barracks along the camera sight line
	worker.global_position = barracks.global_position + view_dir * 2.5
	worker.global_position.y = barracks.global_position.y
	await _frames(3)

	# Verify screen point for worker is within find_unit_at_screen_point
	var worker_screen = camera.unproject_position(worker.global_position + Vector3(0, 0.5, 0))
	var match_utils = load("res://source/match/MatchUtils.gd")
	var detected_behind_bldg = match_utils.find_unit_at_screen_point(
		root.get_tree(), camera, worker_screen, true
	)
	_check(
		detected_behind_bldg == worker,
		"find_unit_at_screen_point did not find worker behind barracks"
	)

	# Simulate click hitting barracks Area3D when worker is behind it
	root.get_node("MatchSignals").deselect_all_units.emit()
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = worker_screen

	barracks.get_node("Selection")._on_input_event(
		camera, click_event, worker.global_position, Vector3.UP, 0
	)
	_check(
		worker.is_in_group("selected_units"),
		"Clicking on worker behind barracks failed to select worker"
	)
	_check(
		not barracks.is_in_group("selected_units"),
		"Clicking on worker behind barracks mistakenly selected barracks"
	)

	# 2. Test clicking barracks directly when NO unit is behind it
	root.get_node("MatchSignals").deselect_all_units.emit()
	var barracks_screen = camera.unproject_position(barracks.global_position + Vector3(0, 0.5, 0))
	# Move worker far away
	worker.global_position = barracks.global_position + Vector3(20, 0, 20)
	await _frames(3)
	click_event.position = barracks_screen
	barracks.get_node("Selection")._on_input_event(
		camera, click_event, barracks.global_position, Vector3.UP, 0
	)
	_check(
		barracks.is_in_group("selected_units"), "Direct click on barracks failed to select barracks"
	)

	# 3. Test unit behind trees / on terrain
	root.get_node("MatchSignals").deselect_all_units.emit()
	var soldiers = _units(human, "Infantry")
	var soldier = soldiers[0] if not soldiers.is_empty() else worker
	soldier.global_position = game.map.ground_point(Vector2(40, 40))
	await _frames(3)
	var soldier_screen = camera.unproject_position(soldier.global_position + Vector3(0, 0.5, 0))

	# Simulate click hitting terrain where soldier is located
	var terrain = game.find_child("Terrain", true, false)
	_check(terrain != null, "Missing Terrain node")
	click_event.position = soldier_screen
	terrain._on_input_event(camera, click_event, soldier.global_position, Vector3.UP, 0)
	_check(
		soldier.is_in_group("selected_units"),
		"Clicking on terrain over unit behind trees/foliage failed to select unit"
	)

	# 4. Test clicking empty terrain deselects
	var empty_ground_screen = camera.unproject_position(
		soldier.global_position + Vector3(15, 0, 15)
	)
	click_event.position = empty_ground_screen
	var detected_empty = match_utils.find_unit_at_screen_point(
		root.get_tree(), camera, empty_ground_screen
	)
	_check(detected_empty == null, "Empty ground detected a false positive unit")
	terrain._on_input_event(
		camera, click_event, soldier.global_position + Vector3(15, 0, 15), Vector3.UP, 0
	)
	# Unhandled input emits deselect on empty ground click
	game._unhandled_input(click_event)
	_check(
		not soldier.is_in_group("selected_units"), "Clicking empty ground failed to deselect units"
	)

	# 5. Box selection covering unit upper half behind an obstacle
	var rect_handler = game.find_child("ArealUnitSelectionHandler", true, false)
	_check(rect_handler != null, "Missing ArealUnitSelectionHandler")
	var rect3d = game.find_child("RectangularSelection3D", true, false)
	_check(rect3d != null, "Missing RectangularSelection3D")
	var screen_rect = Rect2(soldier_screen - Vector2(25, 25), Vector2(50, 50))
	var topdown_poly = rect3d._screen_rect_2d_to_topdown_polygon_2d(screen_rect)
	var units_in_box = (
		rect_handler
		. _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
			soldier.movement_domain, topdown_poly
		)
	)
	_check(units_in_box.has(soldier), "Box selection missed unit behind obstacle")

	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Occluded selection: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
