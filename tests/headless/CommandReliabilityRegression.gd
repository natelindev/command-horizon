extends "res://tests/headless/SaveRestoreEdges.gd"

var manual


func _run():
	manual = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.0, "edge_scrolling": false})
	await _frames(2)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	for faction in ["bastion", "helix", "frontier"]:
		await _commands(faction)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Command reliability: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _commands(faction):
	var previous_errors = errors.size()
	await _skirmish(faction, "res://source/match/maps/BigArena.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var human = game._get_human_player()
	var worker = _units(human, "Worker")[0]
	worker.issue_manual_order(null)
	worker.position = Vector3(36, 0, 40)
	var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
	deposit.position = Vector3(43, 0, 40)
	game.map.add_child(deposit)
	var foundation = load("res://source/match/units/Barracks.tscn").instantiate()
	game._setup_and_spawn_unit(foundation, Transform3D(Basis(), Vector3(40, 0, 47)), human, true)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(40, 0, 40))
	camera.size = 32
	await _frames(90)
	game.hud.select_units([worker])
	await _frames(5)
	var movement = worker.get_node("Movement")
	# A production sidestep is legitimate while idle, but must yield to a new
	# map command. Exercise actual mouse dispatch, not just queue insertion.
	movement.request_exit_clearance(worker.position - Vector3(8, 0, 0))
	_check(movement._exit_clearance_target.is_finite(), "Idle clearance fixture did not start")
	await _right_click(camera.unproject_position(deposit.global_position + Vector3.UP * .5))
	_check(
		worker.manual_orders.current.get("kind") == "gather", "Resource click lost mining command"
	)
	_check(not movement._exit_clearance_target.is_finite(), "Mining retained the old sidestep")
	var remaining = worker.position.distance_to(deposit.global_position)
	movement.request_exit_clearance(worker.position - Vector3(8, 0, 0))
	_check(not movement._exit_clearance_target.is_finite(), "Production overrode travelling miner")
	await _frames(240)
	_check(worker.resource_a > 0, "Accepted mining command did not collect resources")
	_camera_keys_preserve_order(worker)
	_check(
		worker.position.distance_to(deposit.global_position) < remaining,
		"Miner moved away from field"
	)
	# A collecting worker can yield; replacing Gather with Build cancels that
	# temporary motion and keeps its cargo.
	movement.request_exit_clearance(worker.position + Vector3(8, 0, 0))
	await _right_click(camera.unproject_position(foundation.global_position + Vector3.UP * .5))
	_check(worker.manual_orders.current.get("kind") == "construct", "Foundation click lost Build")
	_check(not movement._exit_clearance_target.is_finite(), "Build retained a mining sidestep")
	await _frames(360)
	_check(
		foundation.construction_progress() > 0, "Accepted Build command never started construction"
	)
	var built = foundation.construction_progress()
	_camera_keys_preserve_order(worker)
	var cargo = worker.resource_a
	# Paused replacement must take authority immediately. A queued waypoint
	# must survive and run after the first move completes.
	movement.request_exit_clearance(worker.position + Vector3(8, 0, 0))
	game.hud._toggle_pause()
	var start = worker.position
	var goal = Vector3(36, 0, 34)
	await _right_click(camera.unproject_position(goal))
	_check(worker.position == start, "Paused command advanced movement")
	_check(
		not movement._exit_clearance_target.is_finite(), "Paused Move retained production steering"
	)
	_check(worker.manual_orders.pending.size() == 1, "Paused Move was not accepted")
	worker.manual_orders.submit(manual.point_order("move", goal + Vector3(3, 0, 0)), true, false)
	game.hud._toggle_pause()
	await _frames(3)
	_camera_keys_preserve_order(worker)
	await _frames(480)
	_check(worker.position.distance_to(goal + Vector3(3, 0, 0)) < .6, "Queued Move did not arrive")
	_check(worker.resource_a == cargo, "Replacing Build discarded cargo")
	_check(foundation.construction_progress() == built, "Cancelled Build kept constructing")
	movement.request_exit_clearance(worker.position + Vector3(4, 0, 0))
	_check(movement._exit_clearance_target.is_finite(), "Settled worker no longer clears exits")
	worker.issue_manual_order(null)
	_check(not movement._exit_clearance_target.is_finite(), "Stop retained automatic movement")
	if faction == "bastion":
		await _shortcut_remapping(human)
	print("COMMANDS ", faction, ": ", errors.size() - previous_errors, " failures")
	game.queue_free()
	await _frames(5)


func _camera_keys_preserve_order(unit):
	var active = unit.action
	var order = unit.manual_orders.current.duplicate()
	var stance = unit.stance
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]:
		_key(code)
		_check(unit.action == active, "Camera key cancelled " + str(order.get("kind")))
		_check(unit.manual_orders.current == order, "Camera key replaced manual orders")
		_check(unit.stance == stance, "Camera rotation changed unit stance")
		_check(game.hud.direct_orders.kind.is_empty(), "Camera key armed a unit command")


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)


func _shortcut_remapping(human):
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	var keys = original.key_bindings.duplicate(true)
	keys.keys.move_order = KEY_G
	keys.keys.rotate_map_clockwise = KEY_M
	preferences.key_bindings = keys
	preferences.apply()
	var tank = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(tank, Transform3D(Basis(), Vector3(32, 0, 32)), human, false)
	game.hud.select_units([tank])
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	_check(menus._command_buttons.move.badge == "G", "Move badge ignored remapped binding")
	_key(KEY_M)
	_check(game.hud.direct_orders.kind.is_empty(), "Old Move binding stole remapped camera key")
	_key(KEY_G)
	_check(game.hud.direct_orders.kind == "move", "Remapped Move key did not arm command")
	game.hud.direct_orders.cancel()
	# Reverse must submit an order through ManualOrders, not assign a Dictionary
	# to Unit.action (which requires a Node).
	var reverse_goal = tank.position + tank.global_basis.z * Vector3(1, 0, 1) * 12.0
	menus._command_card._slots[1][3].pressed.emit()
	# An idle queue starts the order at once; otherwise it waits at the head.
	var reverse = (
		tank.manual_orders.current
		if tank.manual_orders.pending.is_empty()
		else tank.manual_orders.pending[0]
	)
	_check(
		(
			tank.manual_orders.pending.size() <= 1
			and reverse.get("point", Vector3.INF).is_equal_approx(reverse_goal)
		),
		"Reverse did not queue a backwards move"
	)
	await _frames(3)
	_check(tank.manual_orders.current.get("kind") == "move", "Reverse failed to start")
	menus._command_card._slots[0][1].pressed.emit()
	_check(not tank.manual_orders._engaged, "Stop button lost its action")
	preferences.restore(original)


func _right_click(point):
	# Camera coordinates are in the viewport; push_input(false) takes window
	# coordinates, which differ under desktop scaling and letterboxing.
	point = root.get_final_transform() * point
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await _frames(2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if down else 0
		event.pressed = down
		root.push_input(event, false)
		await _frames(3)
