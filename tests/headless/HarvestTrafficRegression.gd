extends "res://tests/headless/SaveRestoreEdges.gd"

const ARCHIVE_DIRECTORY = "res://docs/playtests/2026-10-05/harvest-traffic/"
const WATCHED_IDS = {"bastion": ["unit-17"], "helix": ["unit-19", "unit-30"]}
const BLOCKER_ID = "unit-29"
const COLLECTION_DEADLINE = 12.0
const RETURN_DEADLINE = 12.0
var harvest_script
var _ghost_overlaps = {}


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest_script = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	if not OS.get_cmdline_user_args().has("--residual-only"):
		for faction in ["bastion", "helix"]:
			await _archived_traffic(faction)
		await _manual_replacement()
	await _residual_traffic()
	for message in errors:
		push_error(message)
	print("Harvest traffic: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_archive(faction):
	var file = FileStore.new()
	var data = file.read_file(ARCHIVE_DIRECTORY + faction + "-capture.json")
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, faction + ": traffic archive failed to restore")
	if not loaded.ok:
		return null
	game = loaded.game
	var player = restore.entities[BLOCKER_ID].player
	# Reproduce the captured labor fixture's processing, retaining every actor,
	# footprint, position, order and cargo. In particular the settled repair
	# robot remains on the route; no geometry is moved to make travel easier.
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if unit.player == player and unit.type == "Worker"
			else Node.PROCESS_MODE_DISABLED
		)
	return restore


func _archived_traffic(faction):
	var restore = await _open_archive(faction)
	if restore == null:
		return
	var blocker = restore.entities[BLOCKER_ID]
	var player = blocker.player
	var workers = _units(player, "Worker")
	var watched = WATCHED_IDS[faction].map(func(id): return restore.entities[id])
	var original = {}
	var previous = {}
	var first_collection = {}
	var delivered = {}
	var blocker_position = blocker.position
	var clock = game.simulation_time
	for worker in workers:
		original[worker] = {
			"position": worker.position,
			"cargo": Vector2i(worker.resource_a, worker.resource_b),
			"action": worker.action,
			"orders": worker.manual_orders.current.duplicate(),
			"pending": worker.manual_orders.pending.duplicate(),
			"field": worker.action._field_origin,
			"kind": worker.action._kind
		}
		previous[worker] = {"position": worker.position, "cargo": worker.resource_b}
	await _frames(30)
	_check(paused and game.simulation_time == clock, faction + ": paused archive advanced")
	for worker in workers:
		_check(
			(
				worker.position == original[worker].position
				and Vector2i(worker.resource_a, worker.resource_b) == original[worker].cargo
			),
			faction + ": paused archive changed a worker or its cargo"
		)
		_check_order(worker, original[worker], faction)
	await _review_traffic(faction + "-loaded", watched[-1], blocker)
	var stock = _economy_total(player, workers)
	var funds = player.resource_b
	var maximum_step_ratio = 0.0
	var minimum_clearance = INF
	var reviewed_recovery = false
	var reviewed_collection = false
	var reviewed_delivery = false
	var actors = get_nodes_in_group("units") + get_nodes_in_group("resource_units")
	paused = false
	for frame in 2400:
		await physics_frame
		for worker in workers:
			var step = worker.position.distance_to(previous[worker].position)
			maximum_step_ratio = maxf(
				maximum_step_ratio,
				step / (worker.movement_speed / Engine.physics_ticks_per_second + .002)
			)
			minimum_clearance = minf(minimum_clearance, _clearance(worker, actors))
			if worker in watched:
				if worker.resource_b > previous[worker].cargo and not first_collection.has(worker):
					first_collection[worker] = game.simulation_time - clock
					_check(
						root.get_node("Utils").Match.Unit.Movement.units_adhere(
							worker, worker.action.get_resource_unit()
						),
						faction + ": engineer collected outside contact range"
					)
					if not reviewed_collection:
						reviewed_collection = true
						await _review_paused(faction + "-collected", worker, blocker)
				if (
					first_collection.has(worker)
					and previous[worker].cargo > 0
					and worker.resource_b == 0
				):
					delivered[worker] = true
					if not reviewed_delivery:
						reviewed_delivery = true
						await _review_paused(faction + "-delivered", worker, blocker)
				if not reviewed_recovery and worker.get_node("Movement")._recovery_left > 0:
					reviewed_recovery = true
					await _review_paused(faction + "-recovery", worker, blocker)
			previous[worker] = {"position": worker.position, "cargo": worker.resource_b}
		if frame % 60 == 0:
			_check(_economy_total(player, workers) == stock, faction + ": finite stock changed")
	paused = true
	_check(blocker.position == blocker_position, faction + ": traffic moved the settled blocker")
	_check(maximum_step_ratio <= 1.0, faction + ": recovery exceeded movement speed")
	_check(minimum_clearance >= -.08, faction + ": recovery crossed another footprint")
	_check(player.resource_b > funds, faction + ": traffic never delivered electronics")
	_check(_economy_total(player, workers) == stock, faction + ": final conservation failed")
	for worker in workers:
		_check_order(worker, original[worker], faction)
	for index in watched.size():
		var worker = watched[index]
		var label = faction + " " + WATCHED_IDS[faction][index]
		_check(first_collection.has(worker), label + ": never collected actual cargo")
		if faction == "helix":
			_check(delivered.has(worker), label + ": never delivered its collected cargo")
			_check(
				first_collection.get(worker, INF) <= COLLECTION_DEADLINE,
				label + ": settled support blocked real collection beyond 12 seconds"
			)
		print("HARVEST TRAFFIC ", label, " first_cargo=", first_collection.get(worker, -1.0))
	print(
		"HARVEST BOUNDS ",
		faction,
		" income=",
		player.resource_b - funds,
		" step_ratio=",
		maximum_step_ratio,
		" clearance=",
		minimum_clearance
	)
	await _close_archive()


