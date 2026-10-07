extends RefCounted

const Labor = preload("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Orders = preload("res://source/match/orders/ManualOrders.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const SafeRoutes = preload("res://tests/playtest/reference/EngineerReassignmentPolicy.gd")
var routes = SafeRoutes.new()
var handoffs = []


func update(game, player, units, protected):
	var workers = units.filter(func(unit): return unit.type == "Worker" and unit.hp > 0)
	var target = mini(2, maxi(0, workers.size() - 1))
	var electronics = 0
	for worker in workers:
		var queued = Labor.queued_target(worker)
		if queued != null:
			electronics += 1 if "resource_b" in queued else 0
		elif worker.action is Harvest and not worker.action.needs_assignment():
			electronics += 1 if worker.action._kind == 2 else 0
	if electronics >= target:
		return 0
	var observed = Economy.contacts(game, player)
	var issued = 0
	for worker in workers:
		if electronics >= target:
			break
		if (
			worker in protected
			or not worker.manual_orders.pending.is_empty()
			or not Labor.handoff_ready(worker)
			or worker.action._kind != 1
		):
			continue
		var hq = Economy.headquarters(units, worker.position)
		if hq == null:
			continue
		var deposit = Economy.deposit(game, worker, hq, 2, observed)
		if deposit == null or not routes._safe_route(worker, deposit, observed):
			continue
		if (
			deposit.position.distance_to(hq.position) > Economy.HOME_RADIUS
			and not Economy.guarded(units, deposit.position)
		):
			continue
		if worker.manual_orders.submit(Orders.target_order("gather", deposit), true):
			electronics += 1
			issued += 1
			handoffs.append(
				{
					"seconds": game.simulation_time,
					"cargo": [worker.resource_a, worker.resource_b],
					"from": [worker.position.x, worker.position.z],
					"target": [deposit.position.x, deposit.position.z]
				}
			)
	return issued
