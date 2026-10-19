extends RefCounted

# Renderable ground for an authored battlefield: the gameplay lattice plus
# restrained surface relief, extended past the playable edge, and a control
# texture (2 px/m) that tells the terrain shader, minimap and previews where
# roads, water, fords and forest floor lie.

const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const MARGIN = 6.0
# Visual relief stays well inside unit footprints on walkable ground.
const WALKABLE_RELIEF = 0.06
const ROUGH_RELIEF = 0.35
const ROAD_SOFTNESS = 1.2


static func build_mesh(model, seed_text: String) -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = seed_text.hash()
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var resolution = TerrainModel.RESOLUTION
	var margin_cells = int(MARGIN / resolution)
	var width = model.columns + 1 + margin_cells * 2
	var depth = model.rows + 1 + margin_cells * 2
	var corners: PackedFloat32Array = model.heights
	var stride: int = model.columns + 1
	var heights = PackedFloat32Array()
	heights.resize(width * depth)
	for row in depth:
		var j: int = clampi(row - margin_cells, 0, model.rows)
		var outside_row = row < margin_cells or row > model.rows + margin_cells
		for column in width:
			var i: int = clampi(column - margin_cells, 0, model.columns)
			var index: int = j * stride + i
			var height: float = corners[index]
			var amplitude = WALKABLE_RELIEF
			# Cliff faces, their lips and ground beyond the edge read as rough rock.
			if (
				outside_row
				or column < margin_cells
				or column > model.columns + margin_cells
				or (i > 0 and absf(corners[index - 1] - height) > TerrainModel.MAX_WALKABLE_STEP)
				or (
					i < model.columns
					and absf(corners[index + 1] - height) > TerrainModel.MAX_WALKABLE_STEP
				)
				or (
					j > 0
					and absf(corners[index - stride] - height) > TerrainModel.MAX_WALKABLE_STEP
				)
				or (
					j < model.rows
					and absf(corners[index + stride] - height) > TerrainModel.MAX_WALKABLE_STEP
				)
				or _solid_corner(model, i, j)
			):
				amplitude = ROUGH_RELIEF
			heights[row * width + column] = (
				height
				+ (
					noise.get_noise_2d(
						(column - margin_cells) * resolution, (row - margin_cells) * resolution
					)
					* amplitude
				)
			)
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	vertices.resize(width * depth)
	normals.resize(width * depth)
	for row in depth:
		for column in width:
			var index = row * width + column
			var left = heights[row * width + maxi(column - 1, 0)]
			var right = heights[row * width + mini(column + 1, width - 1)]
			var up = heights[maxi(row - 1, 0) * width + column]
			var down = heights[mini(row + 1, depth - 1) * width + column]
			vertices[index] = Vector3(
				(column - margin_cells) * resolution,
				heights[index],
				(row - margin_cells) * resolution
			)
			normals[index] = Vector3(left - right, 2.0 * resolution, up - down).normalized()
	var indices = PackedInt32Array()
	indices.resize((width - 1) * (depth - 1) * 6)
	var cursor = 0
	for row in depth - 1:
		for column in width - 1:
			var a = row * width + column
			var b = a + 1
			var d = a + width
			var c = d + 1
			# Split each quad along the diagonal that follows the surface best.
			if absf(heights[a] - heights[c]) < absf(heights[b] - heights[d]):
				indices[cursor] = a
				indices[cursor + 1] = b
				indices[cursor + 2] = c
				indices[cursor + 3] = a
				indices[cursor + 4] = c
				indices[cursor + 5] = d
			else:
				indices[cursor] = a
				indices[cursor + 1] = b
				indices[cursor + 2] = d
				indices[cursor + 3] = b
				indices[cursor + 4] = c
				indices[cursor + 5] = d
			cursor += 6
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# R: road, G: water (1) or ford (0.5), B: forest floor, A: solid ground cover.
static func build_control(model, layout: Dictionary) -> Image:
	var image = Image.create(model.columns, model.rows, false, Image.FORMAT_RGBA8)
	var resolution = TerrainModel.RESOLUTION
	var roads = PackedFloat32Array()
	roads.resize(model.columns * model.rows)
	for road in layout.get("roads", []):
		var line: PackedVector2Array = road.line
		var half = road.width / 2.0
		for index in line.size() - 1:
			var a = line[index]
			var b = line[index + 1]
			var reach = half + ROAD_SOFTNESS
			var low = (a.min(b) - Vector2.ONE * reach) / resolution
			var high = (a.max(b) + Vector2.ONE * reach) / resolution
			for j in range(maxi(int(low.y), 0), mini(int(high.y) + 1, model.rows)):
				for i in range(maxi(int(low.x), 0), mini(int(high.x) + 1, model.columns)):
					var point = (Vector2(i, j) + Vector2(0.5, 0.5)) * resolution
					var distance = point.distance_to(
						Geometry2D.get_closest_point_to_segment(point, a, b)
					)
					var strength = 1.0 - smoothstep(half - ROAD_SOFTNESS, half, distance)
					var cell = j * model.columns + i
					roads[cell] = maxf(roads[cell], strength)
	for j in model.rows:
		for i in model.columns:
			var cell = model.flags[j * model.columns + i]
			var water = (
				1.0 if cell & TerrainModel.WATER else (0.5 if cell & TerrainModel.FORD else 0.0)
			)
			image.set_pixel(
				i,
				j,
				Color(
					roads[j * model.columns + i],
					water,
					1.0 if cell & TerrainModel.FOREST else 0.0,
					1.0 if cell & TerrainModel.SOLID else 0.0
				)
			)
	return image


static func _inside(point: Vector2, size: Vector2) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x <= size.x and point.y <= size.y


static func _solid_corner(model, i: int, j: int) -> bool:
	var cell = mini(j, model.rows - 1) * model.columns + mini(i, model.columns - 1)
	return model.flags[cell] & TerrainModel.SOLID != 0
