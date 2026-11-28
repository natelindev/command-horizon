# TODO: refactor required after porting from Godot 3
enum Member { MOVEMENT, RADIUS, ORIGIN, MAP, SYNCHRONIZED }
const Connectivity = preload("res://source/match/orders/NavigationConnectivity.gd")
const Planner = preload("res://source/match/orders/FormationPlanner.gd")
const Footprint = preload("res://source/match/utils/Footprint.gd")
const DISTANCE_CACHE_LIMIT = 1024

# crowd - group of units
# pivot - pivot point, central point of crowd


static func crowd_moved_to_new_pivot(units, new_pivot, heading = null, formation = "line"):
	"""calculates new unit positions relative to new_pivot"""
	if units.is_empty():
		return []
	if units.size() == 1:
		return [[units[0], new_pivot]]
	var profiling = "--profile-formation" in OS.get_cmdline_user_args()
	var before = Time.get_ticks_usec()
	var members = {}
	var origins = PackedVector3Array()
	var maximum_radius = 0.0
	for index in units.size():
		var unit = units[index]
		var movement = unit.get_node("Movement")
		var nav = movement.get_navigation_map()
		# These facts cannot change during this synchronous, read-only plan.
		# Reuse them in fallback packing and final-owner verification instead
		# of repeatedly resolving derived unit properties and server iteration.
		var origin = unit.global_position
		var radius = movement.radius
		origins.append(origin)
		maximum_radius = maxf(maximum_radius, radius)
		members[unit] = [
			movement,
			radius,
			origin,
			nav,
			movement._synchronized and NavigationServer3D.map_get_iteration_id(nav) != 0
		]
	if heading == null or not heading is Vector3 or heading.length_squared() < .001:
		heading = new_pivot - _positions_pivot_yless(origins)
	var points = Planner.positions(
		units, new_pivot, heading.normalized(), formation, 0.0, maximum_radius
	)
	var provisional = []
	for index in units.size():
		provisional.append([units[index], points[index]])
	if profiling:
		print("FORMATION GEOMETRY ms=", (Time.get_ticks_usec() - before) / 1000.0)
	before = Time.get_ticks_usec()
	var contexts = {}
	var resolved = _resolve_group_destinations(provisional, contexts, members)
	if profiling:
		print("FORMATION RESOLVE ms=", (Time.get_ticks_usec() - before) / 1000.0)
	before = Time.get_ticks_usec()
	# Match the actual projected, separated slots, including map-edge fallbacks.
	var assigned = Planner.assign(
		units, resolved.map(func(pair): return pair[1]), formation, origins
	)
	if profiling:
		print("FORMATION ASSIGN ms=", (Time.get_ticks_usec() - before) / 1000.0)
	before = Time.get_ticks_usec()
	for pair in assigned:
		var reachable = _reachable_point(members[pair[0]], pair[1], [], 0.0, {}, contexts)
		if not reachable.is_finite():
			return resolved
		if reachable.distance_squared_to(pair[1] * Vector3(1, 0, 1)) > .0001:
			# Hover and ground units can share a role band but use different
			# surfaces. Preserve their assigned role positions while repacking
			# the actual reachable endpoints for each final owner.
			return _resolve_group_destinations(assigned, contexts, members)
	if profiling:
		print("FORMATION VERIFY ms=", (Time.get_ticks_usec() - before) / 1000.0)
	return assigned


static func _resolve_group_destinations(unit_positions, contexts: Dictionary, members: Dictionary):
	# Projection at a shoreline, wall or map edge can collapse different slots
	# onto one endpoint. Pack the actual reachable points, not the raw offsets.
	var result = []
	var discs = []
	var margin = Constants.Match.Units.ADHERENCE_MARGIN_M * 2
	var max_radius = 0.0
	for pair in unit_positions:
		max_radius = maxf(max_radius, members[pair[0]][Member.RADIUS])
	var step = max_radius * 2 + margin + 0.05
	var disc_index = {"step": step, "cells": {}}
	# Search square rings with enough sites for a full army even when only
	# one quadrant is usable and the nearby base occupies part of that quadrant.
	var slots = []
	var generated_rings = 0
	var maximum_rings = ceili(sqrt(unit_positions.size())) * 2 + 2
	var attempts = 0
	var fallbacks = 0

	for pair in unit_positions:
		var unit = pair[0]
		var member: Array = members[unit]
		var radius: float = member[Member.RADIUS]
		var chosen = _reachable_point(member, pair[1], discs, margin, disc_index, contexts)
		if not chosen.is_finite():
			fallbacks += 1
			var movement = member[Member.MOVEMENT]
			var center = pair[1]
			if movement._synchronized:
				var nav = member[Member.MAP]
				var context = contexts.get(nav)
				var projected = (
					context.projected.get(center, Vector3.INF) if context != null else Vector3.INF
				)
				if not projected.is_finite():
					projected = movement.project_command_point(center)
				var origin: Vector3 = member[Member.ORIGIN]
				if Connectivity.can_reach(movement, origin, projected, context):
					center = projected * Vector3(1, 0, 1)
				else:
					var path = movement._match.navigation.path_query.path(nav, origin, projected)
					# A partial route ends on the unit's own reachable component.
					center = (
						(
							path[-1]
							if not path.is_empty()
							else NavigationServer3D.map_get_closest_point(nav, origin)
						)
						* Vector3(1, 0, 1)
					)

			var cursor = 0
			while cursor < slots.size() or generated_rings < maximum_rings:
				if cursor == slots.size():
					generated_rings += 1
					slots.append_array(_fallback_ring(step, generated_rings))
				var candidate = center + slots[cursor]
				cursor += 1
				if _indexed_disc_collision(candidate, radius, disc_index, margin):
					continue
				attempts += 1
				var point = _reachable_point(member, candidate, discs, margin, disc_index, contexts)
				if point.is_finite():
					chosen = point
					break

		# A tiny disconnected pocket may have less room than the selected army.
		# Keep ordinary navigation/arrival behavior when no separate slot fits.
		if not chosen.is_finite():
			var fallback = _reachable_point(member, pair[1])
			chosen = fallback if fallback.is_finite() else pair[1]
		result.append([unit, chosen])
		discs.append([chosen, radius])
		var key = Vector2i(floori(chosen.x / step), floori(chosen.z / step))
		if not disc_index.cells.has(key):
			disc_index.cells[key] = []
		disc_index.cells[key].append([chosen, radius])
	if "--profile-formation" in OS.get_cmdline_user_args():
		print(
			"FORMATION PACK count=",
			unit_positions.size(),
			" fallback=",
			fallbacks,
			" attempts=",
			attempts
		)
	return result


