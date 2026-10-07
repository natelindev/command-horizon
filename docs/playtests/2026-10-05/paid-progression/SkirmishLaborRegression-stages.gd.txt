extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var catalog
var harvest
var labor
var moving
var orders


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _income(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish labor: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _income(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/DesertFrontier.tscn",
		true
	)
	var player = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	_freeze(player)
	while _units(player, "Worker").size() < 6:
		var index = _units(player, "Worker").size()
		_spawn("Worker", player, Vector3(104 + index, 0, 77))
	while _units(player, "Infantry").size() < 6:
		_spawn("Infantry", player, Vector3(98, 0, 72 + _units(player, "Infantry").size()))
	_spawn("Drone", player, Vector3(98, 2, 82))
	var air = _spawn("AircraftFactory", player, Vector3(94, 0, 80))
	var factory = _units(player, "VehicleFactory")[0]
	var hq = _units(player, "CommandCenter")[0]
	var parked = 0
	for unit in player._units():
		if unit.movement_speed > 0 and unit.attack_range != null:
			unit.position = Vector3(86 + parked * 2, 0, 88)
			parked += 1
	var workers = _units(player, "Worker")
	var material = _deposit(hq, "resource_a")
	player.resource_a = 200
	player.resource_b = 0
	for worker in workers:
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		worker.issue_manual_order(harvest.new(material))
	var assignments = labor.plan(game, player, player._units())
	_check(
		assignments.values().count(2) > 2 and assignments.values().count(1) >= 1,
		"Electronics deficit did not change the worker split"
	)
	var start = game.simulation_time
	var switched = null
	for frame in 3600:
		if frame % 90 == 0:
			player._harvest(player._units())
		for worker in workers:
			if labor.queued_target(worker) != null:
				switched = worker
				break
		if switched != null:
			break
		await physics_frame
	_check(switched != null, faction + ": active gatherers never scheduled an electronics handoff")
	if switched == null:
		paused = false
		game.queue_free()
		await _frames(5)
		return
	game.hud._toggle_pause()
	_check(
		(
			switched.action is Object
			and is_instance_of(switched.action, harvest)
			and switched.action._kind == 1
		),
		"Handoff interrupted materials collection before delivery"
	)
	_check(switched.resource_a == 4, "Handoff lost a full materials load")
	_check("resource_b" in labor.queued_target(switched), "Handoff chose the wrong resource")
	switched = await _restore_handoff(switched)
	if switched == null:
		return
	player = switched.player
	workers = _units(player, "Worker")
	hq = _units(player, "CommandCenter")[0]
	air = _units(player, "AircraftFactory")[0]
	factory = _units(player, "VehicleFactory")[0]
	var paid = Vector2i.ZERO
	for role in ["Tank", "Helicopter"]:
		var cost = factions.cost(player, role)
		paid += Vector2i(cost.resource_a, cost.resource_b)
	var electronics = _deposit(hq, "resource_b")
	var stock_before = electronics.resource_b
	var funding_start = game.simulation_time
	game.hud._toggle_pause()
	var delivered_material = false
	for frame in 6000:
		if frame % 90 == 0:
			player._harvest(player._units())
		if (
			switched.resource_a == 0
			and is_instance_of(switched.action, harvest)
			and switched.action._kind == 2
		):
			delivered_material = true
		if player.resource_b >= paid.y:
			break
		await physics_frame
	_check(delivered_material, "Queued electronics assignment did not follow materials delivery")
	if player.resource_b < paid.y:
		var requests = labor.plan(game, player, player._units())
		for worker in workers:
			print(
				"LABOR DETAIL ",
				faction,
				" ",
				worker.position,
				" ",
				worker.action,
				" cargo=",
				worker.resource_a,
				"/",
				worker.resource_b,
				" requested=",
				requests.get(worker, 0),
				" queued=",
				worker.manual_orders.pending
			)
	_check(player.resource_b >= paid.y, "Adaptive gatherers never funded the mixed queue")
	var carried = 0
	for worker in workers:
		carried += worker.resource_b
	_check(
		stock_before - electronics.resource_b == player.resource_b + carried,
		"Electronics income violated finite-stock conservation"
	)
	game.hud._toggle_pause()
	await _review_labor(player, faction + "-electronics")
	var funds = Vector2i(player.resource_a, player.resource_b)
	print(
		"LABOR ORIGINAL FUNDING ",
		faction,
		" elapsed=",
		game.simulation_time - funding_start,
		" earned_E=",
		funds.y,
		" required_E=",
		paid.y
	)
	var economy_before = _labor_economy(player)
	var wing_cost = factions.cost(player, "Helicopter")
	player._train(player._units(), "")
	_check(_labor_queued(air) == "Helicopter", "Original budget did not pay the urgent first wing")
	_check(factory.production_queue.size() == 0, "Routine armor spent unpaid Coordination savings")
	_check(player._production_index == 0, "Held routine armor advanced production sequence")
	_check(
		(
			Vector2i(player.resource_a, player.resource_b)
			== funds - Vector2i(wing_cost.resource_a, wing_cost.resource_b)
		),
		"Urgent first-wing payment differs"
	)
	# The original traffic budget and 6000-frame deadline above are unchanged.
	# The additional research purchase earns its own resources in a separate stage.
	await _labor_progression(player, air, factory)
	paid += Vector2i(player.COORDINATION_COST.resource_a, player.COORDINATION_COST.resource_b)
	_check(
		economy_before - _labor_economy(player) == paid,
		"Coordination and both queues violated exact payment/finite-stock conservation"
	)
	air.process_mode = Node.PROCESS_MODE_INHERIT
	factory.process_mode = Node.PROCESS_MODE_INHERIT
	var tanks = _units(player, "Tank").size()
	game.hud._toggle_pause()
	await _frames(1800)
	_check(
		_units(player, "Helicopter").size() == 1 and _units(player, "Tank").size() == tanks + 1,
		"Paid mixed units did not finish"
	)
	game.hud._toggle_pause()
	print(
		"LABOR MIXED ",
		faction,
		" elapsed=",
		game.simulation_time - start,
		" E=",
		funds.y,
		" paid=",
		paid
	)
	await _review_labor(player, faction + "-mixed")
	player.resource_a = 0
	player.resource_b = 200
	assignments = labor.plan(game, player, player._units())
	_check(
		assignments.values().count(1) >= 4, "Materials deficit retained the electronics-heavy split"
	)
	game.hud._toggle_pause()
	for frame in 6000:
		if frame % 90 == 0:
			player._harvest(player._units())
		var active = workers.filter(
			func(worker): return is_instance_of(worker.action, harvest) and worker.action._kind == 1
		)
		if active.size() >= 4 and player.resource_a >= 4:
			break
		await physics_frame
	game.hud._toggle_pause()
	var material_workers = workers.filter(
		func(worker): return is_instance_of(worker.action, harvest) and worker.action._kind == 1
	)
	_check(material_workers.size() >= 4, "Actual workers failed to rebalance toward materials")
	_check(player.resource_a >= 4, "Rebalanced workers did not deliver materials")
	await _review_labor(player, faction + "-materials")
	print("LABOR MATERIALS ", faction, " M=", player.resource_a)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _restore_handoff(worker):
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Labor handoff snapshot failed")
	if data == null:
		quit(1)
		return null
	var worker_id = capture._reference(worker)
	var clock = game.simulation_time
	var point = worker.position
	var path = "user://ai-labor-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(path, data), "Labor handoff archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Labor handoff archive restore failed")
	if not loaded.ok:
		quit(1)
		return null
	game = loaded.game
	worker = restore.entities[worker_id]
	_freeze(worker.player)
	await _frames(15)
	_check(
		paused and game.simulation_time == clock and worker.position == point,
		"Paused handoff archive advanced"
	)
	_check(
		worker.resource_a == 4 and labor.queued_target(worker) != null,
		"Handoff archive lost cargo or next resource"
	)
	return worker


func _freeze(player):
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if unit.player == player and unit.type == "Worker"
			else Node.PROCESS_MODE_DISABLED
		)


