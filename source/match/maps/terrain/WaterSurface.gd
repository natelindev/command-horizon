extends RefCounted

# Render-only river coordinates: X is distance downstream, Y is distance
# across the channel. Bends and mirrored map sectors carry the current with
# them. A small indexed mesh lets the water itself rise and fall as it flows.
const SPACING = 3.0
const FORD_BLEND_MARGIN = 4.0
var speed = .25
var _vertices = PackedVector3Array()
var _uv = PackedVector2Array()
var _directions = PackedVector2Array()
var _indices = PackedInt32Array()
var _amplitudes = PackedColorArray()
var _fords = []
var _lookup = {}
var _line = PackedVector2Array()
var _level = 0.0


func build(water: Dictionary, waters: Array, level: float) -> ArrayMesh:
	_level = level
	_fords = waters.filter(func(w): return w.get("ford", false))
	_line = PackedVector2Array(water.get("line", []))
	var polygon: PackedVector2Array = water.polygon
	var center = Vector2.ZERO
	for point in polygon:
		center += point
	center /= polygon.size()
	# Fords are a separate shallow surface on top of their river bed. They
	# inherit its path instead of flowing sideways across the crossing.
	if _line.is_empty() and water.get("ford", false):
		var nearest = INF
		for other in waters:
			var path = PackedVector2Array(other.get("line", []))
			for index in range(path.size() - 1):
				var point = Geometry2D.get_closest_point_to_segment(
					center, path[index], path[index + 1]
				)
				var distance = center.distance_to(point)
				if distance < nearest:
					nearest = distance
					_line = path
	speed = water.get("flow_speed", 1.2 if _line.size() >= 2 else .25)
	if _line.size() < 2:
		var bounds = Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		var direction = Vector2.RIGHT if bounds.size.x >= bounds.size.y else Vector2.DOWN
		_line = PackedVector2Array([center - direction * 512.0, center + direction * 512.0])
	var triangles = Geometry2D.triangulate_polygon(polygon)
	for index in range(0, triangles.size(), 3):
		_triangle(
			polygon[triangles[index]], polygon[triangles[index + 1]], polygon[triangles[index + 2]]
		)
	var normals = PackedVector3Array()
	normals.resize(_vertices.size())
	normals.fill(Vector3.UP)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _directions
	arrays[Mesh.ARRAY_INDEX] = _indices
	arrays[Mesh.ARRAY_COLOR] = _amplitudes
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _triangle(a: Vector2, b: Vector2, c: Vector2):
	var ab = a.distance_squared_to(b)
	var bc = b.distance_squared_to(c)
	var ca = c.distance_squared_to(a)
	if maxf(ab, maxf(bc, ca)) <= SPACING * SPACING:
		for point in [a, b, c]:
			_indices.append(_vertex(point))
	elif ab >= bc and ab >= ca:
		var middle = (a + b) * .5
		_triangle(a, middle, c)
		_triangle(middle, b, c)
	elif bc >= ca:
		var middle = (b + c) * .5
		_triangle(a, b, middle)
		_triangle(a, middle, c)
	else:
		var middle = (c + a) * .5
		_triangle(a, b, middle)
		_triangle(middle, b, c)


func _vertex(point: Vector2) -> int:
	if _lookup.has(point):
		return _lookup[point]
	var nearest = INF
	var distance_along = 0.0
	var coordinates = Vector2.ZERO
	var direction = Vector2.RIGHT
	for index in range(_line.size() - 1):
		var a = _line[index]
		var b = _line[index + 1]
		var closest = Geometry2D.get_closest_point_to_segment(point, a, b)
		var offset = point - closest
		if offset.length_squared() < nearest:
			nearest = offset.length_squared()
			direction = (b - a).normalized()
			coordinates = Vector2(distance_along + a.distance_to(closest), direction.cross(offset))
		distance_along += a.distance_to(b)
	var result = _vertices.size()
	_lookup[point] = result
	var surface_level = _level
	var amplitude = 1.0
	for ford in _fords:
		var ford_level = maxf(surface_level, ford.get("level", 0.0) - .08)
		if Geometry2D.is_point_in_polygon(point, ford.polygon):
			surface_level = ford_level
			amplitude = .18
		else:
			var dist = _distance_to_polygon(point, ford.polygon)
			if dist < FORD_BLEND_MARGIN:
				var blend = 1.0 - smoothstep(0.0, FORD_BLEND_MARGIN, dist)
				surface_level = maxf(surface_level, lerpf(_level, ford_level, blend))
				amplitude = minf(amplitude, lerpf(1.0, .18, blend))
	_vertices.append(Vector3(point.x, surface_level, point.y))
	_amplitudes.append(Color(amplitude, 1, 1))
	_uv.append(coordinates)
	_directions.append(direction)
	return result


static func _distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	var best = INF
	for index in polygon.size():
		var closest = Geometry2D.get_closest_point_to_segment(
			point, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		best = minf(best, point.distance_squared_to(closest))
	return sqrt(best)
