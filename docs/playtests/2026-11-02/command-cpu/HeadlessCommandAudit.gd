extends "res://tests/headless/TacticalFormationsRegression.gd"


func _benchmark():
	await super._benchmark()
	if not _errors.is_empty():
		return
	var members = get_nodes_in_group("selected_units")
	var signatures = []
	var times = []
	var cpu_times = []
	var first = _intent_signature(members)
	for iteration in 11:
		for member in members:
			member.manual_orders.cancel()
		var cpu_before = _profile_snapshot().cpu
		var started = Time.get_ticks_usec()
		root.get_node("MatchSignals").terrain_targeted.emit(Vector3(50, 0, 60))
		times.append(Time.get_ticks_usec() - started)
		var cpu_after = _profile_snapshot().cpu
		if cpu_before.size() == 4 and cpu_after.size() == 4:
			cpu_times.append(cpu_after[2] - cpu_before[2])
		var signature = _intent_signature(members)
		_check(signature == first, "Repeated200 command changed endpoint/order output")
		signatures.append(signature)
	var record = {
		"headless": DisplayServer.get_name() == "headless",
		"native_crowd": _game.crowd_runtime != null,
		"first_signature": first,
		"first_signature_bytes": var_to_bytes(first).hex_encode(),
		"repeat_wall_us": times,
		"repeat_main_cpu_us": cpu_times,
		"all_signatures_equal": signatures.all(func(value): return value == first)
	}
	# Compare actual Vector3 values with the retained pre-change implementation,
	# rather than relying on JSON's formatted Vector3 strings for exact parity.
	var original = load("res://docs/playtests/2026-11-02/command-cpu/OriginalUnitMovementUtils.gd")
	var expected = original.crowd_moved_to_new_pivot(members, Vector3(50, 0, 60), null, "staggered")
	var exact_geometry = true
	for index in members.size():
		exact_geometry = exact_geometry and members[index] == expected[index][0]
		exact_geometry = (
			exact_geometry and members[index].manual_orders.pending[0].point == expected[index][1]
		)
	_check(exact_geometry, "Actual200 command differs from the retained original endpoint vectors")
	record.exact_original_geometry = exact_geometry
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--command-audit-output="):
			var output = FileAccess.open(
				argument.trim_prefix("--command-audit-output="), FileAccess.WRITE
			)
			output.store_string(JSON.stringify(record, "\t"))
			output.close()
	print("HEADLESS COMMAND AUDIT ", JSON.stringify({"wall_us": times, "cpu_us": cpu_times}))


func _intent_signature(members: Array) -> Array:
	_check(members.size() == 200, "Audit lost the real200 selected cohort")
	var result = []
	var tokens = {}
	for index in members.size():
		var unit = members[index]
		var orders = unit.manual_orders
		_check(orders.pending.size() == 1, "Audit lost an admitted order")
		if orders.pending.is_empty():
			continue
		var order = orders.pending[0]
		_check(order.kind == "move", "Audit changed the admitted order kind")
		_check(order.cohort.members.size() == 200, "Audit changed cohort membership")
		_check(orders._activation_queued, "Audit started an order before activation")
		_check(not tokens.has(order.token), "Audit duplicated an authoritative token")
		tokens[order.token] = true
		result.append([index, order.kind, order.point, order.waypoints])
	return result
