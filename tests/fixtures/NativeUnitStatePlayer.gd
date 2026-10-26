extends "res://source/match/players/Player.gd"

var allow_alliance := true


func is_allied_with(other):
	return other == self or allow_alliance
