extends "res://source/match/units/actions/Action.gd"

var _target_position = null
var _arrival_elapsed = 0.0
var _arrival_progress = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement_trait = _unit.find_child("Movement")


static func is_applicable(unit):
	return unit.find_child("Movement") != null


func _init(target_position):
	_target_position = target_position


func _ready():
	if restoring:
		return
	_movement_trait.move(_target_position)
	_movement_trait.movement_finished.connect(_on_movement_finished)


func _process(delta):
	if occupied_arrival(self, _movement_trait, _unit, delta):
		_movement_trait.stop()
		queue_free()


static func occupied_arrival(action, movement, unit, delta):
	if (
		not movement._synchronized
		or not movement._has_destination
		or unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
	):
		return false
	var point = unit.global_position_yless
	if action._arrival_progress == null:
		action._arrival_progress = point
	action._arrival_elapsed += delta
	if action._arrival_elapsed < 2.0:
		return false
	action._arrival_elapsed = 0.0
	var path = movement.get_current_navigation_path()
	if path.is_empty():
		action._arrival_progress = point
		return false
	var endpoint = path[-1] * Vector3(1, 0, 1)
	# Sideways crowd recovery can travel without approaching the endpoint.
	# Only progress toward that reachable point restarts the arrival wait.
	var progress = action._arrival_progress.distance_to(endpoint) - point.distance_to(endpoint)
	var stalled = progress < 0.2
	action._arrival_progress = point
	return stalled and movement.has_occupied_endpoint()


func _exit_tree():
	if is_inside_tree():
		_movement_trait.stop()


func _on_movement_finished():
	queue_free()
