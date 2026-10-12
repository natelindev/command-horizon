extends RefCounted

const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Production = preload("res://source/match/players/skirmish-ai/SkirmishProduction.gd")


static func builder(workers, point, allow_interrupt = false):
	var candidates = workers.filter(
		func(worker):
			return (
				worker.action == null
				or (
					worker.action is Harvest
					and (
						allow_interrupt or worker.action.needs_assignment() or handoff_ready(worker)
					)
				)
			)
	)
	var counts = {1: 0, 2: 0}
	for worker in workers:
		if worker.action is Harvest and worker.action._kind in counts:
			counts[worker.action._kind] += 1
	var best = null
	var best_score = INF
	for worker in candidates:
		var distance = Utils.Match.Unit.Movement.path_distance_to(worker, point, 4.0)
		if not is_finite(distance):
			continue
		var disruption = 0
		if worker.action is Harvest and not worker.action.needs_assignment():
			# Prefer a delivery-boundary handoff over stopping an outward trip or
			# collection. Never interrupt the only gatherer of a resource first.
			disruption = 1 if handoff_ready(worker) else 2
			if counts.get(worker.action._kind, 0) == 1:
				disruption += 4
		var score = disruption * 1000.0 + distance
		if score < best_score:
			best = worker
			best_score = score
	return best


static func awaiting_construction(worker):
	return (
		worker.manual_orders != null
		and worker.manual_orders.pending.any(func(order): return order.kind == "construct")
	)


static func assign_construction(worker, building):
	if (
		worker.resource_a + worker.resource_b > 0
		and worker.action is Harvest
		and worker.player.has_completed_structure("CommandCenter")
	):
		# Finish delivery before consuming construction time. Replace only a
		# stale queued economic handoff, retaining the active cargo operation.
		worker.manual_orders.clear_waiting()
		worker.manual_orders.submit(worker.manual_orders.target_order("construct", building), true)
	else:
		worker.issue_manual_order(
			load("res://source/match/units/actions/Constructing.gd").new(building)
		)


static func queued_target(worker):
	if worker.manual_orders == null or worker.manual_orders.pending.is_empty():
		return null
	var order = worker.manual_orders.pending[0]
	if order.kind != "gather" or not order.has("target"):
		return null
	var target = order.target.get_ref()
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	return target if "resource_a" in target or "resource_b" in target else null


static func handoff_ready(worker):
	# Queue the next job during the loaded return; the harvest action retires
	# only after delivery. A short near-HQ window can fall between AI ticks.
	return (
		worker.action is Harvest
		and worker.action._kind > 0
		and worker.action._state == Harvest.State.MOVING_TO_CC
		and worker.resource_a + worker.resource_b > 0
	)


static func plan(game, player, units):
	var workers = units.filter(
		func(unit):
			return (
				unit.type == "Worker"
				and (unit.action == null or unit.action is Harvest)
				and (
					unit.manual_orders == null
					or unit.manual_orders.pending.is_empty()
					or queued_target(unit) != null
				)
			)
	)
	var result = {}
	var locked = []
	var electronics = 0
	for worker in workers:
		var next = queued_target(worker)
		var kind = 0
		if next != null:
			kind = 2 if "resource_b" in next else 1
			locked.append(worker)
		elif worker.action is Harvest:
			kind = worker.action._kind
		result[worker] = kind
		electronics += 1 if kind == 2 else 0
	if workers.is_empty():
		return result
	var demand = Production.demand(game, player, units)
	var gap = Vector2i(maxi(0, demand.x - player.resource_a), maxi(0, demand.y - player.resource_b))
	var target = electronics
	if gap != Vector2i.ZERO:
		# Weight deficits by collection time so labor follows economy tuning.
		# Round trips and congestion still limit actual income.
		var material_work = gap.x * Constants.Match.Resources.A.COLLECTING_TIME_S
		var electronics_work = gap.y * Constants.Match.Resources.B.COLLECTING_TIME_S
		target = roundi(
			workers.size() * electronics_work / maxf(1.0, material_work + electronics_work)
		)
		if workers.size() > 1 and demand.x > 0 and demand.y > 0:
			target = clampi(target, 1, workers.size() - 1)
	elif workers.any(func(worker): return result[worker] == 0):
		target = maxi(electronics, floori(workers.size() / 3.0))
	var candidates = workers.filter(func(worker): return worker not in locked)
	candidates.sort_custom(
		func(a, b):
			if (result[a] == 0) != (result[b] == 0):
				return result[a] == 0
			var a_returning = a.action is Harvest and a.action._state == Harvest.State.MOVING_TO_CC
			var b_returning = b.action is Harvest and b.action._state == Harvest.State.MOVING_TO_CC
			if a_returning != b_returning:
				return a_returning
			return a.get_index() < b.get_index()
	)
	for worker in candidates:
		if electronics < target and result[worker] != 2:
			result[worker] = 2
			electronics += 1
		elif electronics > target and result[worker] == 2:
			result[worker] = 1
			electronics -= 1
		elif result[worker] == 0:
			result[worker] = 1
	return result
