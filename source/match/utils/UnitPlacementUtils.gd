enum { VALID, COLLIDES_WITH_AGENT, NOT_NAVIGABLE, NOT_LEVEL }

# Foundations tolerate modest relief and gentle ramps, but not cliff edges.
const FOUNDATION_HEIGHT_TOLERANCE = 0.6
const FOUNDATION_MAX_GRADE = 0.35
const NAVIGATION_TOLERANCE = 0.05
# Baked walkable surfaces sit this far above authored ground (TerrainNavigation).
const SURFACE_LIFT = 0.5

const Footprint = preload("res://source/match/utils/Footprint.gd")
# Interior navigability probes for polygon footprints, in metres.
const FOOTPRINT_PROBE_SPACING = 2.0


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


# Pass an elevated `map` to check foundation support and query from its surface.
static func validate_agent_placement_position(
	position, radius, existing_units, navigation_map_rid, map = null
):
	for existing_unit in existing_units:
		if existing_unit.is_in_group("salvage_wrecks"):
			continue  # Drive-over rubble never blocks rebuilding or production exits.
		if Footprint.reach_distance(existing_unit, position) <= existing_unit.radius + radius:
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
			var distance = Vector2(point.x - position.x, point.z - position.z).length()
			if not _foundation_supports(level, height, distance):
				return NOT_LEVEL
			# Query from the walkable surface so the projection stays vertical.
			points_expected_to_be_navigable[index] = Vector3(
				point.x, height + SURFACE_LIFT, point.z
			)
	for point_expected_to_be_navigable in points_expected_to_be_navigable:
		if not _is_navigable(point_expected_to_be_navigable, navigation_map_rid):
			return NOT_NAVIGABLE
	return VALID


# Placement of a structure with a polygon footprint (world XZ outline): no
# overlap with any unit or deposit, and its outline and interior on navigable
# ground.
static func validate_footprint_placement(polygon, existing_units, navigation_map_rid, map = null):
	for existing_unit in existing_units:
		if existing_unit.is_in_group("salvage_wrecks"):
			continue
		var other = Footprint.world_outline(existing_unit)
		if other.is_empty():
			var center = Vector2(existing_unit.global_position.x, existing_unit.global_position.z)
			if Footprint.polygon_touches_circle(polygon, center, existing_unit.radius):
				return COLLIDES_WITH_AGENT
		elif Footprint.polygons_touch(polygon, other):
			return COLLIDES_WITH_AGENT
	var probes = Footprint.edge_samples(polygon, 1.0)
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	var center = Vector2.ZERO
	for point in polygon:
		bounds = bounds.expand(point)
		center += point
	center /= polygon.size()
	probes.append(center)
	var x = bounds.position.x + FOOTPRINT_PROBE_SPACING * 0.5
	while x < bounds.end.x:
		var z = bounds.position.y + FOOTPRINT_PROBE_SPACING * 0.5
		while z < bounds.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), polygon):
				probes.append(Vector2(x, z))
			z += FOOTPRINT_PROBE_SPACING
		x += FOOTPRINT_PROBE_SPACING
	var elevated = map != null and map.is_elevated()
	var level = map.height_at(center) if elevated else 0.0
	for probe in probes:
		var point = Vector3(probe.x, 0, probe.y)
		if elevated:
			var height = map.height_at(probe)
			if not _foundation_supports(level, height, center.distance_to(probe)):
				return NOT_LEVEL
			point.y = height + SURFACE_LIFT
		if not _is_navigable(point, navigation_map_rid):
			return NOT_NAVIGABLE
	return VALID


static func _foundation_supports(center_height, height, distance):
	var allowance = minf(FOUNDATION_HEIGHT_TOLERANCE, maxf(0.05, distance * FOUNDATION_MAX_GRADE))
	return absf(height - center_height) <= allowance


static func _is_navigable(point, navigation_map_rid):
	var closest = NavigationServer3D.map_get_closest_point(navigation_map_rid, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() <= NAVIGATION_TOLERANCE


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
