extends RefCounted

const Harvest = preload("res://source/match/units/actions/CollectingResourcesSequentially.gd")


static func workers(units, kind):
	return units.filter(
		func(unit):
			return (
				unit.is_in_group("units")
				and not unit.is_queued_for_deletion()
				and unit.type == "Worker"
				and unit.hp > 0
				and channel(unit) == kind
			)
	)


static func channel(worker):
	# Count each engineer once. A queued next job supersedes continuing the
	# current field, while the harvest action still delivers its existing cargo.
	if worker.manual_orders != null and not worker.manual_orders.pending.is_empty():
		var order = worker.manual_orders.pending[0]
		if order.kind != "gather" or not order.has("target"):
			return 0
		var target = order.target.get_ref()
		if (
			not is_instance_valid(target)
			or target.is_queued_for_deletion()
			or not target.is_in_group("resource_units")
			or not target.can_harvest(worker)
		):
			return 0
		return 1 if "resource_a" in target else 2
	if worker.action is Harvest and not worker.action.needs_assignment():
		return worker.action._kind
	return 0
