extends "res://tests/playtest/reference/ElectronicsHandoffPolicy.gd"

var material_handoffs = []


func restore_materials(game, player, units, protected, demand):
	# Only relieve an actual materials shortfall with funded electronics.
	# The caller supplies its own planned purchases, not the opponent AI's plan.
	if player.resource_a >= demand.x or player.resource_b < demand.y:
		return 0
	var workers = units.filter(func(unit): return unit.type == "Worker" and unit.hp > 0)
	var target = [2, 4].filter(func(index): return index < workers.size()).size()
	var electronics = 0
	for worker in workers:
		var queued = Labor.queued_target(worker)
		if queued != null:
			electronics += 1 if "resource_b" in queued else 0
		elif worker.action is Harvest and not worker.action.needs_assignment():
			electronics += 1 if worker.action._kind == 2 else 0
	var observed = Economy.contacts(game, player)
	var issued = 0
	for worker in workers:
		if electronics <= target:
			break
		if (
			worker in protected
			or not worker.manual_orders.pending.is_empty()
			or not Labor.handoff_ready(worker)
			or worker.action._kind != 2
		):
			continue
		var hq = Economy.headquarters(units, worker.position)
		if hq == null:
			continue
		var deposit = Economy.deposit(game, worker, hq, 1, observed)
		if deposit == null or not routes._safe_route(worker, deposit, observed):
			continue
		if (
			deposit.position.distance_to(hq.position) > Economy.HOME_RADIUS
			and not Economy.guarded(units, deposit.position)
		):
			continue
		if worker.manual_orders.submit(Orders.target_order("gather", deposit), true):
			electronics -= 1
			issued += 1
			material_handoffs.append(
				{
					"seconds": game.simulation_time,
					"cargo": [worker.resource_a, worker.resource_b],
					"funds": [player.resource_a, player.resource_b],
					"demand": [demand.x, demand.y],
					"from": [worker.position.x, worker.position.z],
					"target": [deposit.position.x, deposit.position.z],
					"electronics_after": electronics,
					"electronics_floor": target
				}
			)
	return issued
