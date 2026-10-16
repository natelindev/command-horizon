extends RefCounted

# Keeps the save shape uniform for objectives that have no capturable relay.
var captured_by = null
var candidate = null
var progress = 0.0
var contested = false


func _update_presentation():
	pass
