extends "res://tests/fixtures/NativeUnitStateProbe.gd"

var sight_factor := 1.0
var force_plateau := false


func terrain_advantage() -> bool:
	return force_plateau


func effective_sight_range(point = null):
	return super.effective_sight_range(point) * sight_factor
