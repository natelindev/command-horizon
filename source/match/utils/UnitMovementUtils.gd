# TODO: refactor required after porting from Godot 3
const DISTANCE_REDUCTION_BY_DIVISION_ITERATIONS_MAX = 10
const DISTANCE_REDUCTION_BY_SUBTRACTION_ITERATIONS_MAX = 10

# crowd - group of units
# pivot - pivot point, central point of crowd


static func crowd_moved_to_new_pivot(units, new_pivot):
	"""calculates new unit positions relative to new_pivot"""
	if units.is_empty():
		return []
	if units.size() == 1:
		return [[units[0], new_pivot]]
	var old_pivot = calculate_aabb_crowd_pivot_yless(units)
	var yless_unit_offsets_from_old_pivot = _calculate_yless_unit_offsets_from_old_pivot(
		units, old_pivot
	)
	var new_unit_positions = _calculate_new_unit_positions(
		yless_unit_offsets_from_old_pivot, new_pivot
	)
	var condensed_unit_positions = _attract_unit_positions_towards_pivot(
		new_unit_positions, new_pivot, Constants.Match.Units.ADHERENCE_MARGIN_M * 2
	)
	return _resolve_group_destinations(condensed_unit_positions, new_pivot)


static func _resolve_group_destinations(unit_positions, pivot):
	# Projection at a shoreline, wall or map edge can collapse different slots
	# onto one endpoint. Pack the actual reachable points, not the raw offsets.
	var result = []
	var discs = []
	var margin = Constants.Match.Units.ADHERENCE_MARGIN_M * 2
	var max_radius = 0.0
	for pair in unit_positions:
		max_radius = maxf(max_radius, pair[0].radius)
	var step = max_radius * 2 + margin + 0.05
	# Search square rings with enough sites for a full army even when only
	# one quadrant is usable and the nearby base occupies part of that quadrant.
	var rings = ceili(sqrt(unit_positions.size())) * 2 + 2
	var slots = []
	for ring in range(1, rings + 1):
		for offset in range(-ring, ring + 1):
			slots.append(pivot + Vector3(offset, 0, -ring) * step)
			slots.append(pivot + Vector3(offset, 0, ring) * step)
		for offset in range(-ring + 1, ring):
			slots.append(pivot + Vector3(-ring, 0, offset) * step)
			slots.append(pivot + Vector3(ring, 0, offset) * step)
	for pair in unit_positions:
		var unit = pair[0]
		var fallback = _reachable_point(unit, pair[1])
		var chosen = Vector3.INF
		for candidate in [pair[1]] + slots:
			var point = _reachable_point(unit, candidate, discs, margin)
			if not point.is_finite():
				continue
			chosen = point
			break
		# A tiny disconnected pocket may have less room than the selected army.
		# Keep ordinary navigation/arrival behavior when no separate slot fits.
		if not chosen.is_finite():
			chosen = fallback if fallback.is_finite() else pair[1]
		result.append([unit, chosen])
		discs.append([chosen, unit.radius])
	return result


static func _reachable_point(unit, point, discs = [], margin = 0.0):
	var movement = unit.get_node("Movement")
	var nav = movement.get_navigation_map()
	if not movement._synchronized or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return (
			Vector3.INF
			if _disc_collides_with_others([point, unit.radius], discs, margin)
			else point
		)
	var projected = NavigationServer3D.map_get_closest_point(nav, point)
	if _disc_collides_with_others([projected * Vector3(1, 0, 1), unit.radius], discs, margin):
		return Vector3.INF
	var path = NavigationServer3D.map_get_path(nav, unit.global_position, projected, true)
	if path.is_empty() or path[-1].distance_to(projected) > 0.1:
		return Vector3.INF
	# Orders use planar world coordinates. Navigation meshes can be baked
	# above the rendered ground; movement owns that height offset.
	return projected * Vector3(1, 0, 1)


static func path_distance_to(unit, point, arrival_range):
	var movement = unit.get_node("Movement")
	var nav = movement.get_navigation_map()
	# Before initial synchronization, retain the provisional nearest choice.
	# Normal movement waits for navigation before starting the trip.
	if not movement._synchronized or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return unit.global_position_yless.distance_to(point * Vector3(1, 0, 1))
	var path = NavigationServer3D.map_get_path(nav, unit.global_position, point, true)
	if (
		path.is_empty()
		or (path[-1] * Vector3(1, 0, 1)).distance_to(point * Vector3(1, 0, 1)) > arrival_range
	):
		return INF
	var distance = 0.0
	for index in range(1, path.size()):
		distance += path[index - 1].distance_to(path[index])
	return distance


