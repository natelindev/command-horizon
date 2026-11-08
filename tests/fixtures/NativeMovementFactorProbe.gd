extends "res://tests/fixtures/NativeUnitStateProbe.gd"

var movement_factor := 1.25
var movement_factor_reads := 0


class ProbeMovement:
	extends NavigationAgent3D
	var domain := 1
	var speed: float:
		get:
			return _native_base_speed * get_parent().movement_technology_factor()
	var _native_base_speed := 4.0


func _init():
	super()
	get_node("MovementObstacle").free()
	var movement := ProbeMovement.new()
	movement.name = "Movement"
	add_child(movement)


func movement_technology_factor() -> float:
	movement_factor_reads += 1
	return movement_factor