func _residual_traffic():
	var restore = await _open_archive("helix-residual")
	if restore == null:
		return
	var blocker = restore.entities[BLOCKER_ID]
	var player = blocker.player
	var workers = _units(player, "Worker")
	var actors = get_nodes_in_group("units") + get_nodes_in_group("resource_units")
	var original = {}
	var previous = {}
	var returning_since = {}
	var delivered = 0
	var reviewed_return = false
	var reviewed_delivery = false
	var longest_return = 0.0
	var maximum_step_ratio = 0.0
	var minimum_clearance = INF
	var blocker_position = blocker.position
	var clock = game.simulation_time
	var stock = _economy_total(player, workers)
	var funds = player.resource_b
	for worker in workers:
		original[worker] = {
			"action": worker.action,
			"orders": worker.manual_orders.current.duplicate(),
			"pending": worker.manual_orders.pending.duplicate(),
			"field": worker.action._field_origin,
			"kind": worker.action._kind
		}
		previous[worker] = {"position": worker.position, "cargo": worker.resource_b}
		if worker.resource_b > 0 and worker.action._state == harvest_script.State.MOVING_TO_CC:
			returning_since[worker] = clock
	await _review_traffic("helix-residual-loaded", workers[-2], blocker)
	# This later archive organically recreates repeated loaded trips around the
	# settled support. Lateral avoidance can keep moving without completing a leg;
	# measure actual cargo delivery, including trips still unfinished at the end.
	paused = false
	for frame in 3600:
		await physics_frame
		for worker in workers:
			maximum_step_ratio = maxf(
				maximum_step_ratio,
				(
					worker.position.distance_to(previous[worker].position)
					/ (worker.movement_speed / Engine.physics_ticks_per_second + .002)
				)
			)
			minimum_clearance = minf(minimum_clearance, _clearance(worker, actors))
			if (
				worker.resource_b > 0
				and worker.action._state == harvest_script.State.MOVING_TO_CC
				and not returning_since.has(worker)
			):
				returning_since[worker] = game.simulation_time
			if returning_since.has(worker):
				longest_return = maxf(
					longest_return, game.simulation_time - returning_since[worker]
				)
				if not reviewed_return and worker.position.distance_to(blocker.position) < 2.0:
					reviewed_return = true
					await _review_paused("helix-residual-returning", worker, blocker)
				if previous[worker].cargo > 0 and worker.resource_b == 0:
					delivered += 1
					returning_since.erase(worker)
					_check(
						root.get_node("Utils").Match.Unit.Movement.units_adhere(
							worker, worker.action._cc_unit
						),
						"Residual traffic delivered outside HQ contact"
					)
					if not reviewed_delivery:
						reviewed_delivery = true
						await _review_paused("helix-residual-delivered", worker, blocker)
			previous[worker] = {"position": worker.position, "cargo": worker.resource_b}
		if frame % 60 == 0:
			_check(
				_economy_total(player, workers) == stock, "Residual traffic changed finite stock"
			)
	paused = true
	_check(blocker.position == blocker_position, "Residual traffic moved the settled support")
	_check(maximum_step_ratio <= 1.0, "Residual traffic exceeded movement speed")
	_check(minimum_clearance >= -.08, "Residual traffic crossed another footprint")
	_check(delivered >= 5 and player.resource_b > funds, "Residual traffic missed real deliveries")
	_check(_economy_total(player, workers) == stock, "Residual traffic final conservation failed")
	_check(
		longest_return <= RETURN_DEADLINE, "Settled support delayed loaded return beyond 12 seconds"
	)
	for worker in workers:
		_check_order(worker, original[worker], "Residual traffic")
	print(
		"HARVEST RESIDUAL deliveries=",
		delivered,
		" longest_return=",
		longest_return,
		" income=",
		player.resource_b - funds,
		" step_ratio=",
		maximum_step_ratio,
		" clearance=",
		minimum_clearance
	)
	await _close_archive()


