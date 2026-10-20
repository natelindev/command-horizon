extends "res://source/match/units/actions/Action.gd"

# Fly to a point and hold it in a banked orbit (combat air patrol). A plain move
# keeps weapons safe until arrival; a sweep (attack-move) engages en route.
# Escorting follows a friendly unit's position instead of a fixed point.

var sweep = false
var _point = Vector3.ZERO
var _escort = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _flight = _unit.get_node("Movement")


func _init(point, engage_en_route = false, escort = null):
	_point = point
	sweep = engage_en_route
	_escort = escort


func _ready():
	if restoring:
		return
	_flight.fly_station(_escort.global_position if _valid_escort() else _point)


func weapons_free():
	return sweep or _flight.arrived() or _valid_escort()


func _physics_process(_delta):
	if _escort != null:
		if not _valid_escort():
			queue_free()
			return
		# Escort station moves with the protected unit; the order never completes.
		_flight.station = _flight._clamp_to_map(_escort.global_position)
		return
	if _flight.arrived():
		queue_free()


func _valid_escort():
	return is_instance_valid(_escort) and not _escort.is_queued_for_deletion()
