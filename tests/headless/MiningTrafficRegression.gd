extends "res://tests/headless/Skirmish.gd"

# Engineers at a real base keep their harvest lanes moving, and fresh orders
# reach motion within a couple of ticks. Prints the measured figures as well:
# godot --headless --path . --fixed-fps 60 --script tests/headless/MiningTrafficRegression.gd
# Optional user args: --map=res://... and --detail (per-unit latency stages).

const WORKERS = 14
const SECONDS = 90.0
# Before harvest ghosting: ~57 deliveries, ~30% of travel stalled, ~4,900
# worker-ticks standing still in work-face searches. After: ~100, ~3%, 0.
const MINIMUM_DELIVERIES = 85
const MAXIMUM_STALLED = 0.10
const MAXIMUM_SEARCH_STOPPED_TICKS = 60

var game
var human
var orders
var moving_to_unit
var harvest


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	orders = load("res://source/match/orders/ManualOrders.gd")
	moving_to_unit = load("res://source/match/units/actions/MovingToUnit.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("bastion", "helix", false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			settings.map_path = argument.trim_prefix("--map=")
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.player != human:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var cc = _unit(human, "CommandCenter")
	var workers = get_nodes_in_group("units").filter(
		func(unit): return unit.player == human and unit.type == "Worker"
	)
	while workers.size() < WORKERS:
		var worker = load(Catalog.scene_path("Worker")).instantiate()
		var angle = workers.size() * TAU / WORKERS
		var point = cc.global_position + Vector3(cos(angle), 0, sin(angle)) * (cc.radius + 2.0)
		game._setup_and_spawn_unit(worker, Transform3D(Basis(), point), human, false)
		workers.append(worker)
	await _frames(30)
	var deposits = get_nodes_in_group("resource_units")
	deposits.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_to(cc.global_position)
				< b.global_position.distance_to(cc.global_position)
			)
	)
	var field = deposits[0]
	for worker in workers:
		worker.manual_orders.submit(orders.target_order("gather", field), false, false)
	await _traffic(workers)
	var movers = workers.slice(0, 8)
	await _latency("workers->point", movers, cc.global_position + Vector3(12, 0, 0))
	_check(
		movers.all(func(worker): return not worker.get_node("Movement").ghosted),
		"A manual move kept harvest ghosting"
	)
	for worker in workers:
		worker.manual_orders.submit(orders.target_order("gather", field), false, false)
	await _frames(300)
	await _regather_latency(workers.slice(0, 6), field)
	var center = Vector3(game.map.size.x / 2.0, 0, game.map.size.y / 2.0)
	var inward = ((center - cc.global_position) * Vector3(1, 0, 1)).normalized()
	var side = inward.cross(Vector3.UP)
	var staging = cc.global_position + inward * 12.0
	var tanks = []
	for index in 12:
		var tank = load(Catalog.scene_path("Tank")).instantiate()
		var point = staging + side * ((index % 4) - 1.5) * 2.4 + inward * (index / 4) * 2.4
		game._setup_and_spawn_unit(tank, Transform3D(Basis(), point), human, false)
		tanks.append(tank)
	await _frames(30)
	var open = await _latency("tanks->point", tanks, staging + inward * 18.0)
	# The order pipeline is deterministic: every unit steers on the first tick
	# (previously the second). Crowd avoidance makes the worst case noisy.
	_check(
		open.stages.values().all(func(stage): return stage.vel == 1),
		"A group order did not steer on its first tick"
	)
	_check(open.median <= 6, "Open-ground group order was slow to move")
	await _latency("tanks->edge", tanks, cc.global_position - inward * 40.0)
	game.queue_free()
	await _frames(4)
	for message in _errors:
		push_error(message)
	print("Mining traffic: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _traffic(workers):
	var start_income = human.resource_a + human.resource_b
	var previous = {}
	var cargo = {}
	for worker in workers:
		previous[worker] = worker.global_position
		cargo[worker] = 0
	var deliveries = 0
	var travel = 0
	var stalled = 0
	var search_stopped = 0
	var ghost_mismatches = 0
	var contacts = 0
	for tick in int(SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
		for worker in workers:
			var action = worker.action
			var step = worker.global_position.distance_to(previous[worker])
			previous[worker] = worker.global_position
			var load_now = worker.resource_a + worker.resource_b
			if cargo[worker] > 0 and load_now == 0:
				deliveries += 1
			cargo[worker] = load_now
			if action == null or action.get_script() != harvest:
				continue
			var running = [
				action.State.MOVING_TO_RESOURCE, action.State.COLLECTING, action.State.MOVING_TO_CC
			]
			if worker.get_node("Movement").ghosted != (action._state in running):
				ghost_mismatches += 1
			if action._state in [action.State.MOVING_TO_RESOURCE, action.State.MOVING_TO_CC]:
				travel += 1
				if step < worker.movement_speed / Engine.physics_ticks_per_second * .25:
					stalled += 1
				var sub = action._sub_action
				if (
					is_instance_valid(sub)
					and sub.get_script() == moving_to_unit
					and sub._searching
					and not worker.get_node("Movement")._has_destination
				):
					search_stopped += 1
		for i in workers.size():
			for j in range(i + 1, workers.size()):
				var a = workers[i]
				var b = workers[j]
				if (
					a.global_position_yless.distance_to(b.global_position_yless)
					< a.radius + b.radius + .1
				):
					contacts += 1
	var income = human.resource_a + human.resource_b - start_income
	var stalled_share = float(stalled) / maxf(1, travel)
	print(
		(
			"TRAFFIC workers=%d income=%d deliveries=%d stalled=%.1f%% search_stopped=%d contacts/tick=%.2f"
			% [
				workers.size(),
				income,
				deliveries,
				100.0 * stalled_share,
				search_stopped,
				float(contacts) / (SECONDS * Engine.physics_ticks_per_second)
			]
		)
	)
	_check(deliveries >= MINIMUM_DELIVERIES, "Harvest lanes delivered only %d loads" % deliveries)
	_check(
		stalled_share <= MAXIMUM_STALLED,
		"Engineers stalled for %.0f%% of travel" % [100 * stalled_share]
	)
	_check(
		search_stopped <= MAXIMUM_SEARCH_STOPPED_TICKS,
		"Engineers stood still in work-face searches for %d ticks" % search_stopped
	)
	_check(ghost_mismatches == 0, "Harvest ghosting disagreed with the harvest state")


func _latency(label, units, point):
	var starts = {}
	var goals = {}
	var targets = root.get_node("Utils").Match.Unit.Movement.crowd_moved_to_new_pivot(units, point)
	for pair in targets:
		pair[0].manual_orders.submit(orders.point_order("move", pair[1]), false, false)
		starts[pair[0]] = pair[0].global_position
		goals[pair[0]] = pair[1]
	return await _measure(label, units, starts, func(unit): return goals[unit])


func _regather_latency(units, field):
	# Re-ordering busy engineers to their own field must not stop them to think.
	var starts = {}
	for unit in units:
		unit.manual_orders.submit(orders.target_order("gather", field), false, false)
		starts[unit] = unit.global_position
	var result = await _measure("workers->regather", units, starts, null)
	for unit in units:
		var stage = result.stages[unit]
		var in_contact = (
			stage.dest < 0
			and unit.action != null
			and unit.action.get_script() == harvest
			and unit.action._state == unit.action.State.COLLECTING
		)
		_check(
			in_contact or (stage.dest >= 0 and stage.dest <= 2),
			"A re-ordered engineer waited %d ticks for a destination" % stage.dest
		)


func _measure(label, units, starts, goal):
	var stages = {}
	var latency = {}
	for unit in units:
		stages[unit] = {"dest": -1, "vel": -1, "any": -1}
	for tick in 90:
		await physics_frame
		for unit in units:
			var movement = unit.get_node("Movement")
			var stage = stages[unit]
			if stage.dest < 0 and movement._has_destination:
				stage.dest = tick + 1
			if stage.vel < 0 and movement.velocity.length() > .1:
				stage.vel = tick + 1
			var moved = (unit.global_position - starts[unit]) * Vector3(1, 0, 1)
			if stage.any < 0 and moved.length() > .02:
				stage.any = tick + 1
			if latency.has(unit):
				continue
			if goal != null:
				var toward = (goal.call(unit) - starts[unit]) * Vector3(1, 0, 1)
				if moved.dot(toward.normalized()) > .1:
					latency[unit] = tick + 1
			elif moved.length() > .1:
				latency[unit] = tick + 1
	var values = units.map(func(unit): return latency.get(unit, 999))
	values.sort()
	var result = {"stages": stages, "median": values[values.size() / 2], "max": values[-1]}
	print(
		"LATENCY %s ticks min=%d median=%d max=%d" % [label, values[0], result.median, result.max]
	)
	if OS.get_cmdline_user_args().has("--detail"):
		for unit in units:
			print(
				(
					"  %s dest=%d vel=%d any=%d toward=%d action=%s"
					% [
						unit.type,
						stages[unit].dest,
						stages[unit].vel,
						stages[unit].any,
						latency.get(unit, 999),
						unit.action
					]
				)
			)
	return result
