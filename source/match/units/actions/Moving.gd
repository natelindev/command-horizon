extends "res://source/match/units/actions/Action.gd"

const Shooting = preload("res://source/match/units/actions/AttackingWhileInRange.gd")
var _shot = null
var _scan_left = 0.0
var _target_position = null
var _arrival_elapsed = 0.0
var _arrival_progress = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement_trait = _unit.find_child("Movement")


static func is_applicable(unit):
	return unit.get_node_or_null("Movement") != null


func _init(target_position):
	_target_position = target_position


func _ready():
	if restoring:
		return
	_movement_trait.move(travel_target(_unit, _target_position))
	_movement_trait.movement_finished.connect(_on_movement_finished)


func _physics_process(delta):
	if not Shooting.can_fire_on_move(_unit) or _unit.attack_range == null:
		return
	_scan_left -= delta
	if _scan_left > 0 or (is_instance_valid(_shot) and not _shot.is_queued_for_deletion()):
		return
	_scan_left = .1
	var target = _unit._match.battlefield.automatic_target(_unit)
	if target != null:
		_shot = Shooting.new(target)
		add_child(_shot)


func _process(delta):
	if advance_nearby_funnel(_unit, _target_position):
		_movement_trait.move(travel_target(_unit, _target_position))
	if occupied_arrival(self, _movement_trait, _unit, delta):
		_movement_trait.stop()
		_on_movement_finished()


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
	action._arrival_elapsed = minf(2.0, action._arrival_elapsed + delta)
	if action._arrival_elapsed < 2.0:
		return false
	var path = movement.get_current_navigation_path()
	if path.is_empty():
		# A restored navigation path may still be rebuilding. Its absence is
		# evidence of neither arrival nor new progress; retain the saved observation.
		return false
	var endpoint = path[-1] * Vector3(1, 0, 1)
	# Sideways crowd recovery can travel without approaching the endpoint.
	# Only progress toward that reachable point restarts the arrival wait.
	var progress = action._arrival_progress.distance_to(endpoint) - point.distance_to(endpoint)
	if progress >= 0.2:
		action._arrival_elapsed = 0.0
		action._arrival_progress = point
		return false
	# Once stalled, keep checking the existing arrival bounds. An outward
	# crowd displacement must neither start a new wait nor become fresh
	# approach progress when the unit returns to its previous position.
	return movement.has_occupied_endpoint()


func _exit_tree():
	if is_inside_tree():
		_movement_trait.stop()


static func travel_target(unit, destination: Vector3) -> Vector3:
	var route = (
		unit.manual_orders.current.get("waypoints", []) if unit.manual_orders != null else []
	)
	return route[0] if not route.is_empty() else destination


static func advance_nearby_funnel(unit, destination: Vector3) -> bool:
	if unit.manual_orders == null:
		return false
	var route = unit.manual_orders.current.get("waypoints", [])
	var advanced = false
	while not route.is_empty():
		var gate = route[0]
		var next = route[1] if route.size() > 1 else destination
		var forward = ((next - gate) * Vector3(1, 0, 1)).normalized()
		var offset = (unit.global_position - gate) * Vector3(1, 0, 1)
		# A portal is a plane to cross, never a shared parking point. Advance
		# before stopping so the lead vehicle cannot pin the following column.
		if offset.dot(forward) < -maxf(.3, unit.radius) and offset.length() > unit.radius + .35:
			break
		route.pop_front()
		advanced = true
	return advanced


static func advance_funnel(unit) -> bool:
	if unit.manual_orders == null:
		return false
	var route = unit.manual_orders.current.get("waypoints", [])
	if route.is_empty():
		return false
	route.pop_front()
	return true


func _on_movement_finished():
	if advance_funnel(_unit):
		_arrival_elapsed = 0.0
		_arrival_progress = null
		_movement_trait.move(travel_target(_unit, _target_position))
	else:
		queue_free()
