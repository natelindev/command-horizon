extends "res://tests/headless/ResourceFieldRegression.gd"


func _run():
	seed(12345)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		var settings = _settings(faction, "bastion", false)
		settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
		game = await _start(settings)
		human = game._get_human_player()
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		workers = get_nodes_in_group("units").filter(
			func(unit): return unit.player == human and unit.type == "Worker"
		)
		while workers.size() < 4:
			var worker = load(Catalog.scene_path("Worker")).instantiate()
			game._setup_and_spawn_unit(
				worker, Transform3D(Basis(), Vector3(8, 0, 12)), human, false
			)
			workers.append(worker)
		for unit in get_nodes_in_group("units"):
			if unit not in workers:
				unit.process_mode = Node.PROCESS_MODE_DISABLED
		for kind in ["A", "B"]:
			await _distribution(kind, faction)
		await _unreachable_deposit()
		game.queue_free()
		await _frames(5)
	for error in _errors:
		push_error(error)
	print("Worker distribution: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _distribution(kind, faction):
	await _clear()
	var origin := Vector3(10, 0, 16)
	var deposits = []
	for offset in [Vector3.ZERO, Vector3(4, 0, 0), Vector3(0, 0, 4), Vector3(4, 0, 4)]:
		deposits.append(_deposit(kind, origin + offset, 200))
	_deposit("B" if kind == "A" else "A", Vector3(6, 0, 16), 200)
	_deposit(kind, Vector3(27, 0, 16), 200)
	await _frames(90)
	for index in workers.size():
		_reset_worker(workers[index], Vector3(7 + index * 2, 0, 12))
		workers[index].manual_orders.submit(
			orders.target_order("gather", deposits[0]), false, false
		)
	await _frames(5)
	var assigned = {}
	for worker in workers:
		var target = worker.action.get_resource_unit()
		assigned[target] = assigned.get(target, 0) + 1
		_check(target in deposits, "Worker left the ordered resource type/field")
	_check(
		assigned.size() == 4, "%s %s: four workers did not spread over four piles" % [faction, kind]
	)
	var saved_positions = workers.map(func(worker): return worker.position)
	var saved_targets = workers.map(func(worker): return worker.action.get_resource_unit())
	paused = true
	await _frames(20)
	_check(
		workers.map(func(worker): return worker.position) == saved_positions, "Paused workers moved"
	)
	_check(
		workers.map(func(worker): return worker.action.get_resource_unit()) == saved_targets,
		"Paused distribution changed reservations"
	)
	paused = false
	await _roundtrip()
	assigned.clear()
	for worker in workers:
		var target = worker.action.get_resource_unit()
		assigned[target] = assigned.get(target, 0) + 1
	_check(assigned.size() == 4, "Restoring a field collapsed its distributed assignments")
	var property = "resource_a" if kind == "A" else "resource_b"
	var before: int = human.get(property)
	var collected = {}
	var delivered = {}
	var previous = {}
	var reviewed = false
	for worker in workers:
		previous[worker] = worker.get(property)
	for frame in 2400:
		await physics_frame
		for worker in workers:
			var cargo: int = worker.get(property)
			if cargo > 0:
				collected[worker] = true
			if previous[worker] > 0 and cargo == 0:
				delivered[worker] = true
			previous[worker] = cargo
		if collected.size() == 4 and not reviewed:
			reviewed = true
			await _review_distribution(faction, kind)
		if delivered.size() == workers.size():
			break
	_check(collected.size() == 4, "%s %s: a distributed worker never mined" % [faction, kind])
	_check(delivered.size() == 4, "%s %s: a distributed worker never delivered" % [faction, kind])
	_check(human.get(property) >= before + 4, "Distribution produced no real income")
	# Use restored resources: the original node references belonged to the old match.
	for deposit in get_nodes_in_group("resource_units"):
		if deposit.position.distance_to(Vector3(27, 0, 16)) < .1:
			_check(deposit.get(property) == 200, "Workers chained into a distant field")
		if deposit.position.distance_to(Vector3(6, 0, 16)) < .1:
			_check(
				deposit.get("resource_b" if kind == "A" else "resource_a") == 200,
				"Wrong resource mined"
			)
	print("DISTRIBUTION ", faction, " ", kind, " spread=4/4 delivered=", delivered.size(), "/4")


func _review_distribution(_faction, _kind):
	pass


func _unreachable_deposit():
	await _clear()
	# The first pile is beyond the terrain boundary but still in the same field.
	var unreachable = _deposit("A", Vector3(-5, 0, 16), 200)
	var reachable = _deposit("A", Vector3(3, 0, 16), 200)
	await _frames(90)
	var worker = workers[0]
	_reset_worker(worker, Vector3(0, 0, 16))
	var movement_utils = root.get_node("Utils").Match.Unit.Movement
	var contact = (
		worker.radius + unreachable.radius + movement_utils.adherence_margin(worker, unreachable)
	)
	_check(
		is_inf(movement_utils.path_distance_to(worker, unreachable.global_position_yless, contact)),
		"Unreachable-deposit fixture has a reachable path"
	)
	worker.manual_orders.submit(orders.target_order("gather", unreachable), false, false)
	await _frames(5)
	_check(worker.action.get_resource_unit() == reachable, "Worker reserved an unreachable pile")
	reachable.queue_free()
	await _frames(30)
	_check(worker.action.is_waiting(), "Worker chased an unreachable pile after depletion")
	reachable = _deposit("A", Vector3(3, 0, 16), 200)
	await _frames(90)
	_check(
		worker.action.get_resource_unit() == reachable, "Waiting worker missed a reachable new pile"
	)