static func _indexed_disc_collision(
	point: Vector3, radius: float, index: Dictionary, margin: float
) -> bool:
	var cell = Vector2i(floori(point.x / index.step), floori(point.z / index.step))
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			for disc in index.cells.get(Vector2i(x, z), []):
				var separation = radius + disc[1] + margin
				if (
					((point - disc[0]) * Vector3(1, 0, 1)).length_squared()
					<= separation * separation
				):
					return true
	return false


static func _fallback_ring(step: float, ring: int) -> Array:
	var slots = []
	for offset in range(-ring, ring + 1):
		slots.append(Vector3(offset, 0, -ring) * step)
		slots.append(Vector3(offset, 0, ring) * step)
	for offset in range(-ring + 1, ring):
		slots.append(Vector3(-ring, 0, offset) * step)
		slots.append(Vector3(ring, 0, offset) * step)
	return slots


static func _reachable_point(
	member: Array, point, discs = [], margin = 0.0, disc_index = {}, contexts = {}
):
	var movement = member[Member.MOVEMENT]
	var nav = member[Member.MAP]
	var radius: float = member[Member.RADIUS]
	if not member[Member.SYNCHRONIZED]:
		return Vector3.INF if _disc_collides_with_others([point, radius], discs, margin) else point
	if not contexts.has(nav):
		contexts[nav] = Connectivity.context(movement)
	var context = contexts[nav]
	var projected = context.projected.get(point, Vector3.INF)
	if not projected.is_finite():
		projected = movement.project_command_point(point)
		context.projected[point] = projected
	if (
		_indexed_disc_collision(projected, radius, disc_index, margin)
		if not disc_index.is_empty()
		else _disc_collides_with_others([projected * Vector3(1, 0, 1), radius], discs, margin)
	):
		return Vector3.INF
	if not Connectivity.can_reach(movement, member[Member.ORIGIN], projected, context):
		return Vector3.INF
	# Orders use planar world coordinates. Navigation meshes can be baked
	# above the rendered ground; movement owns that height offset.
	var flat = projected * Vector3(1, 0, 1)
	context.projected[flat] = projected
	return flat


static func path_distance_to(unit, point, arrival_range):
	var movement = unit.get_node("Movement")
	var nav = movement.get_navigation_map()
	# Before initial synchronization, retain the provisional nearest choice.
	# Normal movement waits for navigation before starting the trip.
	var iteration = NavigationServer3D.map_get_iteration_id(nav)
	if not movement._synchronized or iteration == 0:
		return unit.global_position_yless.distance_to(point * Vector3(1, 0, 1))
	var target = point
	if unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN and movement._elevated:
		target = Vector3(point.x, movement._map.height_at(Vector2(point.x, point.z)), point.z)
	var frame = Engine.get_physics_frames()
	var navigation = movement._match.navigation
	var cache = navigation.distance_cache
	if navigation.distance_frame != frame or cache.size() >= DISTANCE_CACHE_LIMIT:
		navigation.distance_frame = frame
		cache.clear()
	# Sorting and economic planning repeatedly ask the identical reachability
	# question. Exact endpoints and map publication keep teleports/rebakes live.
	var key = [nav, iteration, unit.global_position, target, arrival_range]
	if cache.has(key):
		return cache[key]
	var distance = _path_distance(
		nav, unit.global_position, target, arrival_range, navigation.path_query
	)
	cache[key] = distance
	return distance


