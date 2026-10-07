extends RefCounted

const Economy = preload("res://source/match/EconomyAdvice.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")
const Assignments = preload("res://source/match/EconomyAssignments.gd")


static func next_step(player, units):
	var budget = Vector2i.ZERO
	for producer in units:
		if (
			producer.type not in ["VehicleFactory", "AircraftFactory"]
			or not producer.is_constructed()
		):
			continue
		var product = "Tank" if producer.type == "VehicleFactory" else "Helicopter"
		var cost = Factions.cost(player, product).duplicate()
		if product == "Tank" and producer.production_queue.fit_chips:
			cost.resource_b += Factions.chip_cost(player.faction)
		budget.x = maxi(budget.x, cost.resource_a)
		budget.y = maxi(budget.y, cost.resource_b)
	if budget == Vector2i.ZERO:
		return {}
	var workers = Economy.role(units, "Worker")
	var materials = Assignments.workers(workers, 1)
	var electronics = Assignments.workers(workers, 2)
	var kind = 0
	if materials.is_empty() and player.resource_a < budget.x and not electronics.is_empty():
		kind = 1
	elif electronics.is_empty() and player.resource_b < budget.y and not materials.is_empty():
		kind = 2
	if kind == 0:
		return {}
	var candidates = workers.filter(
		func(worker):
			return (
				(worker.action == null or _gathering(worker, 3 - kind))
				and (worker.manual_orders == null or worker.manual_orders.pending.is_empty())
			)
	)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(
		func(a, b):
			if (a.action == null) != (b.action == null):
				return a.action == null
			return a.resource_a + a.resource_b < b.resource_a + b.resource_b
	)
	var resource = "materials" if kind == 1 else "electronics"
	return Economy.step(
		"supply_" + resource,
		"Restore " + resource + " income",
		(
			(
				"No engineers are gathering %s, and reserves are low for your factories. "
				+ "Right-click a protected %s deposit with this engineer. "
				+ "Scout and defend any new field before sending gatherers."
			)
			% [resource, resource]
		),
		"Select engineer",
		[candidates[0]]
	)


static func _gathering(worker, kind):
	return (
		worker.action is Harvest
		and worker.action._kind == kind
		and not worker.action.needs_assignment()
	)
