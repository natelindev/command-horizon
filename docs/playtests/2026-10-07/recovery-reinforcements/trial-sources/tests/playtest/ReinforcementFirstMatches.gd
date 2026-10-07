extends "res://tests/playtest/CautiousRelayMatches.gd"

const ResearchPriority = preload("res://tests/playtest/reference/ReinforcementResearchPolicy.gd")
var prioritize_reinforcements = true


func _reference_research():
	return ResearchPriority.select(super(), _policy_army().size(), prioritize_reinforcements)
