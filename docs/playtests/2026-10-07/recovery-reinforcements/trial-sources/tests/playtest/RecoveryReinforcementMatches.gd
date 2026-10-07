extends "res://tests/playtest/SustainedDefenseMatches.gd"

const ResearchPriority = preload("res://tests/playtest/reference/ReinforcementResearchPolicy.gd")
var prioritize_reinforcements = false


func _run():
	prioritize_reinforcements = "--reinforcement-first" in OS.get_cmdline_user_args()
	await super()


func _reference_research():
	return ResearchPriority.select(super(), _policy_army().size(), prioritize_reinforcements)


func _sample():
	var row = super()
	row.reinforcement_first = prioritize_reinforcements
	return row
