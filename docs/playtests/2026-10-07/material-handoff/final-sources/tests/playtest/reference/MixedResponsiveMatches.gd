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
	var response = load("res://tests/playtest/reference/GuardResponsePolicy.gd")
	for unit in _policy_army():
		if response.update(
			unit,
			defense.threats,
			defense_point,
			retreating.has(unit.get_instance_id()) or _protected_from_command(unit)
		):
			metrics.guard_reassignments = metrics.get("guard_reassignments", 0) + 1
