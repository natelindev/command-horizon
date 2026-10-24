extends "res://source/match/units/actions/AttackMoving.gd"

## A persistent two-point attack move. The origin is captured when a queued
## patrol actually starts, so earlier waypoints do not change the route.
var origin = Vector3.ZERO
var endpoint = Vector3.ZERO


func _init(point):
	super(point)
	endpoint = point


func _ready():
	if not restoring:
		origin = get_parent().global_position
	super()


func _arrived():
	# Navigation can finish synchronously at an already occupied endpoint. Delay
	# the next leg until the next scan to avoid nested movement-finished signals.
	destination = origin if destination.is_equal_approx(endpoint) else endpoint
	_arrival_elapsed = 0.0
	_arrival_progress = null
	_elapsed = 0.0


func _to_string():
	return "Patrolling"
