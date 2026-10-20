extends "res://tests/playtest/reference/PresetRecoveryMatches.gd"


func _sample():
	var row = super()
	row.policy = load("res://tests/playtest/reference/PolicyReadiness.gd").sample(self)
	return row
