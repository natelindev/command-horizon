# TODO: refactor required after porting from Godot 3
const DISTANCE_REDUCTION_BY_DIVISION_ITERATIONS_MAX = 10
const DISTANCE_REDUCTION_BY_SUBTRACTION_ITERATIONS_MAX = 10

# crowd - group of units
# pivot - pivot point, central point of crowd


static func crowd_moved_to_new_pivot(units, new_pivot, heading = null, formation = "line"):
	"""calculates new unit positions relative to new_pivot"""
	if units.is_empty():
		return []
	if units.size() == 1:
		return [[units[0], new_pivot]]
	if heading != null and heading is Vector3 and heading.length_squared() > 0.001:
		return calculate_formation_slots(units, new_pivot, heading.normalized(), formation)
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
	return condensed_unit_positions


static func calculate_formation_slots(
	units, new_pivot: Vector3, heading: Vector3, formation: String = "line", custom_spacing: float = 0.0
):
	if units.is_empty():
		return []
	if units.size() == 1:
		return [[units[0], new_pivot]]

	var base_spacing = custom_spacing
	if base_spacing <= 0.0:
		for unit in units:
			if "radius" in unit and unit.radius != null:
				base_spacing = maxf(base_spacing, unit.radius * 2.4)
		base_spacing = maxf(base_spacing, 2.4)

	var forward = Vector3(heading.x, 0.0, heading.z).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var right = Vector3(-forward.z, 0.0, forward.x)
	var pivot_yless = new_pivot * Vector3(1, 0, 1)

	var raw_slots = []
	var count = units.size()

	if formation == "wedge":
		for i in range(count):
			if i == 0:
				raw_slots.append(pivot_yless)
			else:
				var tier = int(ceil(float(i) / 2.0))
				var side = 1.0 if (i % 2 == 1) else -1.0
				raw_slots.append(
					pivot_yless
					- forward * (tier * base_spacing * 1.1)
					+ right * (side * tier * base_spacing)
				)
	elif formation == "staggered" or formation == "box":
		var cols = int(ceil(sqrt(count)))
		var rows = int(ceil(float(count) / float(cols)))
		for i in range(count):
			var r = i / cols
			var c = i % cols
			var stagger = (base_spacing * 0.5) if (r % 2 == 1) else 0.0
			var x_off = (float(c) - (cols - 1) * 0.5) * base_spacing + stagger
			var z_off = -(float(r) - (rows - 1) * 0.5) * base_spacing * 1.2
			raw_slots.append(pivot_yless + right * x_off + forward * z_off)
	else:
		# "line" rank-and-file formation
		var max_per_rank = 8 if count > 8 else count
		for i in range(count):
			var rank = i / max_per_rank
			var col = i % max_per_rank
			var rank_count = min(max_per_rank, count - rank * max_per_rank)
			var x_off = (float(col) - (rank_count - 1) * 0.5) * base_spacing
			var z_off = -rank * base_spacing * 1.2
			raw_slots.append(pivot_yless + right * x_off + forward * z_off)

	# Greedy slot assignment: assign units to nearest available slot
	var remaining_slots = raw_slots.duplicate()
	var assignments = []
	for unit in units:
		var u_pos = unit.global_position * Vector3(1, 0, 1)
		var best_idx = 0
		var best_dist = INF
		for s_idx in range(remaining_slots.size()):
			var d = u_pos.distance_squared_to(remaining_slots[s_idx])
			if d < best_dist:
				best_dist = d
				best_idx = s_idx
		var chosen_slot = remaining_slots[best_idx]
		remaining_slots.remove_at(best_idx)
		assignments.append([unit, Vector3(chosen_slot.x, new_pivot.y, chosen_slot.z)])

	return assignments


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
	var result = []
	for unit in new_unit_positions:
		result.append([unit, new_unit_positions[unit]])
	return result


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