func _check_order(worker, original, label):
	_check(
		(
			worker.action == original.action
			and worker.action._field_origin == original.field
			and worker.action._kind == original.kind
			and worker.manual_orders.current == original.orders
			and worker.manual_orders.pending == original.pending
		),
		label + ": recovery replaced the harvest assignment or manual queue"
	)


func _economy_total(player, workers):
	var result = Vector2i(player.resource_a, player.resource_b)
	for worker in workers:
		result += Vector2i(worker.resource_a, worker.resource_b)
	for deposit in get_nodes_in_group("resource_units"):
		if "resource_a" in deposit:
			result.x += deposit.resource_a
		else:
			result.y += deposit.resource_b
	return result


func _clearance(worker, actors):
	var result = INF
	for other in actors:
		if other == worker or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if "movement_domain" in other and other.movement_domain != worker.movement_domain:
			continue
		var gap = (
			worker.global_position_yless.distance_to(other.global_position_yless)
			- worker.radius
			- other.radius
		)
		# Harvest runs ghost through mobile units; static footprints still apply.
		# An overlap left when a run ends may only resolve, so it is exempt until
		# the pair separates.
		var pair = [worker.get_instance_id(), other.get_instance_id()]
		if (
			other.is_in_group("units")
			and other.movement_speed > 0
			and (worker.get_node("Movement").ghosted or other.get_node("Movement").ghosted)
		):
			if gap < -.08:
				_ghost_overlaps[pair] = true
			continue
		if _ghost_overlaps.has(pair):
			if gap >= -.08:
				_ghost_overlaps.erase(pair)
			continue
		result = minf(result, gap)
	return result


func _manual_replacement():
	var restore = await _open_archive("helix")
	if restore == null:
		return
	var worker = restore.entities["unit-30"]
	var blocker = restore.entities[BLOCKER_ID]
	var movement = worker.get_node("Movement")
	_check(movement._recovery_left > 0, "Manual replacement fixture missed saved recovery")
	var position = worker.position
	var cargo = Vector2i(worker.resource_a, worker.resource_b)
	var goal = Vector3(108, 0, 58)
	worker.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(goal))
	_check(
		movement.target_position == goal and movement._recovery_left == 0,
		"Manual replacement retained the obsolete recovery"
	)
	await _frames(30)
	_check(worker.position == position, "Paused replacement moved the engineer")
	await _review_traffic("manual-replaced", worker, blocker)
	paused = false
	# Record the actual arrival within ten simulated seconds. Once idle, the
	# engineer may later yield passively to the remaining workers' traffic.
	var reached = false
	for frame in Engine.physics_ticks_per_second * 10:
		await physics_frame
		reached = reached or worker.position.distance_to(goal) < .4
	paused = true
	_check(reached, "Manual replacement did not reach its goal")
	_check(
		(
			Vector2i(worker.resource_a, worker.resource_b) == cargo
			and not is_instance_of(worker.action, harvest_script)
		),
		"Obsolete recovery resumed harvesting over the manual order"
	)
	await _review_traffic("manual-arrived", worker, blocker)
	await _close_archive()


func _review_paused(label, watched, blocker):
	paused = true
	await _review_traffic(label, watched, blocker)
	paused = false


func _review_traffic(_label, _watched, _blocker):
	return true


func _close_archive():
	game.queue_free()
	await _frames(5)
	game = null
