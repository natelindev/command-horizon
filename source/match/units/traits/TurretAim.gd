extends RefCounted


## World targets are converted through the live articulated parent transform,
## independent of the hull's heading, suspension and interpolated visual pose.
static func bearing(local_offset: Vector3) -> float:
	return atan2(-local_offset.x, -local_offset.z)


static func elevation(local_offset: Vector3, minimum = -.15, maximum = .65) -> float:
	return clampf(
		atan2(local_offset.y, Vector2(local_offset.x, local_offset.z).length()), minimum, maximum
	)


static func within_arc(bearing_value: float, center: float, half_arc: float) -> float:
	return center + clampf(angle_difference(center, bearing_value), -half_arc, half_arc)
