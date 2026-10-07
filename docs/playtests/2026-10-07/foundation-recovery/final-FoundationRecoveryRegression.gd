extends "res://tests/headless/HQCountdownRegression.gd"

var factions = ["bastion", "helix", "frontier"]
var plan
var catalog
var harvesting
var owner
var foundation
var original_hq
var origin
var label


func _initialize():
	# Three earned openings exceed the inherited 600-second aggregate timer.
	create_timer(1200).timeout.connect(
		func():
			push_error("Foundation recovery regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	plan = load("res://source/match/SkirmishPlan.gd")
	catalog = load("res://source/match/FactionCatalog.gd")
	harvesting = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions:
		label = faction
		await _mirror(faction)
		owner = game._get_human_player()
		original_hq = _units(owner, "CommandCenter")[0]
		origin = original_hq.position
		if "--advice-only" in OS.get_cmdline_user_args():
			owner.resource_a = 120
			owner.resource_b = 32
		else:
			await _earn_budget()
		var barracks = await _place("Barracks", _nearest_worker(original_hq))
		if "--advice-only" in OS.get_cmdline_user_args():
			barracks.construct(1.0)
		else:
			game.hud._toggle_pause()
			for frame in 3600:
				await _frames(1)
				if barracks.is_constructed():
					break
			game.hud.pause_after_load()
			_check(barracks.is_constructed(), "Paid barracks prerequisite did not complete")
		foundation = await _place("VehicleFactory", null)
		if "--advice-only" in OS.get_cmdline_user_args():
			foundation.construct(.25)
		else:
			var worker = _nearest_worker(foundation)
			worker.issue_manual_order(
				load("res://source/match/units/actions/Constructing.gd").new(foundation)
			)
			game.hud._toggle_pause()
			for frame in 3600:
				await _frames(1)
				if foundation._construction_progress >= .2:
					break
			game.hud.pause_after_load()
			_check(foundation._construction_progress >= .2, "Paid factory construction never began")
		original_hq.hp = 0
		await _frames(5)
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var step = plan.next_step(owner)
		_check(
			step.id == "hq_foundation" and step.units == [foundation],
			label + ": recoverable foundation budget overlooked"
		)
		for index in 10:
			plan.next_step(owner)
		_check(
			Vector2i(owner.resource_a, owner.resource_b) == funds,
			"Advice spent or refunded resources"
		)
		await _review("refund")
		if not "--advice-only" in OS.get_cmdline_user_args():
			await _disk()
			_check(
				plan.next_step(owner).id == "hq_foundation",
				"Loaded recovery lost foundation refund"
			)
			await _review("restored")
			var refund = foundation.construction_refund()
			await _cancel_foundation()
			await _frames(5)
			_check(
				(
					Vector2i(owner.resource_a, owner.resource_b)
					== funds + Vector2i(refund.resource_a, refund.resource_b)
				),
				"Recovery cancellation refunded wrong amount"
			)
			_check(plan.next_step(owner).id == "CommandCenter", "Refund did not enable HQ rebuild")
			foundation = await _place("CommandCenter", plan.next_step(owner).units[0])
			await _review("rebuilding")
			game.hud._toggle_pause()
			for frame in 3600:
				await _frames(1)
				if foundation.is_constructed() or game.finished:
					break
			await _frames(3)
			game.hud.pause_after_load()
			_check(
				foundation.is_constructed() and not game.finished,
				"Earned refund did not finish HQ before defeat"
			)
			_check(game._defeat_timers[owner] == 60.0, "Rebuild did not reset defeat countdown")
			await _review("recovered")
		await _funding_boundaries()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Foundation recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _earn_budget():
	var workers = _units(owner, "Worker")
	for index in 3:
		var electronics = index > 0
		var deposits = get_nodes_in_group("resource_units").filter(
			func(node):
				return node.can_harvest(workers[index]) and (("resource_b" in node) == electronics)
		)
		deposits.sort_custom(
			func(a, b):
				return (
					workers[index].position.distance_squared_to(a.position)
					< workers[index].position.distance_squared_to(b.position)
				)
		)
		workers[index].issue_manual_order(harvesting.new(deposits[0]))
	var start = game.simulation_time
	game.hud._toggle_pause()
	for frame in 18000:
		await _frames(1)
		for index in 3:
			if owner.resource_a >= 120 if index == 0 else owner.resource_b >= 32:
				workers[index].issue_manual_order(null)
		if owner.resource_a >= 120 and owner.resource_b >= 32:
			break
	game.hud.pause_after_load()
	_check(
		owner.resource_a >= 120 and owner.resource_b >= 32,
		"Real deliveries did not earn recovery budget"
	)
	_check(owner.resource_a < 145, "Earned fixture no longer needs a construction refund")
	print(
		"EARNED BUDGET ",
		label,
		" funds=",
		Vector2i(owner.resource_a, owner.resource_b),
		" elapsed=",
		game.simulation_time - start
	)


func _nearest_worker(site):
	var workers = _units(owner, "Worker")
	workers.sort_custom(
		func(a, b):
			return (
				a.position.distance_squared_to(site.position)
				< b.position.distance_squared_to(site.position)
			)
	)
	return workers[0]


func _place(role, builder):
	var handler = owner.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/%s.tscn" % role))
	var valid = false
	for radius in [7.0, 10.0, 13.0, 17.0]:
		for index in 24:
			var angle = index * TAU / 24
			handler._active_blueprint_node.position = (
				origin + Vector3(cos(angle), 0, sin(angle)) * radius
			)
			if (
				handler._calculate_blueprint_position_validity()
				== handler.BlueprintPositionValidity.VALID
			):
				valid = true
				break
		if valid:
			break
	_check(valid, "No legal recovery placement: " + role)
	if not valid:
		push_error("No legal recovery placement: " + role)
		quit(1)
		return null
	root.get_node("MatchSignals").deselect_all_units.emit()
	if builder != null:
		builder.get_node("Selection").select()
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var cost = catalog.cost(owner, role, true)
	handler._finish_structure_placement()
	await _frames(5)
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Recovery placement did not pay exact cost"
	)
	return _units(owner, role).filter(func(unit): return not unit.is_constructed())[0]


func _disk():
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(foundation)
	var progress = foundation._construction_progress
	var timer = game._defeat_timers[owner]
	var path = "user://foundation-recovery-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(path, data), "Recovery save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Recovery load failed")
	game = loaded.game
	foundation = restore.entities[id]
	owner = foundation.player
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(10)
	_check(
		(
			paused
			and game.simulation_time == data.simulation_time
			and foundation._construction_progress == progress
			and game._defeat_timers[owner] == timer
		),
		"Paused recovery changed during load"
	)


func _funding_boundaries():
	# Isolated affordability boundaries; distinct from the earned path above.
	for unit in _units(owner, "CommandCenter"):
		unit.queue_free()
	await _frames(3)
	if not is_instance_valid(foundation) or foundation.is_constructed():
		owner.resource_a = 100
		owner.resource_b = 32
		foundation = await _place("VehicleFactory", null)
		foundation.construct(.25)
	owner.resource_a = 46
	owner.resource_b = 20
	_check(plan.next_step(owner).id == "hq_funds", "Insufficient partial refund promised HQ")
	owner.resource_a = 80
	owner.resource_b = 10
	_check(plan.next_step(owner).id == "hq_funds", "Materials refund hid electronics shortfall")
	owner.resource_a = 47
	owner.resource_b = 11
	_check(
		plan.next_step(owner).id == "hq_foundation", "Exact floor-rounded combined budget rejected"
	)
	foundation.hp = 0
	_check(plan.next_step(owner).id == "hq_funds", "Destroyed foundation promised refund")
	await _frames(3)


func _cancel_foundation():
	foundation.cancel_construction()


func _review(_stage):
	return true
