extends "res://source/match/units/Unit.gd"

var resource_a = 0:
	set(value):
		resource_a = value
		_refresh_cargo()
var resource_b = 0:
	set(value):
		resource_b = value
		_refresh_cargo()
var resources_max = null
var _cargo = null


func _ready():
	await super()
	_cargo = load("res://source/match/units/traits/WorkerCargo.gd").new(self)
	get_node("Geometry").add_child(_cargo)


func _refresh_cargo():
	if is_instance_valid(_cargo) and _cargo.is_node_ready():
		_cargo.refresh()


func is_full():
	assert(resource_a + resource_b <= resources_max, "worker capacity was exceeded somehow")
	return resource_a + resource_b == resources_max
