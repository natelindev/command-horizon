enum { VALID, COLLIDES_WITH_AGENT, NOT_NAVIGABLE, NOT_LEVEL }

# Footprints may not straddle a cliff or sit on a ramp (height samples differ).
const LEVEL_TOLERANCE = 0.05
# Baked walkable surfaces sit this far above authored ground (TerrainNavigation).
const SURFACE_LIFT = 0.5


static func find_valid_position_radially(
	starting_position: Vector3, radius: float, navigation_map_rid: RID, scene_tree
):
	return find_valid_position_radially_yet_skip_starting_radius(
		starting_position, 0.0, radius, 0.0, Vector3(0, 0, 1), true, navigation_map_rid, scene_tree
	)


static func find_valid_position_radially_yet_skip_starting_radius(
	starting_position: Vector3,
	starting_radius: float,
	radius: float,
	spacing: float,
	starting_direction: Vector3,
	shuffle: bool,
	navigation_map_rid: RID,
	scene_tree
):
	var starting_position_yless = starting_position * Vector3(1, 0, 1)
	var units = (
		scene_tree.get_nodes_in_group("units") + scene_tree.get_nodes_in_group("resource_units")
	)
	var map = scene_tree.get_first_node_in_group("battle_map")
	if map != null and not map.is_elevated():
		map = null
	var starting_distance = (
		0 if is_zero_approx(starting_radius) else starting_radius + radius + spacing
	)
	var starting_offset = 1 if is_zero_approx(starting_radius) else 0
	if (
		is_zero_approx(starting_radius)
		and _is_agent_placement_position_valid(
			_grounded(starting_position_yless, map), radius, units, navigation_map_rid, map
		)
	):
		return _grounded(starting_position_yless, map)
	for ring_number in range(starting_offset, 999999):
		var ring_distance_from_starting_position: float = (
			starting_distance + radius * 0.5 * ring_number
		)
		var rotation_angle_rad = asin((radius + spacing) / ring_distance_from_starting_position)
		var radial_positions = []
		var next_rotation_angle_rad = 0.0
		while next_rotation_angle_rad <= PI * 2.0 - rotation_angle_rad:
			radial_positions.append(
				(
					starting_position_yless
					+ (
						starting_direction.normalized().rotated(Vector3.UP, next_rotation_angle_rad)
						* ring_distance_from_starting_position
					)
				)
			)
			next_rotation_angle_rad += rotation_angle_rad
		if shuffle:
			radial_positions.shuffle()
		for radial_position in radial_positions:
			var grounded = _grounded(radial_position, map)
			if _is_agent_placement_position_valid(grounded, radius, units, navigation_map_rid, map):
				return grounded
	assert(false, "unexpected flow")
	return Vector3.INF


# Pass an elevated `map` to require level ground and query from its tier.
static func validate_agent_placement_position(
	position, radius, existing_units, navigation_map_rid, map = null
):
	for existing_unit in existing_units:
		if existing_unit.is_in_group("salvage_wrecks"):
			continue  # Drive-over rubble never blocks rebuilding or production exits.
		if (
			(existing_unit.global_position * Vector3(1, 0, 1)).distance_to(
				position * Vector3(1, 0, 1)
			)
			<= existing_unit.radius + radius
		):
			return COLLIDES_WITH_AGENT
	var points_expected_to_be_navigable = []
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			points_expected_to_be_navigable.append(
				position + Vector3(x, 0, z).normalized() * radius
			)
	if map != null and map.is_elevated():
		var level = map.height_at(Vector2(position.x, position.z))
		for index in points_expected_to_be_navigable.size():
			var point = points_expected_to_be_navigable[index]
			var height = map.height_at(Vector2(point.x, point.z))
			if absf(height - level) > LEVEL_TOLERANCE:
				return NOT_LEVEL
			# Query from the walkable surface so the projection stays vertical.
			points_expected_to_be_navigable[index] = Vector3(
				point.x, height + SURFACE_LIFT, point.z
			)
	for point_expected_to_be_navigable in points_expected_to_be_navigable:
		if not (point_expected_to_be_navigable * Vector3(1, 0, 1)).is_equal_approx(
			(
				NavigationServer3D.map_get_closest_point(
					navigation_map_rid, point_expected_to_be_navigable
				)
				* Vector3(1, 0, 1)
			)
		):
			return NOT_NAVIGABLE
	return VALID


static func _is_agent_placement_position_valid(
	position, radius, existing_units, navigation_map_rid, map = null
):
	return (
		validate_agent_placement_position(position, radius, existing_units, navigation_map_rid, map)
		== VALID
	)


static func _grounded(position: Vector3, map) -> Vector3:
	if map == null:
		return position
	return map.ground_point(Vector2(position.x, position.z))


static func owned_structure_at(player, point):
	for structure in player.get_children():
		if (
			structure.is_in_group("units")
			and structure.has_method("is_constructed")
			and not structure.is_queued_for_deletion()
			and structure.hp > 0
			and structure.global_position_yless.distance_to(point) < structure.radius
		):
			return structure
	return null
