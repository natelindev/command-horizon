extends "res://tests/playtest/CautiousRelayMatches.gd"

var hq_state_key = []


func _play_case(index):
	hq_state_key.clear()
	await super(index)


func _measure():
	super()
	var units = plan_rules.owned_units(human)
	var hqs = units.filter(func(unit): return unit.type == "CommandCenter")
	var complete = hqs.filter(func(unit): return unit.is_constructed())
	var health = complete.map(func(unit): return floori(unit.hp / unit.hp_max * 4))
	var step = plan_rules.next_step(human)
	var funded = human.has_resources(factions.cost(human, "CommandCenter", true))
	var key = [health, hqs.size(), funded, step.id]
	if key == hq_state_key:
		return
	hq_state_key = key.duplicate(true)
	if not metrics.has("hq_recovery_events"):
		metrics.hq_recovery_events = []
	var event = {
		"seconds": game.simulation_time,
		"health": complete.map(func(unit): return unit.hp / unit.hp_max),
		"foundations": hqs.size() - complete.size(),
		"funds": [human.resource_a, human.resource_b],
		"advice": step.id,
		"remaining": game._defeat_timers[human]
	}
	metrics.hq_recovery_events.append(event)
	print("HQ RECOVERY ", JSON.stringify(event))
	if archive_prefix != "":
		if complete.is_empty():
			_archive_progress("hq_lost")
		elif health.any(func(value): return value < 3):
			_archive_progress("hq_damaged")
