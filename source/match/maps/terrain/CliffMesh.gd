extends RefCounted

# Rock faces for authored terrain. The gameplay lattice steps cliffs in
# 0.5 m cells; these meshes follow the true (roughened) outlines instead: a cap
# lip that hides the lattice edge, a near-vertical upper face, a ledge and a
# talus apron at the foot. Tier edges, ramp side cuts and solid formations
# (with a capstone) all use the same profile and the canyon rock shader.

const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const MIN_DROP = 1.0
const MAX_SEGMENT = 2.0
const LIP = 0.8
const CAP_LIFT = 0.04


# Features may name another rock ("rock": "ice"); each variant is its own mesh
# so it takes its own material. Ramp cuts belong to the map's own rock.
static func variants(layout: Dictionary) -> Array:
	var found = [""]
	for key in ["tiers", "blockers"]:
		for entry in layout.get(key, []):
			if not entry.get("rock", "") in found:
				found.append(entry.rock)
	return found


static func build(model, layout: Dictionary, seed_text: String, variant := "") -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = seed_text.hash()
	noise.frequency = 0.35
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces = 0
	for tier in layout.get("tiers", []):
		# Smooth mounds (falloff) have no rock faces.
		if not tier.has("falloff") and tier.get("rock", "") == variant:
			faces += 1
			_outline_faces(tool, model, tier.polygon, noise, INF, layout.get("base_height", 0.0))
	for blocker in layout.get("blockers", []):
		if blocker.get("rock", "") != variant:
			continue
		faces += 1
		var base = INF
		for point in blocker.polygon:
			base = minf(base, model.height_at(point))
		var top = base + blocker.height
		_outline_faces(tool, model, blocker.polygon, noise, top)
		_capstone(tool, blocker.polygon, top, noise)
	if variant == "":
		for ramp in layout.get("ramps", []):
			faces += 1
			_ramp_cuts(tool, model, ramp, noise)
	if faces == 0:
		return null
	tool.generate_normals()
	return tool.commit()


# Walls along an outline wherever the inside stands at least MIN_DROP above
# the outside. `fixed_top` (formations) overrides the sampled inside height.
# A sunken tier (gorge, wadi, quay basin) gets inward-facing walls where the
# ground around it is base ground; a raised neighbour builds its own wall.
static func _outline_faces(
	tool, model, polygon: PackedVector2Array, noise, fixed_top: float, base := INF
):
	var outward_sign = -1.0 if Geometry2D.is_polygon_clockwise(polygon) else 1.0
	var points = densified(polygon)
	var count = points.size()
	for index in count:
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % count]
		if a.distance_to(b) < 0.05:
			continue
		var normal_a = vertex_normal(points, index, outward_sign)
		var normal_b = vertex_normal(points, (index + 1) % count, outward_sign)
		var top_a = fixed_top if fixed_top < INF else model.height_at(a - normal_a * 1.0)
		var top_b = fixed_top if fixed_top < INF else model.height_at(b - normal_b * 1.0)
		var bottom_a = model.height_at(a + normal_a * 1.2)
		var bottom_b = model.height_at(b + normal_b * 1.2)
		if top_a - bottom_a >= MIN_DROP and top_b - bottom_b >= MIN_DROP:
			_face(tool, [a, b], [normal_a, normal_b], [top_a, top_b], [bottom_a, bottom_b], noise)
			continue
		if fixed_top < INF:
			continue
		var rim_a = model.height_at(a + normal_a * 1.0)
		var rim_b = model.height_at(b + normal_b * 1.0)
		var floor_a = model.height_at(a - normal_a * 1.2)
		var floor_b = model.height_at(b - normal_b * 1.2)
		if (
			rim_a - floor_a >= MIN_DROP
			and rim_b - floor_b >= MIN_DROP
			and maxf(rim_a, rim_b) <= base + 0.25
		):
			_face(tool, [b, a], [-normal_b, -normal_a], [rim_b, rim_a], [floor_b, floor_a], noise)


