extends RefCounted

var economy
var orders
var harvest
var construct
var states = {}
var episodes = []
var threatened_decisions = 0
var no_safe_destination_decisions = 0


func _init():
	economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct = load("res://source/match/units/actions/Constructing.gd")


func protected(worker):
	return states.has(worker.get_instance_id())


func update(game, player, units):
	var observed = economy.contacts(game, player)
	for id in states.keys():
		var state = states[id]
		var worker = state.worker.get_ref()
		if not is_instance_valid(worker) or worker.is_queued_for_deletion() or worker.hp <= 0:
			state.record.result = "lost"
			state.record.end = game.simulation_time
			states.erase(id)
	var workers = units.filter(func(unit): return unit.type == "Worker")
	for worker in workers:
		var threatened = economy.danger(worker.global_position_yless, worker, observed)
		if threatened:
			threatened_decisions += 1
		var id = worker.get_instance_id()
		if threatened and not states.has(id):
			var safe = _safe_point(worker, units, observed)
			if not safe.is_finite():
				no_safe_destination_decisions += 1
				continue
			var target = null
			var kind = ""
			if is_instance_of(worker.action, harvest):
				target = worker.action.get_resource_unit()
				kind = "gather"
			elif is_instance_of(worker.action, construct):
				target = worker.action._target_unit
				kind = "construct"
			var record = {
				"start": game.simulation_time,
				"hp": worker.hp,
				"cargo": [worker.resource_a, worker.resource_b],
				"position": [worker.position.x, worker.position.z],
				"safe": [safe.x, safe.z],
				"task": kind,
				"result": "withdrawing",
				"retargets": 0
			}
			episodes.append(record)
			states[id] = {
				"worker": weakref(worker),
				"target": weakref(target) if is_instance_valid(target) else null,
				"kind": kind,
				"safe": safe,
				"unsafe_at": game.simulation_time,
				"record": record,
				"delivering": false
			}
			worker.manual_orders.submit(orders.point_order("move", safe))
		if not states.has(id):
			continue
		var state = states[id]
		if threatened:
			state.unsafe_at = game.simulation_time
		if economy.danger(state.safe, worker, observed):
			var safe = _safe_point(worker, units, observed)
			if safe.is_finite() and safe.distance_to(state.safe) > 1:
				state.safe = safe
				state.delivering = false
				state.record.retargets += 1
				worker.manual_orders.submit(orders.point_order("move", safe))
		if threatened or game.simulation_time - state.unsafe_at < 6:
			continue
		if not state.delivering and worker.position.distance_to(state.safe) > 2:
			continue
		var hq = economy.headquarters(units, worker.position)
		if hq == null or economy.danger(hq.position, worker, observed):
			continue
		if worker.resource_a + worker.resource_b > 0:
			if not state.delivering:
				worker.manual_orders.submit(orders.target_order("gather", hq))
				state.delivering = true
				state.record.result = "delivering"
			continue
		if state.delivering:
			state.record.delivered = true
		var work = _resume_target(game, worker, state, hq, observed)
		if not work.ready:
			continue
		var target = work.target
		if is_instance_valid(target):
			worker.manual_orders.submit(orders.target_order(work.kind, target))
		else:
			worker.issue_manual_order(null)
		state.record.result = "resumed" if is_instance_valid(target) else "available"
		state.record.end = game.simulation_time
		state.record.end_hp = worker.hp
		states.erase(id)


func _resume_target(_game, worker, state, hq, observed):
	var target = state.target.get_ref() if state.target != null else null
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		if state.kind == "gather":
			if not target.can_harvest(worker):
				target = null
			elif not economy.safe_approach(target, worker, hq, observed):
				return {"ready": false}
		elif state.kind == "construct":
			if target.is_constructed():
				target = null
			elif economy.danger(target.position, worker, observed):
				return {"ready": false}
	return {"ready": true, "target": target, "kind": state.kind}


func _destination_available(_worker, _point, _units):
	return true


func _safe_point(worker, units, observed):
	var hqs = units.filter(
		func(unit): return unit.type == "CommandCenter" and unit.is_constructed()
	)
	var movement = worker.get_node("Movement")
	if not movement._synchronized:
		return Vector3.INF
	var nav = movement.get_navigation_map()
	var best = Vector3.INF
	var best_distance = INF
	for hq in hqs:
		if economy.danger(hq.position, worker, observed):
			continue
		var radius = hq.radius + worker.radius + 2.0
		for index in 16:
			var point = (
				hq.position + Vector3(cos(index * TAU / 16), 0, sin(index * TAU / 16)) * radius
			)
			var ground = NavigationServer3D.map_get_closest_point(nav, point) * Vector3(1, 0, 1)
			if (
				ground.distance_to(point) > .3
				or economy.danger(ground, worker, observed)
				or not _destination_available(worker, ground, units)
			):
				continue
			var path = NavigationServer3D.map_get_path(nav, worker.position, ground, true)
			if path.is_empty() or (path[-1] * Vector3(1, 0, 1)).distance_to(ground) > .2:
				continue
			var distance = 0.0
			for step in range(1, path.size()):
				distance += path[step - 1].distance_to(path[step])
			if distance < best_distance:
				best = ground
				best_distance = distance
	return best
