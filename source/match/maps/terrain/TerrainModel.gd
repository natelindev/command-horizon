extends RefCounted

# Gameplay ground sampled on a 0.5 m lattice. Authored tiers, ramps and water
# beds become corner heights; cell flags mark water, fords, solid blockers and
# forest. Navigation sources, rendering, picking and sight all read this model,
# so what players see is exactly what units walk on.

const RESOLUTION = 0.5
const WATER = 1
const SOLID = 2
const FOREST = 4
const RAMP = 8
const FORD = 16
# Inaccessible ground (mesa tops with no way up): no navigation, scenery only.
const BARRIER = 32
# One cell may rise 0.5 m (45 degrees); steeper cells are cliffs.
const MAX_WALKABLE_STEP = 0.5
const WATER_DEPTH = 1.2
const FORD_DEPTH = 0.3
const FOREST_CANOPY = 4.5
# Sight broad phase: 4 m blocks record their tallest occluder and any forest.
const COARSE = 8
const NO_COVER = -1000.0

var size := Vector2.ZERO
var columns := 0
var rows := 0
var heights := PackedFloat32Array()
var flags := PackedByteArray()
var tier_step := 3.0
var min_height := 0.0
var max_height := 0.0
# Per cell: highest ground corner, and formation or forest-canopy top.
var ground_tops := PackedFloat32Array()
var cell_heights := PackedFloat32Array()
var cover_tops := PackedFloat32Array()
var coarse_columns := 0
var coarse_tops := PackedFloat32Array()
var coarse_bottoms := PackedFloat32Array()
var coarse_forest := PackedByteArray()


func _init(layout: Dictionary):
	size = layout.size
	tier_step = layout.get("tier_step", 3.0)
	columns = int(round(size.x / RESOLUTION))
	rows = int(round(size.y / RESOLUTION))
	heights.resize((columns + 1) * (rows + 1))
	heights.fill(layout.get("base_height", 0.0))
	flags.resize(columns * rows)
	for tier in layout.get("tiers", []):
		_fill_corners(tier.polygon, func(_old): return tier.height)
	for tier in layout.get("tiers", []):
		if not tier.get("walkable", true):
			_fill_cells(tier.polygon, BARRIER)
	for ramp in layout.get("ramps", []):
		_ramp(ramp)
	# Fords cross streams: they apply after open water and replace it.
	for water in layout.get("water", []):
		if not water.get("ford", false):
			_fill_corners(water.polygon, func(old): return old - WATER_DEPTH)
			_fill_cells(water.polygon, WATER)
	for water in layout.get("water", []):
		if water.get("ford", false):
			var bed = water.get("level", 0.0) - FORD_DEPTH
			_fill_corners(water.polygon, func(_old): return bed)
			_fill_cells(water.polygon, FORD, WATER)
	cover_tops.resize(columns * rows)
	cover_tops.fill(NO_COVER)
	for forest in layout.get("forests", []):
		_fill_cells(forest.polygon, FOREST)
	for blocker in layout.get("blockers", []):
		var base = INF
		for point in blocker.polygon:
			base = minf(base, height_at(point))
		_fill_cells(blocker.polygon, SOLID, 0, base + blocker.height)
	_index_sight()
	min_height = INF
	max_height = -INF
	for height in heights:
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)


func height_at(point: Vector2) -> float:
	var x = clampf(point.x / RESOLUTION, 0.0, columns)
	var z = clampf(point.y / RESOLUTION, 0.0, rows)
	var i = mini(int(x), columns - 1)
	var j = mini(int(z), rows - 1)
	var fx = x - i
	var fz = z - j
	var top = lerpf(_corner(i, j), _corner(i + 1, j), fx)
	var bottom = lerpf(_corner(i, j + 1), _corner(i + 1, j + 1), fx)
	return lerpf(top, bottom, fz)


func tier_at(point: Vector2) -> int:
	return roundi(height_at(point) / tier_step)


func flag_at(point: Vector2) -> int:
	var i = clampi(int(point.x / RESOLUTION), 0, columns - 1)
	var j = clampi(int(point.y / RESOLUTION), 0, rows - 1)
	return flags[j * columns + i]


