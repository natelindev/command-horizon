extends "res://tests/headless/MechanicsRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _open("bastion")
	var orders_script = load("res://source/match/orders/ManualOrders.gd")
	for kind in ["move", "attack_move", "patrol"]:
		var unit = _spawn("Tank", _human, Vector3(45, 0, 45))
		var changes = []
		unit.action_changed.connect(func(action): changes.append(action))
		_check(
			unit.manual_orders.submit(orders_script.point_order(kind, Vector3(55, 0, 45))),
			"Immediate point order rejected"
		)
		_check(
			changes.size() == 1 and changes[0] == unit.action,
			"Point replacement created an intermediate idle action: " + kind
		)
		_check(
			unit.manual_orders.current.get("kind", "") == kind,
			"Point replacement lost its authoritative order"
		)
	await _clear()
	var queued = _spawn("Tank", _human, Vector3(45, 0, 45))
	queued.process_mode = Node.PROCESS_MODE_INHERIT
	paused = true
	queued.manual_orders.submit(orders_script.point_order("move", Vector3(55, 0, 45)))
	_check(
		queued.manual_orders.current.is_empty() and queued.manual_orders.pending.size() == 1,
		"Paused point order started before resume"
	)
	_check(not queued.get_node("Movement")._has_destination, "Paused replacement retained movement")
	paused = false
	await _frames(6)
	_check(
		queued.manual_orders.current.get("kind", "") == "move", "Paused point order did not resume"
	)
	queued._action_locked = true
	queued.manual_orders.submit(orders_script.point_order("move", Vector3(45, 0, 55)))
	_check(
		queued.manual_orders.pending.size() == 1, "Locked point replacement lost its queued order"
	)
	queued._action_locked = false
	await _frames(6)
	_check(
		queued.manual_orders.current.point.is_equal_approx(Vector3(45, 0, 55)),
		"Locked point replacement did not retry"
	)
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Immediate point orders: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