func _spawn(role, player, point):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _deposit(hq, property):
	var choices = get_nodes_in_group("resource_units").filter(
		func(unit):
			return not unit.is_queued_for_deletion() and property in unit and unit.get(property) > 0
	)
	choices.sort_custom(
		func(a, b):
			return (
				hq.position.distance_squared_to(a.position)
				< hq.position.distance_squared_to(b.position)
			)
	)
	return choices[0]


func _review_labor(_player, _label):
	pass


func _labor_progression(player, air, factory):
	var start = game.simulation_time
	var research_at = -1.0
	game.hud._toggle_pause()
	for frame in 3600:
		if frame % 90 == 0:
			player._harvest(player._units())
			player._research(player._units(), "")
			player._train(player._units(), "")
			if research_at < 0 and (player.coordination_left > 0 or player.coordination_unlocked):
				research_at = game.simulation_time - start
		if research_at >= 0 and _labor_queued(factory) == "Tank":
			break
		await physics_frame
	game.hud._toggle_pause()
	_check(research_at >= 0, "Additional earned income did not buy Coordination")
	_check(_labor_queued(factory) == "Tank", "Additional earned income did not fund held armor")
	_check(
		air.production_queue.size() == 1 and factory.production_queue.size() == 1,
		"Progression stage added missing or duplicate production jobs"
	)
	print(
		"LABOR RESEARCH PROGRESSION ",
		player.faction,
		" additional_seconds=",
		game.simulation_time - start,
		" research_paid_at=",
		research_at,
		" funds=",
		Vector2i(player.resource_a, player.resource_b),
		" queued=",
		_labor_queued(air),
		"/",
		_labor_queued(factory)
	)


func _labor_queued(producer):
	var jobs = producer.production_queue.get_elements()
	return "" if jobs.is_empty() else catalog.type_from_path(jobs[0].unit_prototype.resource_path)


func _labor_economy(player):
	var total = Vector2i(player.resource_a, player.resource_b)
	for worker in _units(player, "Worker"):
		total += Vector2i(worker.resource_a, worker.resource_b)
	for deposit in get_nodes_in_group("resource_units"):
		if not deposit.is_queued_for_deletion():
			total += Vector2i(
				deposit.resource_a if "resource_a" in deposit else 0,
				deposit.resource_b if "resource_b" in deposit else 0
			)
	return total
