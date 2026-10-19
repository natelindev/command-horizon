extends RefCounted

# Scenery beyond the playable rectangle: a ring of landscape that continues
# from the battlefield's edge heights and rises into terraced mesas and cliff
# bands, so the map sits inside a region rather than on a slab. It uses the
# map's ground shader, is never walkable or clickable and costs one draw call.

const INNER = 6.0
const OUTER = 70.0
const STEP = 2.0
const TERRACE = 4.0


static func build(model, profile: Dictionary, seed_text: String) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = ("%s-backdrop" % seed_text).hash()
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	var size: Vector2 = model.size
	var low = Vector2.ONE * -OUTER
	var columns = int((size.x + OUTER * 2.0) / STEP) + 1
	var rows = int((size.y + OUTER * 2.0) / STEP) + 1
	var rise: float = profile.get("rise", 14.0)
	var heights = PackedFloat32Array()
	heights.resize(columns * rows)
	for row in rows:
		for column in columns:
			var point = low + Vector2(column, row) * STEP
			var edge = point.clamp(Vector2.ZERO, size)
			var outside = point.distance_to(edge)
			var base = model.height_at(edge)
			var lift = smoothstep(INNER, INNER + 18.0, outside)
			var shape = (noise.get_noise_2dv(point) * 0.5 + 0.5) * rise * 1.6 * lift
			shape += lift * rise * 0.35
			heights[row * columns + column] = base + _terraced(shape)
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows - 1:
		for column in columns - 1:
			var corners = [
				Vector2i(column, row),
				Vector2i(column + 1, row),
				Vector2i(column + 1, row + 1),
				Vector2i(column, row + 1)
			]
			var centre = low + (Vector2(column, row) + Vector2(0.5, 0.5)) * STEP
			# Leave the battlefield and its margin to the gameplay terrain.
			if Rect2(Vector2.ONE * -INNER, size + Vector2.ONE * INNER * 2.0).has_point(centre):
				continue
			var points = []
			for corner in corners:
				var flat = low + Vector2(corner) * STEP
				points.append(Vector3(flat.x, heights[corner.y * columns + corner.x], flat.y))
			for index in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()


# Flat benches separated by steep risers read as eroded mesas and cliffs.
static func _terraced(height: float) -> float:
	var level = floorf(height / TERRACE)
	var rest = height / TERRACE - level
	return (level + smoothstep(0.62, 0.92, rest)) * TERRACE
