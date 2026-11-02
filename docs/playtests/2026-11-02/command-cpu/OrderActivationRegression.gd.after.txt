extends "res://tests/headless/MechanicsRegression.gd"

var _members := []
var _manual
var _cohort_script


class ReplicaSession:
	extends RefCounted
	var authority = false


class CancellationProbe:
	extends Node
	var calls = []

	func _exit_tree():
		calls.append(true)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_manual = load("res://source/match/orders/ManualOrders.gd")
	_cohort_script = load("res://source/match/orders/CohesionGroup.gd")
	await _open("bastion")
	for unit in get_nodes_in_group("units"):
		if unit.get_node_or_null("Movement") != null:
			unit.queue_free()
	await _frames(3)
	for index in 200:
		var unit = _spawn("Tank", _human, Vector3(15 + (index % 20) * 4, 0, 35 + (index / 20) * 4))
		_members.append(unit)
	await _frames(40)
	for unit in _members:
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	paused = true
	var feedback = [0]
	root.get_node("MatchSignals").order_feedback.connect(
		func(_unit, _kind, _point, accepted, _queued, _reason):
			if accepted:
				feedback[0] += 1
	)
	var cohort = _cohort_script.new(_members)
	for index in _members.size():
		var unit = _members[index]
		var order = _manual.point_order("move", unit.global_position + Vector3(0, 0, 6))
		order.cohort = cohort
		order.token = index + 1
		_check(unit.manual_orders.submit(order), "Bulk order admission failed")
		_check(unit.manual_orders.pending.size() == 1, "Admission did not retain its intent")
		_check(unit.manual_orders.current.is_empty(), "Admission bypassed the activation boundary")
		_check(
			not unit.get_node("Movement")._has_destination, "Admission retained the previous path"
		)
		_check(
			unit.action.process_mode == Node.PROCESS_MODE_DISABLED, "Waiting action remained active"
		)
	await _frames(8)
	_check(feedback[0] == 200, "Bulk admission did not show immediate feedback for every unit")
	var queue = _game.get_node("OrderActivationQueue")
	_check(queue.statistics().queued == 200, "Paused queue lost admitted orders")
	_check(queue.statistics().activated_total == 0, "Tactical pause activated an order")
	await _cancellation_and_activation()
	# Real saves retain the normal100-mobile population limit. The200-body
	# stress above remains separate from the full-capacity disk/restore case.
	paused = true
	for unit in _members.slice(0, 100):
		if is_instance_valid(unit):
			unit.queue_free()
	_members = _members.slice(100)
	await _frames(3)
	cohort = _cohort_script.new(_members)
	for index in _members.size():
		var order = _manual.point_order("move", _members[index].global_position + Vector3(0, 0, 6))
		order.cohort = cohort
		order.token = index + 1
		_members[index].manual_orders.submit(order, false, false)
	await _disk_round_trip()
	if not _members.is_empty():
		paused = false
		var until = Engine.get_physics_frames() + 2
		while Engine.get_physics_frames() < until:
			await process_frame
		await process_frame
		var stats = _game.get_node("OrderActivationQueue").statistics()
		_check(
			stats.queued == 0 and stats.activated_total == 100, "Disk restore lost waiting starts"
		)
		_check(
			_members.all(func(unit): return unit.manual_orders.current.get("kind") == "move"),
			"Disk restore did not activate its saved intents"
		)
		await _partially_started_disk()
		_replica_guard()
		_operational_cleanup()
		_reentrant_eligibility()
	paused = false
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Order activation: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _disk_round_trip():
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = builder.capture(_game)
	_check(snapshot != null, "Waiting formation capture failed: " + builder.error)
	if snapshot == null:
		return
	var ids = _members.map(func(unit): return builder._reference(unit))
	var values = load("res://source/match/saves/SaveValue.gd").new()
	var encoded = values.encode(snapshot)
	DirAccess.make_dir_recursive_absolute("user://test-artifacts")
	var path = "user://test-artifacts/waiting-formation.json"
	var output = FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(encoded))
	output.close()
	var decoded = values.decode(JSON.parse_string(FileAccess.get_file_as_string(path)))
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await loader.restore(self, decoded)
	_check(result.ok, "Waiting formation disk restore failed: " + result.get("error", ""))
	if not result.ok:
		_members.clear()
		return
	_game = result.game
	_members = ids.map(func(id): return loader.entities[id])
	_fixtures.clear()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	_check(paused, "Disk restore resumed a paused formation")
	for index in _members.size():
		var orders = _members[index].manual_orders
		var saved = snapshot.units.filter(func(unit): return unit.id == ids[index])[0].orders
		_check(
			(
				orders.current.get("kind", "") == saved.current.get("kind", "")
				and orders.pending.size() == saved.pending.size()
			),
			"Restore changed pending/current work"
		)
		if not saved.pending.is_empty():
			_check(
				orders.pending[0].point == saved.pending[0].point,
				"Restore changed an admitted destination"
			)
			_check(
				orders.pending[0].cohort.members.size() == 100,
				"Restore changed the admitted cohort"
			)
			_check(
				_members[index].action.process_mode == Node.PROCESS_MODE_DISABLED,
				"Restore resumed an obsolete action"
			)

	await _frames(8)
	_check(
		_game.get_node("OrderActivationQueue").statistics().activated_total == 0,
		"Restored queue advanced while paused"
	)