static func path_distance_to_unit(unit, target_unit, arrival_range) -> float:
	if not Footprint.has_outline(target_unit):
		return path_distance_to(unit, target_unit.global_position, arrival_range)
	var movement = unit.get_node("Movement")
	var nav = movement.get_navigation_map()
	var iteration = NavigationServer3D.map_get_iteration_id(nav)
	if not movement._synchronized or iteration == 0:
		return Footprint.reach_distance(target_unit, unit.global_position)
	var target = target_unit.global_position
	if unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN and movement._elevated:
		target = Vector3(target.x, movement._map.height_at(Vector2(target.x, target.z)), target.z)
	var path = movement._match.navigation.path_query.path(nav, unit.global_position, target)
	if path.is_empty() or Footprint.reach_distance(target_unit, path[-1]) > arrival_range:
		return INF
	var distance = 0.0
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance


static func _path_distance(nav: RID, origin: Vector3, point: Vector3, arrival_range: float, query):
	var path = query.path(nav, origin, point)
	if (
		path.is_empty()
		or (path[-1] * Vector3(1, 0, 1)).distance_to(point * Vector3(1, 0, 1)) > arrival_range
	):
		return INF
	var distance = 0.0
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance


static func calculate_formation_slots(
	units,
	new_pivot: Vector3,
	heading: Vector3,
	formation: String = "line",
	custom_spacing: float = 0.0
):
	return Planner.assign(
		units, formation_positions(units, new_pivot, heading, formation, custom_spacing), formation
	)


# Preview uses exactly the same geometry as accepted group orders.
static func formation_positions(
	units,
	new_pivot: Vector3,
	heading: Vector3,
	formation: String = "line",
	custom_spacing: float = 0.0
):
	return Planner.positions(units, new_pivot, heading, formation, custom_spacing)


static func calculate_aabb_crowd_pivot_yless(units):
	"""calculates pivot which is a center of crowd AABB"""
	var unit_positions = PackedVector3Array()
	for unit in units:
		unit_positions.append(unit.global_position)
	return _positions_pivot_yless(unit_positions)


static func _positions_pivot_yless(positions: PackedVector3Array) -> Vector3:
	var begin = Vector3(INF, 0.0, INF)
	var end = Vector3(-INF, 0.0, -INF)
	for point in positions:
		begin.x = minf(begin.x, point.x)
		begin.z = minf(begin.z, point.z)
		end.x = maxf(end.x, point.x)
		end.z = maxf(end.z, point.z)
	return (begin + end) / 2.0 * Vector3(1, 0, 1)


static func units_adhere(unit_a, unit_b):
	"""checks if distance between unit borders is within margin"""
	return _unit_in_range_of_other(unit_a, unit_b, adherence_margin(unit_a, unit_b))


static func adherence_margin(unit_a, unit_b):
	var margin = Constants.Match.Units.ADHERENCE_MARGIN_M
	var obstacle = unit_b.get_node_or_null("MovementObstacle")
	if obstacle != null and obstacle.affect_navigation_mesh:
		# The shared terrain mesh is eroded for the largest unit and rounded to
		# diagonal voxel corners, and NavigationAgent3D finishes within
		# target_desired_distance of that boundary. Engineers must always adhere
		# cleanly at any reachable corner of a drop-off, structure or deposit.
		margin = maxf(
			margin,
			(
				Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
				- unit_a.radius
				+ Constants.Match.Terrain.Navmesh.CELL_SIZE * 1.5
				+ 0.15
			)
		)
	return margin


static func _unit_in_range_of_other(unit_a, unit_b, b_range):
	"""checks if distance from one unit border to another is within range"""
	# Footprinted structures measure from their outline (Footprint.reach_distance).
	var distance = minf(
		Footprint.reach_distance(unit_b, unit_a.global_position),
		Footprint.reach_distance(unit_a, unit_b.global_position)
	)
	return distance <= (unit_a.radius + unit_b.radius + b_range)


static func _disc_collides_with_others(disc, discs, adherence_margin):
	var disc_pos = disc[0]
	var disc_radius = disc[1]
	for other_disc in discs:
		var other_disc_pos = other_disc[0]
		var other_disc_radius = other_disc[1]
		if (
			disc_pos.distance_to(other_disc_pos)
			<= disc_radius + other_disc_radius + adherence_margin
		):
			return true
	return false


static func _calculate_min_x(positions):
	return _calculate_extremum(positions, Vector3(1, 0, 0), true)


static func _calculate_min_z(positions):
	return _calculate_extremum(positions, Vector3(0, 0, 1), true)


static func _calculate_max_x(positions):
	return _calculate_extremum(positions, Vector3(1, 0, 0), false)


static func _calculate_max_z(positions):
	return _calculate_extremum(positions, Vector3(0, 0, 1), false)


static func _calculate_extremum(positions, axis, minimum):
	var extremum = null
	for position in positions:
		var value = position.x if axis.x == 1 else position.z
		if extremum == null:
			extremum = value
			continue
		if (minimum and value < extremum) or (not minimum and value > extremum):
			extremum = value
	return extremum
