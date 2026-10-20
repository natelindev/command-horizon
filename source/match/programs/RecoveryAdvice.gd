extends RefCounted

const Repairs = preload("res://source/match/combat/RepairService.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")


static func support_near(unit):
	for source in unit.player.get_children():
		if not source.is_in_group("units") or source.is_queued_for_deletion() or source.hp <= 0:
			continue
		if Repairs.facility_eligible(source, unit):
			if (
				unit.global_position_yless.distance_to(source.global_position_yless)
				<= Repairs.FACILITY_RANGE
			):
				return true
		elif source.type == "RepairRobot" and Repairs.mobile_eligible(source, unit):
			if (
				Repairs.mobile_distance(source, unit) <= 3.0
				and Repairs.stationary(source)
				and (
					source.action == null
					or (
						source.action.has_method("repair_target")
						and source.action.repair_target() == unit
					)
				)
			):
				return true
	return false


static func waiting(unit):
	if support_near(unit):
		return "Recovery support nearby; waiting for healing."
	var facility = Factions.title(unit.player.faction, Repairs.facility_for_role(unit.type))
	var text = "No recovery support here. Set the safe point at a %s" % facility
	if not Factions.Bastion.is_aircraft(unit.type) and not Factions.Bastion.is_infantry(unit.type):
		text += (
			" or bring another repair robot"
			if unit.type == "RepairRobot"
			else " or bring a repair robot"
		)
	return text + "."


static func setup(unit, units):
	var facility = Factions.title(unit.player.faction, Repairs.facility_for_role(unit.type))
	if units.any(func(source): return Repairs.facility_eligible(source, unit)):
		return "Set the safe point on your %s for retreat healing." % facility
	if units.any(
		func(source): return source.type == "RepairRobot" and Repairs.mobile_eligible(source, unit)
	):
		return "Station a repair robot at the safe point for retreat healing."
	return "A safe point alone does not heal. Add %s support for recovery." % facility
