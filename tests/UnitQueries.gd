extends RefCounted

# Read-only roster queries shared by regressions and playtest commanders.


static func owned_units(player):
	return player.get_children().filter(
		func(unit): return unit.is_in_group("units") and not unit.is_queued_for_deletion()
	)


static func idle_workers(player):
	return owned_units(player).filter(
		func(unit):
			return (
				unit.type == "Worker"
				and (unit.manual_orders == null or unit.manual_orders.pending.is_empty())
				and (
					unit.action == null
					or (
						unit.action.has_method("needs_assignment")
						and unit.action.needs_assignment()
					)
				)
			)
	)


static func army(player):
	return owned_units(player).filter(
		func(unit): return unit.movement_speed > 0 and unit.attack_range != null
	)
