extends RefCounted

const Recovery = preload("res://source/match/players/skirmish-ai/SkirmishRecovery.gd")
const Economy = preload("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
const Recover = preload("res://source/match/units/actions/RecoveringAtService.gd")
var active = {}
var episodes = []


func update(game, player, units, regrouping):
	var observed = Economy.contacts(game, player)
	var candidates = units.filter(
		func(unit): return _eligible(unit) or unit.has_method("is_constructed")
	)
	# Each policy chooses its patients and entry threshold. Existing service
	# owns the normal 80% exit for both infantry and conventional armor.
	for unit in candidates:
		if (
			not _eligible(unit)
			or unit.action is Recover
			or unit.hp >= unit.hp_max * _threshold(regrouping)
		):
			continue
		var services = candidates.filter(
			func(service): return Recovery._safe(service, unit, observed)
		)
		services.sort_custom(
			func(a, b):
				return unit.position.distance_to(a.position) < unit.position.distance_to(b.position)
		)
		for service in services:
			if Recovery._reachable(game, unit, service):
				unit.issue_manual_order(Recover.new(service))
				break
	var held = Recovery.command(game, candidates, observed)
	for id in active.keys():
		var entry = active[id]
		var unit = entry.unit.get_ref()
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0:
			entry.record.result = "lost"
		elif unit in held:
			continue
		else:
			entry.record.result = (
				"ready" if unit.hp >= unit.hp_max * Recover.RETURN_HEALTH else "interrupted"
			)
			entry.record.end_health = unit.hp / unit.hp_max
		entry.record.end = game.simulation_time
		active.erase(id)
	for unit in held:
		var id = unit.get_instance_id()
		if not active.has(id):
			var record = {
				"role": unit.type,
				"start": game.simulation_time,
				"health": unit.hp / unit.hp_max,
				"result": "recovering"
			}
			episodes.append(record)
			active[id] = {"unit": weakref(unit), "record": record}
	return held


func _eligible(unit):
	return unit.type == "Infantry"


func _threshold(regrouping):
	return Recover.RETURN_HEALTH if regrouping else .4
