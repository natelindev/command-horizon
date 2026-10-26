extends "res://tests/headless/Skirmish.gd"

var harvest
var orders
var game
var human
var workers = []


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	for faction in ["bastion", "helix", "frontier"]:
		game = await _start(_settings(faction, "helix", false))
		human = game._get_human_player()
		get_nodes_in_group("players")[1].set_process(false)
		for deposit in get_nodes_in_group("resource_units"):
			deposit.queue_free()
		workers = get_nodes_in_group("units").filter(
			func(unit): return unit.player == human and unit.type == "Worker"
		)
		while workers.size() < 3:
			var worker = load(Catalog.scene_path("Worker")).instantiate()
			game._setup_and_spawn_unit(
				worker, Transform3D(Basis(), Vector3(25, 0, 20)), human, false
			)
			workers.append(worker)
		await _frames(4)
		await _slots_and_type()
		await _depletion_and_archive()
		await _hq_and_queue()
		game.queue_free()
		await _frames(4)
		print("Resource field scenarios complete: " + faction)
	for error in _errors:
		push_error(error)
	print("Resource fields: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _deposit(kind, point, amount = 100):
	var deposit = load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
	deposit.set("resource_a" if kind == "A" else "resource_b", amount)
	game.map.add_child(deposit)
	deposit.global_position = point
	return deposit


func _reset_worker(worker, point):
	worker.issue_manual_order(null)
	worker.resource_a = 0
	worker.resource_b = 0
	var movement = worker.get_node("Movement")
	movement.stop()
	worker.global_position = point


func _clear():
	for worker in workers:
		_reset_worker(worker, Vector3(20 + workers.find(worker) * 2, 0, 20))
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(4)


func _slots_and_type():
	var origin = Vector3(30, 0, 25)
	var deposit = _deposit("B", origin)
	var wrong = _deposit("A", origin + Vector3(0, 0, 3))
	for index in range(3):
		_reset_worker(
			workers[index],
			origin + Vector3(1.2 if index == 0 else (-1.2 if index == 1 else 5.0), 0, 0)
		)
		workers[index].issue_manual_order(harvest.new(deposit))
	_check(
		workers[2].action._waiting_reason == harvest.Wait.SLOT, "Third worker overbooked deposit"
	)
	await _frames(130)
	_check(
		workers[0].resource_b > 0 and workers[1].resource_b > 0, "Reserved workers did not gather"
	)
	_check(
		workers[2].resource_b == 0 and wrong.resource_a == 100,
		"Waiting worker gathered or switched type"
	)
	paused = true
	var retry = workers[2].action._retry_left
	var quantity = deposit.resource_b
	await _frames(45)
	_check(
		workers[2].action._retry_left == retry and deposit.resource_b == quantity,
		"Pause advanced field work"
	)
	paused = false
	workers[0].issue_manual_order(null)
	await _frames(40)
	_check(
		workers[2].action.holds_harvest_slot(deposit), "Cancelled order did not release its slot"
	)
	# Capture two reservations and a waiter, then reconstruct from their saved actions.
	workers[0].resource_b = 0
	workers[0].issue_manual_order(harvest.new(deposit))
	await _roundtrip()
	var holding = (
		workers.filter(func(w): return w.action != null and not w.action.is_waiting()).size()
	)
	_check(holding == 2 and workers[0].action.is_waiting(), "Archive lost slot ownership or waiter")
	workers[1].queue_free()
	workers.remove_at(1)
	await _frames(40)
	_check(not workers[0].action.is_waiting(), "Dead worker retained a work slot")
	var replacement = load(Catalog.scene_path("Worker")).instantiate()
	game._setup_and_spawn_unit(replacement, Transform3D(Basis(), origin), human, false)
	workers.append(replacement)
	await _clear()
	# A field is anchored to the original order, never to the last deposit or HQ.
	deposit = _deposit("B", origin)
	var local = _deposit("B", origin + Vector3(8, 0, 0))
	var remote = _deposit("B", origin + Vector3(16, 0, 0))
	wrong = _deposit("A", origin + Vector3(2, 0, 0))
	_reset_worker(workers[0], origin)
	workers[0].issue_manual_order(harvest.new(deposit))
	deposit.queue_free()
	await _frames(4)
	_check(
		workers[0].action.get_resource_unit() == local, "Local same-type replacement not selected"
	)
	local.queue_free()
	await _frames(5)
	_check(
		workers[0].action._waiting_reason == harvest.Wait.DEPLETED,
		"Harvester chained into a distant field"
	)
	_check(
		remote.resource_b == 100 and wrong.resource_a == 100, "Unassigned resources were gathered"
	)
	await _clear()


func _depletion_and_archive():
	var hq = _unit(human, "CommandCenter")
	var point = hq.global_position + Vector3(6, 0, 0)
	var deposit = _deposit("A", point, 1)
	var before = human.resource_a
	for index in range(2):
		_reset_worker(workers[index], point + Vector3(0, 0, 1.2 if index == 0 else -1.2))
		workers[index].issue_manual_order(harvest.new(deposit))
	await _until(
		func(): return workers.slice(0, 2).all(func(w): return w.action.needs_assignment())
	)
	_check(
		human.resource_a == before + 1,
		"Final deposit unit duplicated or partial cargo not delivered"
	)
	for worker in workers.slice(0, 2):
		_check(
			worker.resource_a == 0 and worker.action._waiting_reason == harvest.Wait.DEPLETED,
			"Depleted worker did not wait after delivery"
		)
	await _roundtrip()
	_check(workers[0].action.needs_assignment(), "Targetless depleted state lost on restore")
	# Shift queued after depletion must start, even though no child action remains.
	workers[0].manual_orders.submit(orders.point_order("move", point + Vector3(2, 0, 4)), true)
	await _frames(5)
	_check(
		workers[0].manual_orders.current.get("kind") == "move",
		"Shift queue stalled behind a depleted assignment"
	)
	await _clear()


func _hq_and_queue():
	var hq = _unit(human, "CommandCenter")
	var deposit = _deposit("B", hq.global_position + Vector3(7, 0, 0))
	var worker = workers[0]
	_reset_worker(worker, hq.global_position + Vector3(4, 0, 0))
	worker.resource_a = 2
	var before = human.resource_a
	worker.issue_manual_order(harvest.new(deposit))
	_check(
		worker.action._state == harvest.State.MOVING_TO_CC,
		"New field order discarded carried cargo"
	)
	await _roundtrip()
	worker = workers[0]
	hq = _unit(human, "CommandCenter")
	_check(worker.action._kind == 2, "Archive lost the new field type of returning cargo")
	await _until(func(): return human.resource_a == before + 2)
	_check(worker.action._kind == 2, "Returning old cargo lost new electronics assignment")
	worker.issue_manual_order(null)
	worker.resource_a = 3
	worker.global_position = hq.global_position + Vector3(15, 0, 0)
	worker.issue_manual_order(harvest.new(hq))
	var alternative = load(Catalog.scene_path("CommandCenter")).instantiate()
	game._setup_and_spawn_unit(
		alternative, Transform3D(Basis(), hq.global_position + Vector3(0, 0, 12)), human, false
	)
	hq.queue_free()
	await _frames(8)
	_check(
		worker.action._waiting_reason == harvest.Wait.HQ and worker.resource_a == 3,
		"Lost HQ failed to preserve cargo or auto-selected another HQ"
	)
	await _roundtrip()
	worker = workers[0]
	alternative = _unit(human, "CommandCenter")
	_check(
		worker.resource_a == 3 and worker.action.needs_assignment(), "HQ wait cargo lost on restore"
	)
	before = human.resource_a
	worker.issue_manual_order(harvest.new(alternative))
	worker.manual_orders.submit(
		orders.point_order("move", alternative.global_position + Vector3(7, 0, 3)), true
	)
	await _until(func(): return human.resource_a == before + 3)
	await _frames(6)
	_check(
		worker.resource_a == 0 and worker.manual_orders.current.get("kind") == "move",
		"Explicit HQ recovery did not deliver and advance queue"
	)


func _roundtrip():
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Field snapshot failed: " + capture.error)
	if data == null:
		paused = false
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Field schema rejected live state: " + schema.error)
	var ids = workers.map(func(worker): return capture._reference(worker))
	var bad = data.duplicate(true)
	for unit in bad.units:
		if unit.action.get("kind") == "CollectingResourcesSequentially":
			unit.action.state._kind = 9
			break
	_check(not schema.validate(bad), "Invalid resource kind accepted")
	bad = data.duplicate(true)
	for unit in bad.units:
		if unit.action.get("kind") == "CollectingResourcesSequentially":
			unit.action.state._waiting_reason = 0 if unit.action.state._state == 4 else 2
			break
	_check(not schema.validate(bad), "Inconsistent harvest wait state accepted")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Field restore failed")
	if loaded.ok:
		game = loaded.game
		human = game._get_human_player()
		get_nodes_in_group("players")[1].set_process(false)
		workers = ids.map(func(id): return restore.entities[id])
	paused = false


func _until(predicate, limit = 1800):
	for index in range(limit):
		if predicate.call():
			return
		await physics_frame
	for worker in workers:
		print("TIMEOUT: ", worker.action, worker.position, worker.resource_a, worker.resource_b)
	_check(false, "Timed out waiting for field operation")
