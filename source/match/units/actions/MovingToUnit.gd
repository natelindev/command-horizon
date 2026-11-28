# gdlint: disable=max-returns
extends "res://source/match/units/actions/Moving.gd"

const PathQuery = preload("res://source/match/orders/PathQuery.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")

const SEARCH_USEC_PER_FRAME = 2000
const SEARCH_QUERIES_PER_FRAME = 24
const SearchBudget = preload("res://source/match/orders/MovementSearchBudget.gd")
const RuntimeCache = preload("res://source/utils/RuntimeCache.gd")
var _target_unit = null
var _contact_elapsed = 0.0
var _contact_progress = null
var _orbit_windows = 0
var _searching = false
var _slice_started = 0
var _blocker_frame = -1
var _blocker_geometry: Array[Vector4] = []
var _path_query := PathQuery.new()

@onready var _search_allowance: SearchBudget = _shared_search_budget()


func _shared_search_budget() -> SearchBudget:
	var cache = RuntimeCache.bucket("movement_search_budget")
	if not cache.has("state"):
		cache.state = SearchBudget.new()
	return cache.state


func _init(target_unit):
	_target_unit = target_unit


func _process(delta):
	if not is_instance_valid(_target_unit):
		queue_free()
		return
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		queue_free()
		return
	# A save made during a sliced search contains the temporarily stopped
	# movement, but not the coroutine. Resume its saved goal once navigation is
	# ready; crowd displacement must not leave that restored action idle forever.
	if not _searching and _movement_trait._synchronized and not _movement_trait._has_destination:
		_movement_trait.move(_target_position)
	var obstacle = _target_unit.get_node_or_null("MovementObstacle")
	if (
		_unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
		or obstacle == null
		or not obstacle.affect_navigation_mesh
	):
		return
	if _contact_progress == null:
		_contact_progress = _unit.global_position_yless
	_contact_elapsed += delta
	if _contact_elapsed < 2.0:
		return
	_contact_elapsed = 0.0
	var distance = Footprint.reach_distance(_target_unit, _unit.global_position)
	var contact = (
		_unit.radius
		+ _target_unit.radius
		+ Utils.Match.Unit.Movement.adherence_margin(_unit, _target_unit)
	)
	# Keep the best distance to the reachable endpoint, rather than restarting
	# progress on each sideways avoidance window. Otherwise an engineer can
	# repeatedly leave and return to the same blocked front without ever
	# triggering a new work face.
	var path = _movement_trait.get_current_navigation_path()
	var endpoint = path[-1] * Vector3(1, 0, 1) if not path.is_empty() else _target_position
	var progress = (
		_contact_progress.distance_to(endpoint) - _unit.global_position_yless.distance_to(endpoint)
	)
	if progress >= .2:
		_contact_progress = _unit.global_position_yless
		_orbit_windows = 0
		return
	var near_contact = distance < contact + 2.0
	_orbit_windows = _orbit_windows + 1 if near_contact else 0
	# Give an honest outside detour time to clear the footprint. Long routes
	# only retry when stationary; near-contact loops retain a progress high-water.
	if _unit.global_position_yless.distance_to(_contact_progress) < .2 or _orbit_windows >= 2:
		_try_open_approach()
		_orbit_windows = 0
		_contact_progress = _unit.global_position_yless


func _ready():
	if restoring:
		return
	if not is_instance_valid(_target_unit):
		queue_free()
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
	# Structures need an open work face; deposits retain their ordinary field
	# route unless a settled mobile row actually blocks that original route.
	# A ghosted harvest run cannot be blocked by units: its ordinary route ends
	# on the nearest reachable face, and arrival still falls back to a search.
	var obstacle = _target_unit.get_node_or_null("MovementObstacle")
	if obstacle != null and obstacle.affect_navigation_mesh and not _movement_trait.ghosted:
		_try_open_approach(not _target_unit.has_method("is_constructed"))


func _on_movement_finished():
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		queue_free()
	elif not _try_open_approach(false, true):
		_target_position = _target_unit.global_position_yless
		_movement_trait.move(_target_position)


func _try_open_approach(preserve_clear_route = false, return_to_center = false):
	if _searching:
		return true
	if not _movement_trait._synchronized:
		return false
	_searching = true
	_run_approach.call_deferred(preserve_clear_route, return_to_center)
	return true


func _run_approach(preserve_clear_route, return_to_center):
	_slice_started = Time.get_ticks_usec()
	_blocker_frame = -1
	if not await _search_budget():
		_searching = false
		return
	# Keep following the current route while candidates are evaluated across
	# frames. Stopping here made every searching unit a settled blocker for its
	# neighbors and delayed fresh orders; the result is revalidated from the
	# live position before it replaces the route.
	var found = await _search_approach(preserve_clear_route)
	_searching = false
	if _search_valid() and not found:
		if return_to_center:
			_target_position = _target_unit.global_position_yless
		_movement_trait.move(_target_position)


func _search_valid():
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(_target_unit)
		and not _target_unit.is_queued_for_deletion()
		and is_instance_valid(_unit)
		and not _unit.is_queued_for_deletion()
	)


