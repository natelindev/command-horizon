extends "res://tests/playtest/SustainedDefenseMatches.gd"

var prioritize_reinforcements = false


func _run():
	prioritize_reinforcements = "--reinforcement-first" in OS.get_cmdline_user_args()
	await super()


func _reinforcement_priority():
	return prioritize_reinforcements


func _sample():
	var row = super()
	row.reinforcement_first = prioritize_reinforcements
	return row
