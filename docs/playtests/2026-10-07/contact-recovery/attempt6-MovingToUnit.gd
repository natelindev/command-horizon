extends "res://source/match/units/actions/Moving.gd"

var _target_unit = null
var _contact_elapsed = 0.0
var _contact_progress = null
var _orbit_windows = 0


func _init(target_unit):
	_target_unit = target_unit


func _process(delta):
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		queue_free()
		return
	var obstacle = _target_unit.get_node_or_null("MovementObstacle")
	if (
		_unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
		or obstacle == null
		or not obstacle.affect_navigation_mesh
	):
		return
	if _contact_progress == null:
		_contact_progress = _unit.global_position
	_contact_elapsed += delta
	if _contact_elapsed < 2.0:
		return
	_contact_elapsed = 0.0
	var center = _target_unit.global_position_yless
	var distance = _unit.global_position_yless.distance_to(center)
	var contact = (
		_unit.radius
		+ _target_unit.radius
		+ Utils.Match.Unit.Movement.adherence_margin(_unit, _target_unit)
	)
	# Near a work face, sideways avoidance can move the engineer without
	# advancing along its route. Use the next path corner: an open approach
	# can require moving away from the building before circling its footprint.
	var path = _movement_trait.get_current_navigation_path()
	var index = _movement_trait.get_current_navigation_path_index()
	var next = path[index] * Vector3(1, 0, 1) if index < path.size() else _target_position
	var orbiting = (
		distance < contact + 2.0
		and (
			_contact_progress.distance_to(next) - _unit.global_position_yless.distance_to(next)
			< 0.2
		)
	)
	_orbit_windows = _orbit_windows + 1 if orbiting else 0
	# A new work face may require a short outward avoidance detour. Require
	# two windows before replacing a route that is still moving.
	if _unit.global_position.distance_to(_contact_progress) < 0.2 or _orbit_windows >= 2:
		_try_open_approach()
		_orbit_windows = 0
	_contact_progress = _unit.global_position


func _ready():
	if restoring:
		return
	_target_unit.tree_exited.connect(queue_free)
	_target_position = (
		_target_unit.global_position_yless
		+ (
			(_unit.global_position_yless - _target_unit.global_position_yless).normalized()
			* _target_unit.radius
		)
	)
	super()


func _on_movement_finished():
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		queue_free()
	else:
		_try_open_approach()
		if not _movement_trait._has_destination:
			_target_position = _target_unit.global_position
			_movement_trait.move(_target_position)


func _try_open_approach():
	if not _movement_trait._synchronized:
		return
	var center = _target_unit.global_position_yless
	var origin = _unit.global_position_yless
	var contact = (
		_unit.radius
		+ _target_unit.radius
		+ Utils.Match.Unit.Movement.adherence_margin(_unit, _target_unit)
	)
	var radius = maxf(_target_unit.radius, contact - _movement_trait.target_desired_distance - 0.05)
	var blockers = get_tree().get_nodes_in_group("units").filter(
		func(other):
			return (
				other != _unit
				and not other.is_queued_for_deletion()
				and other.movement_speed > 0
				and other.movement_domain == _unit.movement_domain
				and (
					other.player == _unit.player
					or _unit._match.battlefield.is_observed(_unit.player, other)
				)
			)
	)
	var navmap = _movement_trait.get_navigation_map()
	var best = Vector3.INF
	var best_length = INF
	var faces = []
	# Choose another reachable work face without widening contact range or
	# ignoring the agents occupying the original approach. Ordinary RVO stays on.
	for index in 32:
		var radial = Vector3(cos(index * TAU / 32), 0, sin(index * TAU / 32))
		var point = NavigationServer3D.map_get_closest_point(navmap, center + radial * radius)
		point *= Vector3(1, 0, 1)
		if point.distance_to(center) > contact or point.distance_to(_target_position) < 0.5:
			continue
		var occupied = blockers.any(
			func(other):
				return (
					point.distance_to(other.global_position_yless)
					< _unit.radius + other.radius + 0.1
				)
		)
		if occupied:
			continue
		faces.append(point)
		var path = NavigationServer3D.map_get_path(navmap, origin, point, true)
		if path.size() < 2 or (path[-1] * Vector3(1, 0, 1)).distance_to(point) > 0.1:
			continue
		var length = 0.0
		for step in range(1, path.size()):
			length += path[step - 1].distance_to(path[step])
		if length < best_length:
			best = point
			best_length = length
	var clear = _clear_work_approach(origin, faces, blockers, navmap)
	if clear.is_finite():
		best = clear
	if best.is_finite():
		_target_position = best
		_movement_trait.move(best)