func _partially_started_disk():
	paused = true
	var cohort = _cohort_script.new(_members)
	# Reverse submission proves roster ordering survives a partial save.
	for index in range(_members.size() - 1, -1, -1):
		var order = _manual.point_order("move", _members[index].global_position + Vector3(0, 0, 8))
		order.cohort = cohort
		_members[index].manual_orders.submit(order, false, false)
	paused = false
	var until = Engine.get_physics_frames() + 1
	while Engine.get_physics_frames() < until:
		await process_frame
	paused = true
	_check(
		_game.get_node("OrderActivationQueue").statistics().queued == 4,
		"First tick did not start96 heads"
	)
	_check(
		_members[0].manual_orders.current.get("kind") == "move",
		"Queue did not use saved roster order"
	)
	_check(_members[-1].manual_orders.current.is_empty(), "Queue used unsaved insertion order")
	await _disk_round_trip()
	paused = false
	until = Engine.get_physics_frames() + 1
	while Engine.get_physics_frames() < until:
		await process_frame
	_check(
		_game.get_node("OrderActivationQueue").statistics().queued == 0,
		"Partial restore lost remaining heads"
	)


func _replica_guard():
	var unit = _members[0]
	var orders = unit.manual_orders
	orders.cancel()
	var order = _manual.point_order("move", unit.global_position + Vector3(3, 0, 0))
	order.cohort = _cohort_script.new(_members)
	orders.pending = [order]
	orders.current = {}
	orders._engaged = true
	var replica = ReplicaSession.new()
	unit.set_meta("network_session", replica)
	orders.resume_waiting_activation()
	_check(not orders._activation_queued, "Replica scheduled local action activation")
	_check(not orders.is_physics_processing(), "Replica retained local queue processing")
	unit.remove_meta("network_session")
	orders.cancel()


func _operational_cleanup():
	var unit = _members[0]
	var probe = CancellationProbe.new()
	var calls = []
	probe.calls = calls
	unit.action = probe
	var order = _manual.point_order("move", unit.global_position + Vector3(3, 0, 0))
	order.cohort = _cohort_script.new(_members)
	unit.manual_orders.submit(order, false, false)
	_check(calls.size() == 1, "Operational teardown was deferred")
	_check(
		not unit.manual_orders._activation_queued, "Operational action entered the delayed queue"
	)


