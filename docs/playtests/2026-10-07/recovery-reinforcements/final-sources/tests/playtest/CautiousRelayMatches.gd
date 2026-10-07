extends "res://tests/playtest/RelayContestMatches.gd"

const ResearchPriority = preload("res://tests/playtest/reference/ReinforcementResearchPolicy.gd")


func _new_expedition():
	return load("res://tests/playtest/reference/CautiousRelayPolicy.gd").new()


func _command():
	super()
	metrics.relay_withdrawals = expedition.withdrawals


func _reinforcement_priority():
	return true


func _reference_research():
	return ResearchPriority.select(super(), _policy_army().size(), _reinforcement_priority())