func _clear_work_approach(origin, faces, blockers, navmap):
	var best = Vector3.INF
	var best_length = INF
	for face in faces:
		var length = _clear_path_length(origin, face, blockers, navmap)
		if length < best_length:
			best = face
			best_length = length
	if best.is_finite():
		return best
	# Route around nearby observed bodies when no direct work face is clear.
	# Bounded local waypoints leave RVO authoritative if this small search
	# cannot resolve a larger crowd. Save/load already preserves the current
	# waypoint; reaching it recalculates the remaining approach.
	var nearby = blockers.filter(
		func(other): return other.global_position_yless.distance_to(origin) < 6.0
	)
	nearby.sort_custom(
		func(a, b):
			return (
				a.global_position_yless.distance_squared_to(origin)
				< b.global_position_yless.distance_squared_to(origin)
			)
	)
	var points = [origin]
	for other in nearby.slice(0, 6):
		var radius = (_unit.radius + other.radius + .05) / cos(PI / 12)
		for index in 12:
			var radial = Vector3(cos(index * TAU / 12), 0, sin(index * TAU / 12))
			var desired = other.global_position_yless + radial * radius
			var point = NavigationServer3D.map_get_closest_point(navmap, desired) * Vector3(1, 0, 1)
			if point.distance_to(desired) > .15 or point.distance_to(origin) < .3:
				continue
			if blockers.any(
				func(body):
					return (
						point.distance_to(body.global_position_yless) < _unit.radius + body.radius
					)
			):
				continue
			if points.any(func(known): return point.distance_to(known) < .1):
				continue
			points.append(point)
	var first_goal = points.size()
	points.append_array(faces)
	var costs = {0: 0.0}
	var first_steps = {}
	var closed = []
	# Limit expansion even in a packed base with no possible approach.
	for expansion in 24:
		var current = -1
		var estimate = INF
		for index in costs:
			if index in closed:
				continue
			var remaining = INF
			for face in faces:
				remaining = minf(remaining, points[index].distance_to(face))
			if costs[index] + remaining < estimate:
				current = index
				estimate = costs[index] + remaining
		if current < 0:
			break
		if current >= first_goal:
			return first_steps[current]
		closed.append(current)
		for index in range(1, points.size()):
			if (
				index in closed
				or (
					costs[current] + points[current].distance_to(points[index])
					>= costs.get(index, INF)
				)
			):
				continue
			var cost = (
				costs[current]
				+ _clear_path_length(points[current], points[index], blockers, navmap)
			)
			if cost < costs.get(index, INF):
				costs[index] = cost
				first_steps[index] = points[index] if current == 0 else first_steps[current]
	return Vector3.INF


func _clear_path_length(origin, point, blockers, navmap):
	var path = NavigationServer3D.map_get_path(navmap, origin, point, true)
	if path.size() < 2 or (path[-1] * Vector3(1, 0, 1)).distance_to(point) > .1:
		return INF
	var length = 0.0
	for index in range(1, path.size()):
		if (
			_movement_trait._ground_step_contact(path[index - 1], path[index], blockers).fraction
			< 1.0
		):
			return INF
		length += path[index - 1].distance_to(path[index])
	return length
