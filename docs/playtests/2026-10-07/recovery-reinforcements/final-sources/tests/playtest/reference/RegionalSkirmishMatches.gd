extends "res://tests/playtest/reference/MixedResponsiveMatches.gd"


func _map_id(index):
	return ["IndustrialCrossroads", "CoastalFoundry"][(index / 2) % 2]
