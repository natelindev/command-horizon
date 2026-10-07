extends "res://tests/headless/SkirmishTravelProbe.gd"


# Continue the matrix at seed 4110, where the pre-fix placement trapped an engineer.
func _play_case(index):
	var original_repetition = repetition
	repetition += 10
	await super(index)
	repetition = original_repetition