func is_walkable_cell(i: int, j: int) -> bool:
	var cell = flags[j * columns + i]
	if cell & (WATER | SOLID | BARRIER):
		return false
	var a = _corner(i, j)
	var b = _corner(i + 1, j)
	var c = _corner(i + 1, j + 1)
	var d = _corner(i, j + 1)
	return (
		absf(a - b) <= MAX_WALKABLE_STEP
		and absf(b - c) <= MAX_WALKABLE_STEP
		and absf(c - d) <= MAX_WALKABLE_STEP
		and absf(d - a) <= MAX_WALKABLE_STEP
	)


# Walkable triangles for the navigation bake. Level runs along each row merge
# into single quads so rebakes stay cheap; slopes keep their own cells and
# cliffs, water and solid blockers are omitted entirely.
func navigation_faces() -> PackedVector3Array:
	var faces = PackedVector3Array()
	var stride = columns + 1
	for j in rows:
		var run_start = -1
		var run_height = 0.0
		for i in columns:
			var index = j * stride + i
			var a = heights[index]
			var b = heights[index + 1]
			var c = heights[index + stride + 1]
			var d = heights[index + stride]
			var walkable = (
				flags[j * columns + i] & (WATER | SOLID | BARRIER) == 0
				and absf(a - b) <= MAX_WALKABLE_STEP
				and absf(b - c) <= MAX_WALKABLE_STEP
				and absf(c - d) <= MAX_WALKABLE_STEP
				and absf(d - a) <= MAX_WALKABLE_STEP
			)
			var level = walkable and a == b and a == c and a == d
			if run_start >= 0 and not (level and a == run_height):
				_quad_faces(faces, run_start, i, j, run_height)
				run_start = -1
			if level:
				if run_start < 0:
					run_start = i
					run_height = a
			elif walkable:
				_slope_faces(faces, i, j)
		if run_start >= 0:
			_quad_faces(faces, run_start, columns, j, run_height)
	return faces


func _corner(i: int, j: int) -> float:
	return heights[j * (columns + 1) + i]


# Winding matches Geometry2D.triangulate_polygon output used by flat maps.
func _quad_faces(faces: PackedVector3Array, start: int, end: int, j: int, height: float):
	var x0 = start * RESOLUTION
	var x1 = end * RESOLUTION
	var z0 = j * RESOLUTION
	var z1 = (j + 1) * RESOLUTION
	var a = Vector3(x0, height, z0)
	var b = Vector3(x1, height, z0)
	var c = Vector3(x1, height, z1)
	var d = Vector3(x0, height, z1)
	faces.append_array([d, a, b, b, c, d])


func _slope_faces(faces: PackedVector3Array, i: int, j: int):
	var x0 = i * RESOLUTION
	var z0 = j * RESOLUTION
	var a = Vector3(x0, _corner(i, j), z0)
	var b = Vector3(x0 + RESOLUTION, _corner(i + 1, j), z0)
	var c = Vector3(x0 + RESOLUTION, _corner(i + 1, j + 1), z0 + RESOLUTION)
	var d = Vector3(x0, _corner(i, j + 1), z0 + RESOLUTION)
	faces.append_array([d, a, b, b, c, d])


func _ramp(ramp: Dictionary):
	var a: Vector2 = ramp.from
	var b: Vector2 = ramp.to
	var axis = b - a
	var length_squared = axis.length_squared()
	var half_width = ramp.width / 2.0
	var normal = axis.orthogonal().normalized()
	var reach = half_width + axis.length()
	var low = (a.min(b) - Vector2.ONE * reach).max(Vector2.ZERO)
	var high = (a.max(b) + Vector2.ONE * reach).min(size)
	for j in range(int(low.y / RESOLUTION), int(high.y / RESOLUTION) + 1):
		for i in range(int(low.x / RESOLUTION), int(high.x / RESOLUTION) + 1):
			var point = Vector2(i, j) * RESOLUTION
			var t = (point - a).dot(axis) / length_squared
			if t < 0.0 or t > 1.0 or absf((point - a).dot(normal)) > half_width:
				continue
			heights[j * (columns + 1) + i] = lerpf(ramp.from_height, ramp.to_height, t)
			if i < columns and j < rows:
				flags[j * columns + i] |= RAMP


