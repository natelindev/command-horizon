extends "res://tests/playtest/CautiousRelayMatches.gd"

var prioritize_reinforcements = true


func _reference_research():
	var candidate = super()
	# Keep the hardware unlock; defer optional upgrades until this commander
	# has enough ground combatants for its existing nine-unit assault gate.
	if (
		prioritize_reinforcements
		and candidate.get("id", "coordination") != "coordination"
		and _policy_army().size() < 9
	):
		return {}
	return candidate
