extends RefCounted

# Moves a unit on native Guard to the first observed threat it can engage, or
# back to the fallback point. Units under any other behavior are left alone.
const Rules = preload("res://source/match/combat/CombatRules.gd")
const POINT = "guard_response_point"


static func update(unit, threats, fallback, protected = false):
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	if protected or behavior.current(unit) != "guard":
		return false
	var point = fallback
	for threat in threats:
		if (
			Rules.can_target(unit, threat)
			and unit._match.battlefield.is_observed(unit.player, threat)
		):
			point = threat.global_position_yless
			break
	var previous = unit.get_meta(POINT, unit.global_position_yless)
	if previous.distance_to(point) < 2.0 or not behavior.guard(unit, point):
		return false
	unit.set_meta(POINT, point)
	return true