# Even-odd scanline fill of lattice corners inside `polygon`.
func _fill_corners(polygon: PackedVector2Array, value: Callable):
	for j in rows + 1:
		for span in _spans(polygon, j * RESOLUTION):
			for i in range(ceili(span.x / RESOLUTION), floori(span.y / RESOLUTION) + 1):
				if i < 0 or i > columns:
					continue
				var index = j * (columns + 1) + i
				heights[index] = value.call(heights[index])


# Even-odd scanline fill of cells whose centres lie inside `polygon`.
func _fill_cells(polygon: PackedVector2Array, flag: int, cleared := 0, cover := NO_COVER):
	for j in rows:
		for span in _spans(polygon, (j + 0.5) * RESOLUTION):
			var first = maxi(ceili(span.x / RESOLUTION - 0.5), 0)
			var last = mini(floori(span.y / RESOLUTION - 0.5), columns - 1)
			for i in range(first, last + 1):
				flags[j * columns + i] = (flags[j * columns + i] & ~cleared) | flag
				if cover > NO_COVER:
					cover_tops[j * columns + i] = cover


func cell_index(point: Vector2) -> int:
	var i = clampi(int(point.x / RESOLUTION), 0, columns - 1)
	var j = clampi(int(point.y / RESOLUTION), 0, rows - 1)
	return j * columns + i


func coarse_index(point: Vector2) -> int:
	var i = clampi(int(point.x / (RESOLUTION * COARSE)), 0, coarse_columns - 1)
	var j = clampi(int(point.y / (RESOLUTION * COARSE)), 0, coarse_tops.size() / coarse_columns - 1)
	return j * coarse_columns + i


func _index_sight():
	var stride = columns + 1
	ground_tops.resize(columns * rows)
	cell_heights.resize(columns * rows)
	for j in rows:
		for i in columns:
			var index = j * stride + i
			var cell = j * columns + i
			ground_tops[cell] = maxf(
				maxf(heights[index], heights[index + 1]),
				maxf(heights[index + stride], heights[index + stride + 1])
			)
			cell_heights[cell] = (
				(
					heights[index]
					+ heights[index + 1]
					+ heights[index + stride]
					+ heights[index + stride + 1]
				)
				/ 4.0
			)
			if flags[cell] & FOREST and cover_tops[cell] == NO_COVER:
				cover_tops[cell] = ground_tops[cell] + FOREST_CANOPY
	coarse_columns = ceili(float(columns) / COARSE)
	var coarse_rows = ceili(float(rows) / COARSE)
	coarse_tops.resize(coarse_columns * coarse_rows)
	coarse_tops.fill(NO_COVER)
	coarse_bottoms.resize(coarse_columns * coarse_rows)
	coarse_bottoms.fill(-NO_COVER)
	coarse_forest.resize(coarse_columns * coarse_rows)
	coarse_forest.fill(0)
	for j in rows:
		for i in columns:
			var cell = j * columns + i
			var block = (j / COARSE) * coarse_columns + i / COARSE
			coarse_tops[block] = maxf(coarse_tops[block], maxf(ground_tops[cell], cover_tops[cell]))
			coarse_bottoms[block] = minf(coarse_bottoms[block], heights[j * stride + i])
			if flags[cell] & FOREST:
				coarse_forest[block] = 1


func _spans(polygon: PackedVector2Array, z: float) -> Array:
	var crossings = []
	for index in polygon.size():
		var a = polygon[index]
		var b = polygon[(index + 1) % polygon.size()]
		if (a.y <= z and b.y > z) or (b.y <= z and a.y > z):
			crossings.append(a.x + (z - a.y) / (b.y - a.y) * (b.x - a.x))
	crossings.sort()
	var spans = []
	for index in range(0, crossings.size() - 1, 2):
		spans.append(Vector2(crossings[index], crossings[index + 1]))
	return spans
