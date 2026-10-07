extends "res://tests/playtest/reference/MixedAllocationMatches.gd"


func _command():
	super()
	if phase == "attack":
		return
	var units = plan_rules.owned_units(human)
	var observed = get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != human
				and not unit.is_queued_for_deletion()
				and unit.hp > 0
				and game.battlefield.is_observed(human, unit)
			)
	)
	var defense = load("res://source/match/players/skirmish-ai/SkirmishDefense.gd").plan(
		game, human, units, observed
	)
	var point = defense_point
	if not defense.threats.is_empty():
		point = defense.threats[0].global_position_yless
	for unit in _policy_army():
		if (
			unit.program == null
			or unit.program.mode != "Running"
			or retreating.has(unit.get_instance_id())
		):
			continue
		if unit.program.anchor != null and unit.program.anchor.distance_to(point) < 2:
			continue
		unit.program.anchor = point
		metrics.guard_reassignments = metrics.get("guard_reassignments", 0) + 1
