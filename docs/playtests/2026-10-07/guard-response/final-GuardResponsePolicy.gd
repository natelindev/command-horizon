extends RefCounted

const Rules = preload("res://source/match/combat/CombatRules.gd")


static func update(unit, threats, fallback, protected = false):
	if protected or unit.program == null or unit.program.mode != "Running":
		return false
	var point = fallback
	for threat in threats:
		if (
			Rules.can_target(unit, threat)
			and unit._match.battlefield.is_observed(unit.player, threat)
		):
			point = threat.global_position_yless
			break
	if unit.program.anchor != null and unit.program.anchor.distance_to(point) < 2.0:
		return false
	unit.program.anchor = point
	return true
