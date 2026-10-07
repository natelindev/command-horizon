extends "res://tests/playtest/CautiousRelayMatches.gd"

var prioritize_reinforcements = true


func _reinforcement_priority():
	return prioritize_reinforcements
