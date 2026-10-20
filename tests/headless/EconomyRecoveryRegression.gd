extends "res://tests/headless/Skirmish.gd"

var advice
var plan
var harvest
var game
var human


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	advice = load("res://source/match/EconomyAdvice.gd")
	plan = load("res://source/match/SkirmishPlan.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		await _open(faction)
		await _assignments()
		await _replacement()
		await _close()
		await _open(faction)
		await _headquarters()
		await _close()
		print("Economy recovery scenarios: " + faction)
	for error in _errors:
		push_error(error)
	print("Economy recovery: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _open(faction):
	game = await _start(_settings(faction, "helix", false))
	human = game._get_human_player()
	get_nodes_in_group("players")[1].set_process(false)


func _close():
	paused = false
	game.queue_free()
	await _frames(5)


func _wait_state(worker, reason):
	var action = harvest.new(null)
	action.restoring = true
	action._kind = 1
	action._field_origin = worker.global_position_yless
	action._state = harvest.State.WAITING
	action._waiting_reason = reason
	action._retry_left = 0.5
	worker.issue_manual_order(action)


func _assignments():
	var workers = advice.role(plan.owned_units(human), "Worker")
	var deposit = get_nodes_in_group("resource_units")[0]
	workers[0].issue_manual_order(harvest.new(deposit))
	var cost_before = Vector2(human.resource_a, human.resource_b)
	var active = workers[0].action
	var build = plan.next_step(human)
	_check(
		build.id == "Barracks" and build.units[0] != workers[0],
		"Guide stole active gatherer while idle builders existed"
	)
	_wait_state(workers[1], harvest.Wait.DEPLETED)
	var expansion = plan.next_step(human)
	_check(
		expansion.id == "expand" and expansion.units == [workers[1]],
		"Partial depletion was masked by active economy"
	)
	_wait_state(workers[2], harvest.Wait.HQ)
	_check(plan.next_step(human).id == "drop_off", "Stranded cargo was not prioritized")
	workers[2].issue_manual_order(null)
	_wait_state(workers[1], harvest.Wait.DELIVERED)
	_check(plan.next_step(human).id == "reassign", "Delivered workers lacked field guidance")
	_wait_state(workers[1], harvest.Wait.SLOT)
	_wait_state(workers[2], harvest.Wait.SLOT)
	_check(
		plan.next_step(human).id == "distribute",
		"Oversubscribed field lacked redistribution guidance"
	)
	for index in range(10):
		plan.next_step(human)
	_check(
		Vector2(human.resource_a, human.resource_b) == cost_before and workers[0].action == active,
		"Advice spent funds or replaced an order"
	)
	workers[1].issue_manual_order(null)
	workers[2].issue_manual_order(null)
	human.resource_a = 0
	_check(
		plan.next_step(human).id == "fund_Barracks", "Unaffordable building lacked funding guidance"
	)
	for worker in workers:
		worker.issue_manual_order(null)
		worker.queue_free()
	await _frames(4)


func _replacement():
	for role in ["VehicleFactory", "CommandLab"]:
		var unit = load(Catalog.scene_path(role)).instantiate()
		var location = Vector3(23 if role == "VehicleFactory" else 31, 0, 12)
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), location), human, false)
	await _frames(4)
	human.resource_a = 20
	human.resource_b = 20
	_check(human.start_coordination(_unit(human, "CommandLab")), "Research refund fixture failed")
	_check(plan.next_step(human).id == "workers_research", "Paid research recovery was overlooked")
	human.cancel_coordination()
	_check(human.resource_a == 20 and human.resource_b == 20, "Research refund lost paid resources")
	var barracks = load(Catalog.scene_path("Barracks")).instantiate()
	game._setup_and_spawn_unit(barracks, Transform3D(Basis(), Vector3(20, 0, 12)), human, false)
	await _frames(4)
	human.resource_a = 6
	human.resource_b = 0
	paused = true
	var queue = barracks.production_queue
	var job = queue.produce(load(Catalog.scene_path("Infantry")))
	_check(job != null and human.resource_a == 0, "Paid refund fixture failed")
	var step = plan.next_step(human)
	_check(
		step.id == "workers_refund" and step.units == [barracks],
		"Bankrupt worker loss did not identify paid queue"
	)
	queue.cancel(job)
	_check(
		human.resource_a == 6 and plan.next_step(human).id == "workers",
		"Refund did not enable replacement"
	)
	var hq = _unit(human, "CommandCenter")
	_check(
		hq.production_queue.produce(load(Catalog.scene_path("Worker"))) != null,
		"Replacement engineer could not be purchased"
	)
	_check(
		plan.next_step(human).id == "workers_pending", "Guide requested duplicate paid replacement"
	)
	await _restore()
	_check(plan.next_step(human).id == "workers_pending", "Loaded advice lost pending replacement")
	var clock_before = game.simulation_time
	await _frames(20)
	_check(
		game.simulation_time == clock_before and _unit(human, "Worker") == null,
		"Paused advice advanced production"
	)
	game.hud._toggle_pause()
	await _until(func(): return _unit(human, "Worker") != null)
	var worker = _unit(human, "Worker")
	if worker == null:
		return
	var deposits = get_nodes_in_group("resource_units").filter(func(d): return "resource_a" in d)
	deposits.sort_custom(
		func(a, b):
			return a.position.distance_to(worker.position) < b.position.distance_to(worker.position)
	)
	worker.issue_manual_order(harvest.new(deposits[0]))
	await _until(func(): return human.resource_a > 0)
	_check(human.resource_a >= 4, "Refund → worker → harvest never restored income")
	worker.issue_manual_order(null)
	worker.queue_free()
	await _frames(3)
	human.resource_a = 0
	_check(
		plan.next_step(human).id == "last_stand",
		"Irrecoverable economy still recommended an unaffordable worker"
	)


