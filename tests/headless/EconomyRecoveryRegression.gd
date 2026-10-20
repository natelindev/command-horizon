extends "res://tests/headless/Skirmish.gd"

var plan
var harvest
var game
var human


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	plan = load("res://tests/UnitQueries.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		await _open(faction)
		await _remove_workers()
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


func _workers():
	return plan.owned_units(human).filter(func(unit): return unit.type == "Worker")


func _remove_workers():
	for worker in _workers():
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
	_check(human.resource_a < 20 or human.resource_b < 20, "Research did not charge its cost")
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
	queue.cancel(job)
	_check(human.resource_a == 6, "Queue refund did not return the paid cost")
	var hq = _unit(human, "CommandCenter")
	_check(
		hq.production_queue.produce(load(Catalog.scene_path("Worker"))) != null,
		"Replacement engineer could not be purchased"
	)
	await _restore()
	hq = _unit(human, "CommandCenter")
	_check(hq.production_queue.size() == 1, "Loaded HQ lost the paid replacement engineer")
	var clock_before = game.simulation_time
	await _frames(20)
	_check(
		game.simulation_time == clock_before and _unit(human, "Worker") == null,
		"Paused restore advanced production"
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


func _headquarters():
	var hq = _unit(human, "CommandCenter")
	var point = hq.position
	human.resource_a = 80
	human.resource_b = 20
	hq.queue_free()
	await _frames(6)
	var builders = _workers()
	builders.sort_custom(
		func(a, b): return a.position.distance_to(point) < b.position.distance_to(point)
	)
	var builder = builders[0]
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
	_check(
		(
			builder.manual_orders.current.get("kind") == "construct"
			or builder.manual_orders.pending.any(func(order): return order.kind == "construct")
		),
		"HQ placement did not assign the selected builder"
	)
	await _restore()
	var left = game._defeat_timers[human]
	_check(
		plan.owned_units(human).any(
			func(unit): return unit.type == "CommandCenter" and not unit.is_constructed()
		),
		"Loaded HQ recovery lost foundation"
	)
	await _frames(30)
	_check(game._defeat_timers[human] == left, "Paused restore advanced defeat countdown")
	game.hud._toggle_pause()
	await _until(func(): return human.has_completed_structure("CommandCenter"), 3300)
	await _frames(3)
	_check(
		not game.finished and game._defeat_timers[human] == 60.0,
		"Paid HQ rebuild did not reset recovery countdown"
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