static func _ramp_cuts(tool, model, ramp: Dictionary, noise):
	var axis: Vector2 = ramp.to - ramp.from
	var side = axis.orthogonal().normalized()
	var length = axis.length()
	var steps = maxi(2, ceili(length / MAX_SEGMENT))
	for direction in [-1.0, 1.0]:
		var normal = side * direction
		for step in steps:
			var t0 = float(step) / steps
			var t1 = float(step + 1) / steps
			var a = ramp.from + axis * t0 + normal * (ramp.width / 2.0)
			var b = ramp.from + axis * t1 + normal * (ramp.width / 2.0)
			var ramp_a = lerpf(ramp.from_height, ramp.to_height, t0)
			var ramp_b = lerpf(ramp.from_height, ramp.to_height, t1)
			var outside_a = model.height_at(a + normal * 1.2)
			var outside_b = model.height_at(b + normal * 1.2)
			# The plateau stands above a ramp cut into it: wall faces the ramp.
			if outside_a - ramp_a >= MIN_DROP and outside_b - ramp_b >= MIN_DROP:
				_face(
					tool,
					[b, a],
					[-normal, -normal],
					[outside_b, outside_a],
					[ramp_b, ramp_a],
					noise
				)
			# A ramp built out over low ground: embankment faces outward.
			elif ramp_a - outside_a >= MIN_DROP and ramp_b - outside_b >= MIN_DROP:
				_face(
					tool, [a, b], [normal, normal], [ramp_a, ramp_b], [outside_a, outside_b], noise
				)


# One column per end: cap lip inside, vertical upper face, ledge, talus apron.
static func _face(tool, ends: Array, normals: Array, tops: Array, bottoms: Array, noise):
	var columns = []
	for side in 2:
		var point: Vector2 = ends[side]
		var normal: Vector2 = normals[side]
		var top: float = tops[side]
		var bottom: float = bottoms[side]
		var drop = top - bottom
		var wobble = noise.get_noise_2dv(point)
		var ledge = 0.25 + 0.2 * noise.get_noise_2dv(point * 1.7 + Vector2(31, 7))
		var profile = [
			[-LIP, top + CAP_LIFT],
			[0.0, top + CAP_LIFT],
			[0.12 + wobble * 0.12, top - drop * 0.3],
			[ledge, top - drop * 0.55],
			[ledge + 0.18, top - drop * 0.78],
			[ledge + 0.7 + absf(wobble) * 0.6, bottom - 0.15],
		]
		var column = []
		for entry in profile:
			var flat = point + normal * entry[0]
			column.append(Vector3(flat.x, entry[1], flat.y))
		columns.append(column)
	# Clockwise seen from the face's outer side (Godot's front face), so
	# generated normals point out of the rock and level lips face up.
	for row in columns[0].size() - 1:
		var a: Vector3 = columns[0][row]
		var b: Vector3 = columns[1][row]
		var c: Vector3 = columns[1][row + 1]
		var d: Vector3 = columns[0][row + 1]
		for vertex in [a, c, b, a, d, c]:
			tool.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
			tool.add_vertex(vertex)


# Slightly domed, weathered top of a solid formation.
static func _capstone(tool, polygon: PackedVector2Array, top: float, noise):
	var outline = polygon
	if Geometry2D.is_polygon_clockwise(outline):
		outline = outline.duplicate()
		outline.reverse()
	var centre = Vector2.ZERO
	for point in outline:
		centre += point
	centre /= outline.size()
	var indices = Geometry2D.triangulate_polygon(outline)
	for index in indices:
		var point = outline[index]
		var rise = 0.35 * clampf(1.0 - point.distance_to(centre) / 12.0, 0.0, 1.0)
		var vertex = Vector3(
			point.x, top + CAP_LIFT + rise + noise.get_noise_2dv(point) * 0.1, point.y
		)
		tool.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		tool.add_vertex(vertex)


static func densified(polygon: PackedVector2Array, step := MAX_SEGMENT) -> PackedVector2Array:
	var result = PackedVector2Array()
	for index in polygon.size():
		var a = polygon[index]
		var b = polygon[(index + 1) % polygon.size()]
		var pieces = maxi(1, ceili(a.distance_to(b) / step))
		for piece in pieces:
			result.append(a.lerp(b, float(piece) / pieces))
	return result


static func vertex_normal(points: PackedVector2Array, index: int, outward_sign: float) -> Vector2:
	var previous = points[(index - 1 + points.size()) % points.size()]
	var current = points[index]
	var following = points[(index + 1) % points.size()]
	var edge_in = (current - previous).orthogonal().normalized()
	var edge_out = (following - current).orthogonal().normalized()
	var normal = (edge_in + edge_out).normalized() * outward_sign
	return normal if normal.is_finite() and normal.length() > 0.5 else edge_out * outward_sign