func _headquarters():
	var hq = _unit(human, "CommandCenter")
	var point = hq.position
	human.resource_a = 80
	human.resource_b = 20
	hq.queue_free()
	await _frames(6)
	var step = plan.next_step(human)
	var build_time = "%d s" % factions.BUILD_TIMES.CommandCenter
	_check(
		step.id == "CommandCenter" and build_time in step.description,
		"HQ rebuild guidance omitted budget or build time"
	)
	var builder = step.units[0]
	var handler = human.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load(Catalog.scene_path("CommandCenter")))
	var valid = false
	for distance in [0.0, 5.0, 7.0, 9.0]:
		for index in range(16):
			var angle = index * TAU / 16
			handler._active_blueprint_node.global_position = (
				point + Vector3(cos(angle), 0, sin(angle)) * distance
			)
			if (
				handler._calculate_blueprint_position_validity()
				== handler.BlueprintPositionValidity.VALID
			):
				valid = true
				break
		if valid:
			break
	if not valid:
		_check(false, "No legal HQ recovery site near the starting base")
		handler._cancel_structure_placement()
		return
	root.get_node("MatchSignals").deselect_all_units.emit()
	builder.get_node("Selection").select()
	handler._finish_structure_placement()
	_check(human.resource_a == 0 and human.resource_b == 0, "HQ rebuild did not reserve full cost")
	await _frames(60)
	step = plan.next_step(human)
	_check(
		(
			step.id == "CommandCenter"
			and "already paid" in step.description
			and step.units == [builder]
		),
		"Paid foundation prompted duplicate spending or wrong builder"
	)
	await _restore()
	var left = game._defeat_timers[human]
	_check(
		"already paid" in plan.next_step(human).description, "Loaded HQ recovery lost foundation"
	)
	await _frames(30)
	_check(game._defeat_timers[human] == left, "Paused advice advanced defeat countdown")
	game.hud._toggle_pause()
	await _until(func(): return human.has_completed_structure("CommandCenter"), 3300)
	await _frames(3)
	_check(
		not game.finished and game._defeat_timers[human] == 60.0,
		"Paid HQ rebuild did not reset recovery countdown"
	)
	_unit(human, "CommandCenter").queue_free()
	await _frames(3)
	human.resource_a = 0
	human.resource_b = 0
	_check(
		plan.next_step(human).id == "hq_funds",
		"HQ budget shortfall recommended cargo delivery without HQ"
	)
	var producer = load(Catalog.scene_path("Barracks")).instantiate()
	game._setup_and_spawn_unit(producer, Transform3D(Basis(), Vector3(25, 0, 12)), human, false)
	await _frames(3)
	paused = true
	human.resource_a = 12
	var first = producer.production_queue.produce(load(Catalog.scene_path("Infantry")))
	producer.production_queue.produce(load(Catalog.scene_path("Infantry")))
	_check(
		plan.next_step(human).id == "hq_funds", "Insufficient combined refunds promised HQ recovery"
	)
	human.resource_a = 74
	human.resource_b = 20
	_check(
		plan.next_step(human).id == "hq_refund", "Available paid jobs were ignored for HQ recovery"
	)
	producer.production_queue.cancel(first)
	_check(
		plan.next_step(human).id == "CommandCenter",
		"HQ refund failed to restore an actionable rebuild"
	)
	producer.production_queue.cancel_all()
	human.resource_a = 0
	human.resource_b = 0
	paused = false
	for worker in advice.role(plan.owned_units(human), "Worker"):
		worker.queue_free()
	await _frames(3)
	_check(
		plan.next_step(human).id == "last_stand",
		"No-HQ/no-worker recovery offered an impossible build"
	)


func _restore():
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Recovery capture failed: " + capture.error)
	if data == null:
		return
	var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
	_check(restored.ok, "Recovery archive restore failed")
	if restored.ok:
		game = restored.game
		human = game._get_human_player()
		get_nodes_in_group("players")[1].set_process(false)


func _until(predicate, limit = 1800):
	for index in range(limit):
		if predicate.call():
			return
		await physics_frame
	_check(false, "Recovery operation timed out")
