extends "res://tests/playtest/reference/RelayExpeditionPolicy.gd"

const Rules = preload("res://source/match/combat/CombatRules.gd")
const Move = preload("res://source/match/units/actions/Moving.gd")
var quiet_until = 0.0
var withdrawals = []
var _returning = []


func update(game, player, units, phase, unavailable, home):
	if game.get_tree().paused:
		return _living_members() + _returning_units()
	_update_returns(game, unavailable, home)
	var returning = _returning_units()
	var contacts = Economy.contacts(game, player)
	var headquarters = units.filter(func(unit): return unit.type == "CommandCenter")
	var approaching = contacts.any(
		func(contact):
			return headquarters.any(
				func(hq):
					return (
						Rules.can_target(contact, hq)
						and contact.position.distance_to(hq.position) < 30
					)
			)
	)
	if approaching or not Defense.plan(game, player, units, contacts).threats.is_empty():
		quiet_until = game.simulation_time + 20
	if phase == "defend" and (headquarters.is_empty() or game.simulation_time < quiet_until):
		phase = "recover"
	var held = super(game, player, units, phase, unavailable + returning, home)
	return held + _returning_units()


func _choose_members(infantry, count, home, objective, contacts):
	# The base policy sorts by distance to this objective. Count the remaining
	# healthy conventional infantry at home, not troops still returning from a relay.
	for size in range(count, 0, -1):
		var held = infantry.slice(0, size)
		var reserve = infantry.slice(size).filter(
			func(unit): return unit.position.distance_to(home) <= 18
		)
		if reserve.size() >= 2 and not _mission_risk(objective, held, contacts):
			return held
	return []


func _mission_risk(objective, held, contacts):
	if held.is_empty():
		return true
	var opposition = contacts.filter(
		func(contact):
			return (
				held.any(func(unit): return Rules.can_target(contact, unit))
				and (
					contact.position.distance_to(objective.position) <= 12
					or held.any(
						func(unit): return contact.position.distance_to(unit.position) <= 12
					)
				)
			)
	)
	# An infantry scouting mission does not engage observed armor, aircraft or
	# emplacements, or an equal/larger infantry group. This is a conservative
	# commitment rule, not a general combined-arms strength estimator.
	return (
		opposition.size() >= held.size()
		or opposition.any(func(unit): return unit.type != "Infantry")
	)


func _finish(game, held, unavailable, home, reason):
	super(game, held, unavailable, home, reason)
	if reason == "opposition":
		for unit in held:
			if unit not in unavailable:
				unit.issue_manual_order(Move.new(home))
				var record = {"start": game.simulation_time, "result": "returning"}
				withdrawals.append(record)
				_returning.append({"unit": weakref(unit), "record": record, "order": unit.action})


func _returning_units():
	var result = []
	for item in _returning:
		var unit = item.unit.get_ref()
		if is_instance_valid(unit) and unit.hp > 0 and not unit.is_queued_for_deletion():
			result.append(unit)
	return result


func _update_returns(game, unavailable, home):
	for item in _returning.duplicate():
		var unit = item.unit.get_ref()
		var reason = ""
		if not is_instance_valid(unit) or unit.hp <= 0 or unit.is_queued_for_deletion():
			reason = "lost"
		elif unit in unavailable:
			reason = "recovery"
		elif unit.position.distance_to(home) <= 6:
			reason = "home"
		elif unit.action != item.order:
			reason = "replaced"
		elif game.simulation_time - item.record.start >= 60:
			reason = "timeout"
		if reason != "":
			item.record.result = reason
			item.record.end = game.simulation_time
			_returning.erase(item)
