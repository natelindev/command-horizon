extends RefCounted

# Baked once per authored map. RG = current (m/s), B = effective depth,
# A = wet mask. The field is presentation data; terrain/navigation stay authoritative.
const RESOLUTION = 256
const Dressing = preload("res://source/match/maps/terrain/TerrainDressing.gd")
var image: Image
var texture: ImageTexture
var size = Vector2.ONE
var waters = []
var blockers = []


func build(layout: Dictionary):
	size = layout.size
	waters = layout.get("water", []).filter(func(w): return not w.get("lava", false))
	blockers = layout.get("blockers", []).duplicate()
	# These are the same solid footprints used by movement obstacles. Openings
	# stay open; purely decorative foliage does not obstruct a whole channel.
	for entry in layout.get("landmarks", []):
		if entry.has("solid"):
			blockers.append({"center": entry.position, "radius": entry.solid})
		for outline in entry.get("footprints", []):
			var polygon = PackedVector2Array()
			for p in outline:
				polygon.append(
					entry.position + p.rotated(deg_to_rad(Dressing.heading(layout, entry)))
				)
			blockers.append({"polygon": polygon})
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAF)
	image.fill(Color(0, 0, 0, 0))
	# Rasterize only wet bounding boxes, then resolve overlaps with one query.
	var visited = PackedByteArray()
	visited.resize(RESOLUTION * RESOLUTION)
	for water in waters:
		if water.get("ford", false):
			continue
		var bounds = Rect2(water.polygon[0], Vector2.ZERO)
		for p in water.polygon:
			bounds = bounds.expand(p)
		var lo = Vector2i((bounds.position / size * RESOLUTION).floor()).clamp(
			Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1)
		)
		var hi = Vector2i((bounds.end / size * RESOLUTION).ceil()).clamp(
			Vector2i.ZERO, Vector2i.ONE * (RESOLUTION - 1)
		)
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var index = y * RESOLUTION + x
				if visited[index]:
					continue
				visited[index] = 1
				image.set_pixel(x, y, sample((Vector2(x, y) + Vector2(.5, .5)) / RESOLUTION * size))
	texture = ImageTexture.create_from_image(image)


func sample(point: Vector2) -> Color:
	var wet = {}
	var shallow = false
	for water in waters:
		if Geometry2D.is_point_in_polygon(point, water.polygon):
			if water.get("ford", false):
				shallow = true
			else:
				wet = water
	if wet.is_empty():
		return Color(0, 0, 0, 0)
	var velocity = _current(point, wet)
	# Bank tangents stop texture advection from visibly crossing solid banks.
	velocity = _along_boundary(point, wet.polygon, velocity)
	for blocker in blockers:
		if blocker.has("polygon"):
			if Geometry2D.is_point_in_polygon(point, blocker.polygon):
				return Color(0, 0, 0, 0)
			velocity = _along_boundary(point, blocker.polygon, velocity)
		elif blocker.has("radius"):
			var offset: Vector2 = point - blocker.center
			var radius: float = blocker.radius
			if offset.length() < radius:
				return Color(0, 0, 0, 0)
			# Potential-flow deflection around a cylinder, smoothly approaching
			# the authored current away from a pier/rock.
			var normal = offset.normalized()
			velocity += (
				radius
				* radius
				/ maxf(offset.length_squared(), .01)
				* (velocity - 2.0 * velocity.dot(normal) * normal)
			)
	velocity = _along_boundary(point, wet.polygon, velocity).limit_length(2.5)
	return Color(velocity.x, velocity.y, .18 if shallow else 1.2, 1.0)


func level_at(point: Vector2) -> float:
	var level = -INF
	var ford_level = -INF
	for water in waters:
		if Geometry2D.is_point_in_polygon(point, water.polygon):
			if water.get("ford", false):
				ford_level = maxf(ford_level, water.get("level", 0.0) - .08)
			else:
				level = maxf(level, water.get("level", 0.0) - .3)
	return maxf(level, ford_level) if is_finite(level) else -INF


func _current(point: Vector2, water: Dictionary) -> Vector2:
	var line = water.get("line", [])
	var nearest = INF
	var direction = Vector2.RIGHT
	for index in range(line.size() - 1):
		var closest = Geometry2D.get_closest_point_to_segment(point, line[index], line[index + 1])
		if point.distance_squared_to(closest) < nearest:
			nearest = point.distance_squared_to(closest)
			direction = (line[index + 1] - line[index]).normalized()
	return direction * water.get("flow_speed", 1.2 if line.size() >= 2 else .25)


func _along_boundary(point: Vector2, polygon: PackedVector2Array, velocity: Vector2) -> Vector2:
	var nearest = INF
	var normal = Vector2.ZERO
	for index in polygon.size():
		var closest = Geometry2D.get_closest_point_to_segment(
			point, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		var offset = point - closest
		if offset.length_squared() < nearest:
			nearest = offset.length_squared()
			normal = offset.normalized()
	return velocity - normal * velocity.dot(normal) * (1.0 - smoothstep(0.0, 3.0, sqrt(nearest)))