func _reentrant_eligibility():
	var was_paused = paused
	paused = true
	var unit = _members[0]
	var orders = unit.manual_orders
	var movement = unit.get_node("Movement")
	var signals = root.get_node("MatchSignals")
	var order = _manual.point_order("move", unit.global_position + Vector3(3, 0, 0))
	order.cohort = _cohort_script.new(_members)
	orders.cancel()
	unit.action = null
	var changed_domain = func(source, _kind, _point, accepted, _queued, _reason):
		if source == unit and accepted:
			movement.domain = 0
	signals.order_feedback.connect(changed_domain)
	orders.submit(order)
	signals.order_feedback.disconnect(changed_domain)
	_check(not orders._activation_queued, "Feedback domain change used stale eligibility")
	movement.domain = 1
	orders.cancel()
	unit.action = null
	var calls = []
	var changed_action = func(source, _kind, _point, accepted, _queued, _reason):
		if source == unit and accepted:
			var probe = CancellationProbe.new()
			probe.calls = calls
			unit.action = probe
	signals.order_feedback.connect(changed_action)
	orders.submit(order)
	signals.order_feedback.disconnect(changed_action)
	_check(not orders._activation_queued, "Feedback action change used stale eligibility")
	# Paused operational replacement must remain available for the usual retry.
	_check(calls.is_empty(), "Paused operational action was torn down before resume")
	orders.cancel()
	unit.action = null
	paused = was_paused


func _cancellation_and_activation():
	var stopped = _members[0]
	stopped.issue_manual_order(null)
	var replacement = _members[1]
	var replacement_point = replacement.global_position + Vector3(4, 0, 0)
	replacement.manual_orders.submit(_manual.point_order("move", replacement_point), false, false)
	_members[2].queue_free()
	var shifted = _members[3]
	var next_point = shifted.global_position + Vector3(0, 0, 10)
	shifted.manual_orders.submit(_manual.point_order("move", next_point), true, false)
	var dragged = _members[4]
	var drag_point = dragged.global_position + Vector3(5, 0, 5)
	_check(dragged.manual_orders.revise(5, drag_point), "Drag did not revise the admitted token")
	await _frames(2)
	var queue = _game.get_node("OrderActivationQueue")
	_check(queue.statistics().queued == 197, "Cancellation/deletion retained stale work")
	paused = false
	var until = Engine.get_physics_frames() + 3
	while Engine.get_physics_frames() < until:
		await process_frame
	await process_frame
	var stats = queue.statistics()
	_check(
		stats.queued == 0 and stats.activated_total == 197, "Three ticks did not start every intent"
	)
	_check(stats.maximum_batch <= 96, "Activation exceeded its fixed tick batch")
	_check(stats.maximum_wait_ms <= 100.001, "Activation exceeded100ms at30Hz")
	_check(stopped.manual_orders.pending.is_empty(), "Stop was overwritten by delayed work")
	_check(not stopped.get_node("Movement")._has_destination, "Stop resumed an obsolete path")
	_check(
		replacement.manual_orders.current.get("point") == replacement_point,
		"Delayed work replaced a newer immediate order"
	)
	_check(shifted.manual_orders.pending.size() == 1, "Activation lost a Shift follow-up")
	_check(shifted.manual_orders.pending[0].point == next_point, "Activation changed Shift order")
	_check(
		dragged.manual_orders.current.get("point") == drag_point, "Activation ignored drag revision"
	)
	var active = 0
	var moving = 0
	var arrived = 0
	for index in range(3, _members.size()):
		var unit = _members[index]
		active += int(unit.manual_orders.current.get("kind") == "move")
		moving += int(unit.get_node("Movement").velocity.length_squared() > .01)
		if unit.manual_orders.current.is_empty():
			var movement = unit.get_node("Movement")
			arrived += int(unit.global_position.distance_to(movement.get_final_position()) < .7)
	_check(active + arrived == 197, "Activated count did not match actual current/arrived orders")
	_check(moving >= 190, "Started orders did not produce actual movement")
	print(
		"ORDER ACTIVATION COVERAGE ",
		JSON.stringify({"queue": stats, "current": active, "moving": moving, "arrived": arrived})
	)
