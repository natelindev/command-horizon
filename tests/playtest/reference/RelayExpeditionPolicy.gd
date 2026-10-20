extends RefCounted

const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Defense = preload("res://source/match/players/skirmish-ai/SkirmishDefense.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
var relay = null
var members = []
var started = 0.0
var retry_at = 0.0
var episodes = []
var _record = {}


func update(game, player, units, phase, unavailable, home):
	if game.get_tree().paused:
		return _living_members()
	var contacts = Economy.contacts(game, player)
	var danger = not Defense.plan(game, player, units, contacts).threats.is_empty()
	var held = _living_members()
	if relay != null:
		var objective = relay.get_ref()
		var reason = ""
		if not is_instance_valid(objective):
			reason = "removed"
		elif objective.captured_by == player:
			reason = "captured"
		elif phase != "defend" or danger:
			reason = "home_priority"
		elif held.is_empty():
			reason = "lost"
		elif held.any(func(unit): return unit in unavailable or unit.hp < unit.hp_max * .4):
			reason = "recovery"
		elif _mission_risk(objective, held, contacts):
			reason = "opposition"
		elif game.simulation_time - started >= 60:
			reason = "timeout"
		if reason != "":
			_finish(game, held, unavailable, home, reason)
			held = []
		return held
	if phase != "defend" or danger or game.simulation_time < retry_at:
		return []
	var infantry = units.filter(
		func(unit):
			return (
				unit.type == "Infantry" and unit.hp >= unit.hp_max * .8 and unit not in unavailable
			)
	)
	# Keep at least one healthy conventional infantry at home. Expeditions do
	# not count toward the reference commander's main assault readiness.
	var count = mini(2, infantry.size() - 1)
	if count <= 0 or not "relays" in game.map:
		return []
	var objectives = game.map.relays.filter(func(item): return item.captured_by != player)
	objectives.sort_custom(
		func(a, b): return a.position.distance_to(home) < b.position.distance_to(home)
	)
	for objective in objectives:
		var opposition = contacts.filter(
			func(unit):
				return (
					unit.attack_range != null and unit.position.distance_to(objective.position) < 9
				)
		)
		if opposition.size() > count:
			continue
		infantry.sort_custom(
			func(a, b):
				return (
					a.position.distance_to(objective.position)
					< b.position.distance_to(objective.position)
				)
		)
		held = _choose_members(infantry, count, home, objective, contacts)
		if held.is_empty():
			continue
		for unit in held:
			unit.issue_manual_order(AttackMove.new(objective.position))
		members = held.map(func(unit): return weakref(unit))
		relay = weakref(objective)
		started = game.simulation_time
		_record = {
			"relay": str(objective.name),
			"start": started,
			"infantry": held.size(),
			"result": "travelling"
		}
		episodes.append(_record)
		return held
	return []


func _choose_members(infantry, count, _home, _objective, _contacts):
	return infantry.slice(0, count)


func _mission_risk(_objective, _held, _contacts):
	return false


func _living_members():
	var result = []
	for reference in members:
		var unit = reference.get_ref()
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0:
			result.append(unit)
	return result


func _finish(game, held, unavailable, home, reason):
	_record.result = reason
	_record.end = game.simulation_time
	_record.survivors = held.size()
	for unit in held:
		if unit not in unavailable:
			unit.issue_manual_order(AttackMove.new(home))
	members.clear()
	relay = null
	retry_at = game.simulation_time + (5 if reason == "captured" else 30)