func _search_budget():
	# All workers share a frame budget. A single native path query is atomic;
	# charge its actual cost before admitting the next one.
	var now = Time.get_ticks_usec()
	if _search_allowance.frame == Engine.get_process_frames():
		_search_allowance.usec += now - _slice_started
	while _search_valid():
		var frame = Engine.get_process_frames()
		if _search_allowance.frame != frame:
			_search_allowance.frame = frame
			_search_allowance.usec = 0
			_search_allowance.queries = 0
		if (
			can_process()
			and _search_allowance.usec < SEARCH_USEC_PER_FRAME
			and _search_allowance.queries < SEARCH_QUERIES_PER_FRAME
		):
			_search_allowance.queries += 1
			_slice_started = Time.get_ticks_usec()
			return true
		await get_tree().process_frame
	return false


func _geometry(blockers):
	# Radius and position are live properties. Read them once per slice/frame,
	# not millions of times inside candidate x segment x blocker loops.
	if _blocker_frame != Engine.get_process_frames():
		_blocker_frame = Engine.get_process_frames()
		_blocker_geometry.clear()
		var radius = _unit.radius
		for other in blockers:
			if is_instance_valid(other) and not other.is_queued_for_deletion():
				var point = other.global_position_yless
				_blocker_geometry.append(Vector4(point.x, point.y, point.z, radius + other.radius))
	return _blocker_geometry


func _nav_point(point: Vector3) -> Vector3:
	if _movement_trait._elevated:
		return Vector3(
			point.x,
			(
				_movement_trait._map.height_at(Vector2(point.x, point.z))
				+ _movement_trait.path_height_offset
			),
			point.z
		)
	return point * Vector3(1, 0, 1)


func _search_approach(preserve_clear_route):
	if not await _search_budget():
		return false
	if not _movement_trait._synchronized:
		return false
	var center = _target_unit.global_position_yless
	var origin = _unit.global_position_yless
	var nav_origin = _nav_point(origin)
	var contact = (
		_unit.radius
		+ _target_unit.radius
		+ Utils.Match.Unit.Movement.adherence_margin(_unit, _target_unit)
	)
	var radius = maxf(_target_unit.radius, contact - _movement_trait.target_desired_distance - 0.05)
	# Ghosted harvest runs pass through units, and nobody is blocked by them.
	var ghosted = _movement_trait.ghosted
	var blockers = get_tree().get_nodes_in_group("units").filter(
		func(other):
			return (
				other != _unit
				and not ghosted
				and not other.is_queued_for_deletion()
				and other.movement_speed > 0
				and other.movement_domain == _unit.movement_domain
				and not other.get_node("Movement").ghosted
				and (
					other.player == _unit.player
					or _unit._match.battlefield.is_observed(_unit.player, other)
				)
			)
	)
	var navmap = _movement_trait.get_navigation_map()
	if preserve_clear_route:
		var ordinary_path = _path_query.path(navmap, nav_origin, _nav_point(_target_position))
		var settled = blockers.filter(
			func(other):
				var movement = other.get_node_or_null("Movement")
				return (
					other.process_mode == Node.PROCESS_MODE_DISABLED
					or (movement != null and not movement._has_destination)
				)
		)
		var clear = _path_clear_of_bodies(ordinary_path, settled)
		_blocker_frame = -1
		if clear:
			return false
	var best = Vector3.INF
	var best_length = INF
	var fallback_face = Vector3.INF
	var fallback_length = INF
	var faces = []
	# Choose another reachable work face without widening contact range or
	# ignoring the agents occupying the original approach. Ordinary RVO stays on.
	for index in 32:
		if not await _search_budget():
			return false
		var radial = Vector3(cos(index * TAU / 32), 0, sin(index * TAU / 32))
		var sample_world = center + radial * radius
		var projected = NavigationServer3D.map_get_closest_point(navmap, _nav_point(sample_world))
		var point = projected * Vector3(1, 0, 1)
		if Footprint.reach_distance(_target_unit, point) > contact:
			continue
		var occupied = false
		for body in _geometry(blockers):
			if point.distance_squared_to(Vector3(body.x, body.y, body.z)) < pow(body.w + .1, 2):
				occupied = true
				break
		if occupied:
			continue
		var path = _path_query.path(navmap, nav_origin, projected)
		if path.size() < 2 or (path[-1] * Vector3(1, 0, 1)).distance_to(point) > 0.1:
			continue
		var length = _path_length(path)
		if point.distance_to(_target_position) < 0.5:
			if _path_clear_of_bodies(path, blockers) and length < fallback_length:
				fallback_face = point
				fallback_length = length
			continue
		faces.append(point)
		if not _path_clear_of_bodies(path, blockers):
			continue
		if length < best_length:
			best = point
			best_length = length
	# A free work face can still lie behind a settled row of engineers. The
	# static navmesh cannot see that row. Find a short, clear outside waypoint
	# before entering the contact face; RVO and ordinary body clipping still
	# govern every step. Finishing the waypoint rechecks contact and the route.
	if not best.is_finite() and not faces.is_empty():
		for ring in [
			[origin, 2.0],
			[origin, 4.0],
			[center, contact + 2.0],
			[center, contact + 4.0],
			[center, contact + 8.0]
		]:
			for index in 64:
				if not await _search_budget():
					return false
				var offset = Vector3(cos(index * TAU / 64), 0, sin(index * TAU / 64))
				var waypoint = ring[0] + offset * ring[1]
				var projected_3d = NavigationServer3D.map_get_closest_point(
					navmap, _nav_point(waypoint)
				)
				var projected = projected_3d * Vector3(1, 0, 1)
				if projected.distance_to(waypoint) > .15:
					continue
				var first = _path_query.path(navmap, nav_origin, projected_3d)
				if (
					first.size() < 2
					or (first[-1] * Vector3(1, 0, 1)).distance_to(projected) > .1
					or not _path_clear_of_bodies(first, blockers)
				):
					continue
				for face in faces:
					if not await _search_budget():
						return false
					var second = _path_query.path(navmap, projected_3d, _nav_point(face))
					if (
						second.size() < 2
						or (second[-1] * Vector3(1, 0, 1)).distance_to(face) > .1
						or not _path_clear_of_bodies(second, blockers)
					):
						continue
					var length = _path_length(first) + _path_length(second)
					if length < best_length:
						best = projected
						best_length = length
	if not best.is_finite() and not faces.is_empty():
		best = await _two_corner_approach(navmap, origin, center, contact, faces, blockers)
	if not best.is_finite() and fallback_face.is_finite():
		best = fallback_face
	if not best.is_finite():
		return false
	if not await _search_budget():
		return false
	# The worker and nearby agents may move while the search yields.
	var current_path = _path_query.path(
		navmap, _nav_point(_unit.global_position_yless), _nav_point(best)
	)
	if (
		current_path.size() < 2
		or (current_path[-1] * Vector3(1, 0, 1)).distance_to(best) > .1
		or not _path_clear_of_bodies(current_path, blockers)
	):
		return false
	_target_position = best
	_movement_trait.move(best)
	return true


