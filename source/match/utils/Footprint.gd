extends RefCounted

# Polygon footprints for structures that are not circles (the runway airfield).
# A unit's footprint is its MovementObstacle `footprint` outline in local XZ; it
# turns and moves with the unit. Circular units have none and keep using
# `radius` everywhere.
#
# reach_distance() lets "center distance <= range + target.radius" checks stay
# correct for long structures: it returns the distance to the nearest footprint
# point plus the structure's own (inscribed) radius, which equals the center
# distance for circular units.


static func local_outline(unit):
	var obstacle = unit.get_node_or_null("MovementObstacle") if is_instance_valid(unit) else null
	if obstacle == null or not "footprint" in obstacle:
		return PackedVector2Array()
	return obstacle.footprint


static func has_outline(unit):
	return not local_outline(unit).is_empty()


# World XZ polygon for an outline placed with `transform`.
static func outline_at(outline, transform: Transform3D):
	var result = PackedVector2Array()
	for point in outline:
		var world = transform * Vector3(point.x, 0, point.y)
		result.append(Vector2(world.x, world.z))
	return result


static func world_outline(unit):
	return outline_at(local_outline(unit), unit.global_transform)


# Nearest point of the unit's footprint to `point` (the point itself when inside).
static func closest_point(unit, point: Vector3) -> Vector3:
	var polygon = world_outline(unit)
	if polygon.is_empty():
		return unit.global_position
	var flat = Vector2(point.x, point.z)
	var nearest = _closest_on_polygon(polygon, flat)
	return Vector3(nearest.x, unit.global_position.y, nearest.y)


static func reach_distance(unit, point: Vector3) -> float:
	var polygon = world_outline(unit)
	var flat = Vector2(point.x, point.z)
	if polygon.is_empty():
		return flat.distance_to(Vector2(unit.global_position.x, unit.global_position.z))
	return flat.distance_to(_closest_on_polygon(polygon, flat)) + unit.radius


static func _closest_on_polygon(polygon, flat: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(flat, polygon):
		return flat
	var best = polygon[0]
	var best_distance = INF
	for index in range(polygon.size()):
		var candidate = Geometry2D.get_closest_point_to_segment(
			flat, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		var distance = candidate.distance_squared_to(flat)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


# Whether a world polygon touches a circle (center/radius in XZ).
static func polygon_touches_circle(polygon, center: Vector2, radius: float) -> bool:
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	return _closest_on_polygon(polygon, center).distance_to(center) < radius


static func polygons_touch(first, second) -> bool:
	return not Geometry2D.intersect_polygons(first, second).is_empty()


# Points along the outline (every `spacing` metres) for navigability checks.
static func edge_samples(polygon, spacing = 1.0):
	var result = []
	for index in range(polygon.size()):
		var start = polygon[index]
		var end = polygon[(index + 1) % polygon.size()]
		var steps = maxi(1, ceili(start.distance_to(end) / spacing))
		for step in range(steps):
			result.append(start.lerp(end, float(step) / steps))
	return result
