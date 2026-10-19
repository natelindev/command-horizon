extends "res://tests/headless/SaveRestoreEdges.gd"

var checks = 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "interface_scale": 1.0})
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	for faction in ["bastion", "helix", "frontier"]:
		await _review(faction)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	_check(checks == 3, "Not all faction fixtures completed")
	print("Game polish: %d failures; %d factions" % [errors.size(), checks])
	quit(0 if errors.is_empty() else 1)


func _review(faction):
	await _skirmish(faction, "res://source/match/maps/BigArena.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	paused = true
	var human = game._get_human_player()
	var worker = _units(human, "Worker")[0]
	var tank = _units(human, "Tank")[0]
	var factory = _units(human, "VehicleFactory")[0]
	var feedback = game.hud.command_feedback
	var deck = game.find_child("UnitMenus")
	game.hud.select_units([tank])
	await _frames(6)
	var tank_height = deck.size.y
	game.hud.select_units([factory])
	await _frames(6)
	_check(deck.size.y < tank_height, faction + ": producer deck did not fit its smaller content")
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(6)
	_check(
		not deck.visible and not game.find_child("EmptyDeck", true, false).visible,
		faction + ": empty selection still covers the battlefield"
	)
	for unit in human.get_children():
		if unit.has_method("is_constructed"):
			var apron = unit.get_node_or_null("BaseApron")
			_check(
				apron is MeshInstance3D and apron.mesh.get_surface_count() == 1,
				faction + ": missing static foundation"
			)
			_check(
				apron.get_child_count() == 0 and not apron.is_processing(),
				faction + ": foundation has dynamic behavior"
			)
	game.hud.select_units([worker])
	await _frames(4)
	var deposit = get_nodes_in_group("resource_units")[0]
	_check(
		feedback.contextual_kind(deposit) == "gather",
		faction + ": gathering cursor differs from command"
	)
	var foundation = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(foundation, Transform3D(Basis(), Vector3(40, 0, 40)), human, true)
	await _frames(3)
	_check(feedback.contextual_kind(foundation) == "construct", faction + ": build cursor missing")
	var orders = load("res://source/match/orders/ManualOrders.gd")
	var goal = Vector3(46, 0, 44)
	feedback.markers.clear()
	game.hud.select_units(_units(human, "Worker"))
	await _frames(2)
	game.hud.direct_orders.arm("move")
	_check(game.hud.direct_orders.commit(goal, null, false), faction + ": move rejected")
	await _frames(2)
	_check(
		feedback.markers.size() == 1 and feedback.markers[0].accepted,
		faction + ": formation feedback was not grouped"
	)
	_check(worker.manual_orders.pending.size() == 1, "Paused feedback advanced the queue")
	worker.manual_orders.cancel()
	for index in orders.LIMIT:
		worker.manual_orders.submit(orders.point_order("move", goal), true, false)
	_check(
		not worker.manual_orders.submit(orders.point_order("move", goal), true),
		"Full queue accepted overflow"
	)
	await _frames(2)
	_check(
		not feedback.markers[-1].accepted and "Queue full" in feedback.markers[-1].text,
		"Rejected command lacks its reason"
	)
	_check(worker.manual_orders.pending.size() == orders.LIMIT, "Rejection changed existing orders")
	TranslationServer.set_locale("zh_CN")
	worker.manual_orders.submit(orders.point_order("move", goal), true)
	await _frames(2)
	_check("队列已满" in feedback.markers[-1].text, "Queue rejection is not translated")
	TranslationServer.set_locale("en")
	worker.manual_orders.cancel()
	_check(
		worker.manual_orders.submit(orders.point_order("move", goal), true), "Queued order rejected"
	)
	await _frames(2)
	_check(
		"Queued" in feedback.markers[-1].text,
		"Queue feedback is indistinguishable from replacement"
	)
	game.hud.select_units([tank])
	game.hud.direct_orders.arm("guard")
	_check(game.hud.direct_orders.commit(goal, null, false), "Guard order rejected")
	await _frames(2)
	_check(feedback.markers[-1].kind == "guard", "Guard feedback was mislabeled as Move")
	game.hud.select_units([factory])
	root.get_node("MatchSignals").terrain_targeted.emit(goal)
	await _frames(2)
	_check(feedback.markers[-1].kind == "rally", "Ground rally lacks accepted feedback")
	root.get_node("MatchSignals").unit_targeted.emit(deposit)
	await _frames(2)
	_check(
		(
			feedback.markers[-1].kind == "rally"
			and feedback.markers[-1].point.is_equal_approx(deposit.global_position)
		),
		"Target rally lacks feedback at its destination"
	)
	for index in 20:
		feedback._add_marker(goal, "move", "Move", true)
	_check(feedback.markers.size() == feedback.MAX_MARKERS, "Feedback history is unbounded")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(50, 0, 50))
	camera.set_size_safely(30)
	camera._request_zoom(-6)
	camera._zoom_anchor = root.get_visible_rect().size * Vector2(.62, .42)
	var anchor = camera.get_ray_intersection(camera._zoom_anchor)
	camera._advance_zoom(1.0 / 60)
	_check(camera.size > 24 and camera.size < 30, "Zoom snaps rather than easing")
	for frame in 40:
		camera._advance_zoom(1.0 / 60)
	_check(camera.size == 24, "Smooth zoom failed to settle")
	_check(
		camera.get_ray_intersection(camera._zoom_anchor).distance_to(anchor) < .01,
		"Zoom moved the point under the cursor"
	)
	camera._request_zoom(-1000)
	for frame in 60:
		camera._advance_zoom(1.0 / 60)
	_check(camera.size == camera.size_min, "Zoom escaped minimum bound")
	camera._request_zoom(6)
	camera.set_position_safely(Vector3(50, 0, 50))
	_check(is_nan(camera._zoom_target), "Camera jump retained a stale zoom anchor")
	checks += 1
	paused = false
	game.queue_free()
	await _frames(5)
