extends RefCounted

const Rules = preload("res://source/match/combat/CombatRules.gd")
const Advance = preload("res://source/match/units/actions/AttackMoving.gd")
const Recover = preload("res://source/match/units/actions/RecoveringAtService.gd")
var decisions = 0
var _last = {}


func command(unit, contacts, now):
	if is_instance_of(unit.action, Recover):
		return false
	var targets = contacts.filter(
		func(target):
			return (
				is_instance_valid(target)
				and not target.is_queued_for_deletion()
				and target.hp > 0
				and target.attack_range != null
				and unit._match.battlefield.is_observed(unit.player, target)
				and Rules.can_target(unit, target)
			)
	)
	if targets.is_empty():
		return false
	# Conventional troops require an explicit commander response to a contact
	# outside weapon range. Keep a firing action intact once it can contribute.
	if (
		is_instance_valid(unit.action)
		and (unit.action.has_method("is_idle") or is_instance_of(unit.action, Advance))
		and not unit._match.battlefield.fireable_targets(unit).is_empty()
	):
		return true
	var id = unit.get_instance_id()
	if now - _last.get(id, -100.0) < 2.0:
		return true
	targets.sort_custom(
		func(a, b):
			return (
				unit.global_position_yless.distance_squared_to(a.global_position_yless)
				< unit.global_position_yless.distance_squared_to(b.global_position_yless)
			)
	)
	var point = targets[0].global_position_yless
	if is_instance_of(unit.action, Advance) and unit.action.destination.distance_to(point) < 2.0:
		return true
	unit.issue_manual_order(Advance.new(point))
	_last[id] = now
	decisions += 1
	return true
