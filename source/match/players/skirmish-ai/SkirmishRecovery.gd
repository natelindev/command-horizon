extends RefCounted

const Recover = preload("res://source/match/units/actions/RecoveringAtService.gd")
const Repairs = preload("res://source/match/combat/RepairService.gd")
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const RETREAT_HEALTH = 0.3


static func command(game, units, observed, retreat_health = RETREAT_HEALTH):
	var recovering = []
	for unit in units:
		if unit.movement_speed <= 0 or unit.type == "Worker" or unit.hp <= 0:
			continue
		var current = unit.action if unit.action is Recover else null
		if current == null and unit.hp >= unit.hp_max * retreat_health:
			continue
		if current != null and unit.hp >= unit.hp_max * Recover.RETURN_HEALTH:
			unit.issue_manual_order(null)
			continue
		if current != null and not current._blocked and _safe(current._target, unit, observed):
			recovering.append(unit)
			continue
		var options = (units + Sites.repair_sites(unit.player)).filter(
			func(service):
				return (
					_safe(service, unit, observed)
					and (
						current == null
						or not current._blocked
						or current._retry_left <= 0
						or service != current._target
					)
				)
		)
		options.sort_custom(
			func(a, b):
				return (
					Utils.Match.Unit.Movement.path_distance_to(
						unit, a.global_position, Recover.ARRIVAL_RANGE
					)
					< Utils.Match.Unit.Movement.path_distance_to(
						unit, b.global_position, Recover.ARRIVAL_RANGE
					)
				)
		)
		var target = null
		for service in options:
			if _reachable(game, unit, service):
				target = service
				break
		if target != null:
			unit.issue_manual_order(Recover.new(target))
			recovering.append(unit)
		elif current != null:
			# Keep the recovery threshold after service loss. A new safe facility
			# can resume it; ordinary waves must not pull the wounded unit away.
			current.block()
			recovering.append(unit)
	return recovering


static func _safe(service, unit, observed):
	return (
		Repairs.facility_eligible(service, unit)
		and not Economy.danger(service.global_position_yless, unit, observed)
	)


static func _reachable(_game, unit, service):
	return is_finite(
		Utils.Match.Unit.Movement.path_distance_to(
			unit, service.global_position, Recover.ARRIVAL_RANGE
		)
	)
