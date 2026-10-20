extends "res://source/match/units/actions/Action.gd"

# Fly back, land, taxi to a stand and rearm. Completes once parked.

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _flight = _unit.get_node("Movement")


func _ready():
	if restoring:
		return
	_flight.return_to_base()


func weapons_free():
	return true


func _physics_process(_delta):
	if _flight.is_parked():
		queue_free()