func _two_corner_approach(navmap, origin, center, contact, faces, blockers):
	# Two offset rows can require two turns: no single outside waypoint has a
	# clear path both from the worker and to a work face. Search a bounded local
	# set only after the cheaper direct and one-corner approaches fail.
	var starts = []
	var finishes = []
	for ring in [[origin, 4.0], [center, contact + 4.0], [center, contact + 8.0]]:
		for index in 16:
			if not await _search_budget():
				return Vector3.INF
			var angle = index * TAU / 16
			var candidate = ring[0] + Vector3(cos(angle), 0, sin(angle)) * ring[1]
			var point = NavigationServer3D.map_get_closest_point(navmap, _nav_point(candidate))
			point *= Vector3(1, 0, 1)
			if point.distance_to(candidate) > .15:
				continue
			var first = await _clear_path_length(navmap, origin, point, blockers)
			if is_finite(first):
				starts.append({"point": point, "length": first})
			var last = INF
			for face in faces:
				last = minf(last, await _clear_path_length(navmap, point, face, blockers))
			if is_finite(last):
				finishes.append({"point": point, "length": last})
	var best = Vector3.INF
	var best_length = INF
	for first in starts:
		for last in finishes:
			var lower_bound = first.length + first.point.distance_to(last.point) + last.length
			if lower_bound >= best_length:
				continue
			var middle = await _clear_path_length(navmap, first.point, last.point, blockers)
			var total = first.length + middle + last.length
			if total < best_length:
				best = first.point
				best_length = total
	return best


func _clear_path_length(navmap, start, end, blockers):
	if not await _search_budget():
		return INF
	var path = _path_query.path(navmap, _nav_point(start), _nav_point(end))
	if (
		path.size() < 2
		or (path[-1] * Vector3(1, 0, 1)).distance_to(end) > .1
		or not _path_clear_of_bodies(path, blockers)
	):
		return INF
	return _path_length(path)


func _path_length(path):
	var length = 0.0
	for step in range(1, path.size()):
		length += path[step - 1].distance_to(path[step])
	return length


func _path_clear_of_bodies(path, blockers):
	var geometry = _geometry(blockers)
	for index in range(1, path.size()):
		var start = path[index - 1] * Vector3(1, 0, 1)
		var end = path[index] * Vector3(1, 0, 1)
		var segment = end - start
		var length_squared = segment.length_squared()
		if length_squared < .000001:
			continue
		for body in geometry:
			var center = Vector3(body.x, body.y, body.z)
			var separation = body.w - _movement_trait.GROUND_CONTACT_MARGIN
			var offset = start - center
			# A pre-existing crowd contact must allow an outward escape.
			if offset.length_squared() < separation * separation and offset.dot(segment) >= 0:
				continue
			var fraction = clampf((center - start).dot(segment) / length_squared, 0, 1)
			if start.lerp(end, fraction).distance_squared_to(center) < separation * separation:
				return false
	return true