static func calculate_aabb_crowd_pivot_yless(units):
	"""calculates pivot which is a center of crowd AABB"""
	var unit_positions = []
	for unit in units:
		unit_positions.append(unit.global_position)
	var begin = Vector3(_calculate_min_x(unit_positions), 0.0, _calculate_min_z(unit_positions))
	var end = Vector3(_calculate_max_x(unit_positions), 0.0, _calculate_max_z(unit_positions))
	return (begin + end) / 2.0 * Vector3(1, 0, 1)


static func units_adhere(unit_a, unit_b):
	"""checks if distance between unit borders is within margin"""
	return _unit_in_range_of_other(unit_a, unit_b, adherence_margin(unit_a, unit_b))


static func adherence_margin(unit_a, unit_b):
	var margin = Constants.Match.Units.ADHERENCE_MARGIN_M
	var obstacle = unit_b.get_node_or_null("MovementObstacle")
	if obstacle != null and obstacle.affect_navigation_mesh:
		# The shared terrain mesh is eroded for the largest unit and rounded to
		# cells. Engineers must be able to gather, deliver and build from that
		# reachable boundary. Mobile-unit contact retains the ordinary margin.
		margin = maxf(
			margin,
			(
				Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
				- unit_a.radius
				+ Constants.Match.Terrain.Navmesh.CELL_SIZE
			)
		)
	return margin


static func _unit_in_range_of_other(unit_a, unit_b, b_range):
	"""checks if distance from one unit border to another is within range"""
	var unit_a_position_yless = unit_a.global_position * Vector3(1, 0, 1)
	var unit_b_position_yless = unit_b.global_position * Vector3(1, 0, 1)
	return (
		unit_a_position_yless.distance_to(unit_b_position_yless)
		<= (unit_a.radius + unit_b.radius + b_range)
	)


static func _attract_unit_positions_towards_pivot(unit_positions, pivot, interunit_threshold):
	"""takes List[Tuple[unit, point]], pivot, and interunit_threshold(min interunit dist)"""
	var new_unit_positions = {}
	var unit_distances_to_pivot = []
	for tuple in unit_positions:
		var unit = tuple[0]
		var point = tuple[1]
		new_unit_positions[unit] = point
		unit_distances_to_pivot.append([unit, point.distance_to(pivot)])
	unit_distances_to_pivot.sort_custom(func(a, b): return a[1] < b[1])
	var discs = [[pivot, 0]]
	for tuple in unit_distances_to_pivot:
		var unit = tuple[0]
		var distance = tuple[1]
		var direction_towards_pivot = (pivot - new_unit_positions[unit]).normalized()
		# reduce distance by division
		for _i in range(DISTANCE_REDUCTION_BY_DIVISION_ITERATIONS_MAX):
			var candidate_pos = new_unit_positions[unit] + direction_towards_pivot * distance / 2.0
			if not _disc_collides_with_others(
				[candidate_pos, unit.radius], discs, interunit_threshold
			):
				distance /= 2.0
				new_unit_positions[unit] = candidate_pos
			else:
				break
		# reduce distance by subtraction
		var reduction_step = max(
			distance / 2.0 / float(DISTANCE_REDUCTION_BY_SUBTRACTION_ITERATIONS_MAX),
			interunit_threshold / 2.0
		)
		for _i in range(DISTANCE_REDUCTION_BY_SUBTRACTION_ITERATIONS_MAX):
			var candidate_pos = new_unit_positions[unit] + direction_towards_pivot * reduction_step
			if not _disc_collides_with_others(
				[candidate_pos, unit.radius], discs, interunit_threshold
			):
				new_unit_positions[unit] = candidate_pos
			else:
				break
		discs.append([new_unit_positions[unit], unit.radius])
	return Utils.Dict.items(new_unit_positions)


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


static func _calculate_new_unit_positions(yless_unit_offsets_from_old_pivot, new_pivot):
	var new_unit_positions = []
	for tuple in yless_unit_offsets_from_old_pivot:
		var unit = tuple[0]
		var offset = tuple[1]
		new_unit_positions.append([unit, new_pivot + offset])
	return new_unit_positions


static func _calculate_yless_unit_offsets_from_old_pivot(units, old_pivot):
	var old_pivot_yless = old_pivot * Vector3(1, 0, 1)
	var yless_unit_offsets_from_old_pivot = []
	for unit in units:
		var unit_position_yless = unit.global_position * Vector3(1, 0, 1)
		(
			yless_unit_offsets_from_old_pivot
			. append(
				[
					unit,
					unit_position_yless - old_pivot_yless,
				]
			)
		)
	return yless_unit_offsets_from_old_pivot


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
