extends RefCounted

# Sight on authored terrain. Battle visibility (Battlefield.gd) and the fog of
# war display share these rules so the revealed map matches what units see:
# - ground, cliffs and solid formations block sight lines;
# - forest canopy hides what lies more than FOREST_SEE metres inside it;
# - ground observers cannot see up onto a higher tier beyond close range.
# Aircraft see over forest and up onto every tier.

const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const EYE = 0.8
const FOREST_SEE = 3.0
const HIGH_GROUND = 1.5
const HIGH_GROUND_REVEAL = 1.5
# Samples this close to either end belong to the observer's or target's own
# footing (ramps, relief) and never occlude.
const END_CLEARANCE = 0.75
const STEP = 0.5
const COARSE_STEP = 1.0
const REVEAL_RAYS = 48
const LEVEL = 0.4


static func high_ground_hidden(model, observer: Vector2, target: Vector2) -> bool:
	return (
		model.height_at(target) - model.height_at(observer) >= HIGH_GROUND
		and observer.distance_to(target) > HIGH_GROUND_REVEAL
	)


# `forest_blocks` is false for aircraft and for physical shots.
static func segment_clear(model, origin: Vector3, end: Vector3, forest_blocks := true) -> bool:
	var a = Vector2(origin.x, origin.z)
	var b = Vector2(end.x, end.z)
	var length = a.distance_to(b)
	if length <= END_CLEARANCE * 2.0:
		return true
	if _coarse_clear(model, a, b, length, minf(origin.y, end.y), forest_blocks):
		return true
	var steps = ceili(length / STEP)
	for step in range(1, steps):
		var t = float(step) / steps
		var distance = t * length
		var from_end = minf(distance, length - distance)
		var point = a.lerp(b, t)
		var line = lerpf(origin.y, end.y, t)
		var cell = model.cell_index(point)
		if from_end > END_CLEARANCE and model.ground_tops[cell] > line:
			return false
		if model.cover_tops[cell] > line:
			if model.flags[cell] & TerrainModel.SOLID:
				return false
			if forest_blocks and from_end > FOREST_SEE:
				return false
	return true


# Fog-of-war reveal of a ground unit at `centre`, as a triangle list in world
# XZ: one wedge per ray and visible interval, so dead ground below a cliff can
# be hidden while ground beyond it shows. Consistent with segment_clear and
# the high-ground rule. Empty when nothing within reach can occlude (draw a
# plain circle). Aircraft always reveal their full circle.
# Optional level_reach limits the extended ring to lower ground.
static func reveal_triangles(
	model, centre: Vector2, reach: float, level_reach := -1.0
) -> PackedVector2Array:
	var ground = model.height_at(centre)
	var triangles = PackedVector2Array()
	if level_reach < 0.0 and _open_circle(model, centre, reach, ground):
		return triangles
	var half = PI / REVEAL_RAYS
	for ray in REVEAL_RAYS:
		var angle = ray * TAU / REVEAL_RAYS
		var left = Vector2.from_angle(angle - half)
		var right = Vector2.from_angle(angle + half)
		var intervals = _visible_intervals(
			model, centre, Vector2.from_angle(angle), ground, reach, level_reach
		)
		for index in range(0, intervals.size(), 2):
			var near = intervals[index]
			var far = intervals[index + 1]
			if near <= 0.0:
				triangles.append_array([centre, centre + left * far, centre + right * far])
			else:
				var a = centre + left * near
				var b = centre + right * near
				var c = centre + right * far
				var d = centre + left * far
				triangles.append_array([a, b, c, a, c, d])
	return triangles


# Visible [start, end] distances along one ray, flattened. Sampling and rules
# mirror segment_clear: a target is seen when its eye clears the steepest
# occluder before it, it is not inside forest beyond FOREST_SEE, and it is not
# on markedly higher ground beyond close range.
static func _visible_intervals(
	model, centre, direction, ground, reach, level_reach := -1.0
) -> PackedFloat32Array:
	var intervals = PackedFloat32Array()
	var eye: float = ground + EYE
	var horizon := -INF
	var forest_from := INF
	var ground_tops: PackedFloat32Array = model.ground_tops
	var floors: PackedFloat32Array = model.cell_heights
	var cover_tops: PackedFloat32Array = model.cover_tops
	var flags: PackedByteArray = model.flags
	var columns: int = model.columns
	var last_column: int = columns - 1
	var last_row: int = model.rows - 1
	var open_from := 0.0
	var is_open := true
	var distance := STEP
	while distance <= reach:
		var x: float = centre.x + direction.x * distance
		var z: float = centre.y + direction.y * distance
		var cell: int = (
			clampi(int(z / TerrainModel.RESOLUTION), 0, last_row) * columns
			+ clampi(int(x / TerrainModel.RESOLUTION), 0, last_column)
		)
		var top: float = ground_tops[cell]
		var floor_height: float = floors[cell]
		var flag: int = flags[cell]
		if flag & TerrainModel.FOREST and distance > FOREST_SEE:
			forest_from = minf(forest_from, distance)
		var visible: bool = (
			(distance <= END_CLEARANCE or (floor_height + EYE - eye) / distance >= horizon)
			and (
				level_reach < 0.0 or distance <= level_reach or ground - floor_height >= HIGH_GROUND
			)
			and distance < forest_from + FOREST_SEE
			and not (floor_height - ground >= HIGH_GROUND and distance > HIGH_GROUND_REVEAL)
			and not (flag & TerrainModel.SOLID and cover_tops[cell] > eye)
		)
		if visible and not is_open:
			open_from = distance - STEP * 0.5
			is_open = true
		elif not visible and is_open:
			intervals.append_array([open_from, distance - STEP * 0.5])
			is_open = false
		if distance > END_CLEARANCE:
			horizon = maxf(horizon, (top - eye) / distance)
		if flag & TerrainModel.SOLID and cover_tops[cell] > eye:
			break
		distance += STEP
	if is_open:
		intervals.append_array([open_from, reach])
	return intervals


static func _coarse_clear(model, a, b, length, lowest, forest_blocks) -> bool:
	var samples = ceili(length / COARSE_STEP)
	for sample in samples + 1:
		var block = model.coarse_index(a.lerp(b, float(sample) / samples))
		if model.coarse_tops[block] > lowest:
			return false
		if forest_blocks and model.coarse_forest[block]:
			return false
	return true


# Level ground without cover within reach cannot hide anything.
static func _open_circle(model, centre: Vector2, reach: float, ground: float) -> bool:
	var low = model.coarse_index(centre - Vector2.ONE * reach)
	var high = model.coarse_index(centre + Vector2.ONE * reach)
	for row in range(low / model.coarse_columns, high / model.coarse_columns + 1):
		for column in range(low % model.coarse_columns, high % model.coarse_columns + 1):
			var block = row * model.coarse_columns + column
			if (
				model.coarse_tops[block] > ground + LEVEL
				or model.coarse_bottoms[block] < ground - LEVEL
				or model.coarse_forest[block]
			):
				return false
	return true
