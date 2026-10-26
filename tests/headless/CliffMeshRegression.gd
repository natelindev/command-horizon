extends SceneTree

# Cliff geometry for authored terrain: a raised tier gets outward walls, a
# sunken tier (gorge, wadi, canal cut) gets inward walls from the surrounding
# ground down to its floor, and a raised tier beside a sunken one is walled
# once, not twice.
#   Godot --headless --path . --script tests/headless/CliffMeshRegression.gd
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const CliffMesh = preload("res://source/match/maps/terrain/CliffMesh.gd")
const Layout = preload("res://source/match/maps/terrain/BattlefieldLayout.gd")
var errors = []


func _initialize():
	_run_after_ready.call_deferred()


func _run_after_ready():
	_sunken_walls_face_inward()
	_raised_walls_face_outward()
	_shared_edge_walled_once()
	_capstones_face_up()
	for message in errors:
		push_error(message)
	print("Cliff mesh regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _layout(tiers: Array) -> Dictionary:
	return (
		Layout
		. expand(
			{
				"id": "CliffMeshProbe",
				"players": 2,
				"size": Vector2(64, 64),
				"symmetry": "rotate",
				"biome": "desert",
				"shared": {"tiers": tiers},
			}
		)
	)


func _triangles(layout: Dictionary) -> Array:
	var mesh = CliffMesh.build(TerrainModel.new(layout), layout, "probe")
	if mesh == null:
		return []
	# Each entry: three corners and the generated (lit) normal of the face.
	var arrays = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null or indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var result = []
	for index in range(0, indices.size(), 3):
		var corners = [indices[index], indices[index + 1], indices[index + 2]]
		var normal = Vector3.ZERO
		for corner in corners:
			normal += normals[corner]
		result.append(corners.map(func(corner): return vertices[corner]) + [normal.normalized()])
	return result


# Steep triangles whose centre lies within `reach` of the square's edge.
func _walls(triangles: Array, square: Rect2, reach: float) -> Array:
	var result = []
	for triangle in triangles:
		var normal: Vector3 = triangle[3]
		if absf(normal.y) > 0.6:
			continue
		var centre = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		var flat = Vector2(centre.x, centre.z)
		var inside = square.grow(-reach).has_point(flat)
		if square.grow(reach).has_point(flat) and not inside:
			result.append([centre, normal])
	return result


func _square(low: Vector2, high: Vector2) -> PackedVector2Array:
	return PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])


func _sunken_walls_face_inward():
	var square = Rect2(Vector2(20, 20), Vector2(24, 24))
	var layout = _layout(
		[{"name": "Cut", "height": -3.0, "polygon": _square(square.position, square.end)}]
	)
	var walls = _walls(_triangles(layout), square, 3.0)
	_check(walls.size() >= 40, "Sunken tier got %d wall triangles" % walls.size())
	var inward = walls.filter(
		func(wall):
			var toward_centre = Vector2(32, 32) - Vector2(wall[0].x, wall[0].z)
			return Vector2(wall[1].x, wall[1].z).dot(toward_centre) > 0.0
	)
	_check(inward.size() == walls.size(), "Sunken walls must face into the cut")
	var low = INF
	var high = -INF
	for wall in walls:
		low = minf(low, wall[0].y)
		high = maxf(high, wall[0].y)
	_check(high > -1.0 and low < -2.0, "Sunken walls must span rim to floor")


func _raised_walls_face_outward():
	var square = Rect2(Vector2(20, 20), Vector2(24, 24))
	var layout = _layout(
		[{"name": "Mesa", "height": 3.0, "polygon": _square(square.position, square.end)}]
	)
	var walls = _walls(_triangles(layout), square, 3.0)
	_check(walls.size() >= 40, "Raised tier got %d wall triangles" % walls.size())
	var outward = walls.filter(
		func(wall):
			var away = Vector2(wall[0].x, wall[0].z) - Vector2(32, 32)
			return Vector2(wall[1].x, wall[1].z).dot(away) > 0.0
	)
	_check(outward.size() == walls.size(), "Raised walls must face outward")


func _shared_edge_walled_once():
	# A mesa standing directly against a cut: the mesa walls the shared edge.
	var layout = _layout(
		[
			{"name": "Mesa", "height": 3.0, "polygon": _square(Vector2(10, 20), Vector2(32, 44))},
			{"name": "Cut", "height": -3.0, "polygon": _square(Vector2(32, 20), Vector2(54, 44))},
		]
	)
	var edge = 0
	for triangle in _triangles(layout):
		var centre = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		if absf(centre.x - 32.0) < 1.5 and centre.z > 24 and centre.z < 40:
			edge += 1
	var single = _layout(
		[{"name": "Mesa", "height": 3.0, "polygon": _square(Vector2(10, 20), Vector2(32, 44))}]
	)
	var mesa_only = 0
	for triangle in _triangles(single):
		var centre = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		if absf(centre.x - 32.0) < 1.5 and centre.z > 24 and centre.z < 40:
			mesa_only += 1
	_check(edge > 0 and edge <= mesa_only * 1.5, "Shared mesa/cut edge walled twice")


func _capstones_face_up():
	var layout = (
		Layout
		. expand(
			{
				"id": "CliffMeshProbe",
				"players": 2,
				"size": Vector2(64, 64),
				"symmetry": "rotate",
				"biome": "desert",
				"shared":
				{
					"blockers":
					[
						{
							"name": "Butte",
							"height": 5.0,
							"polygon": _square(Vector2(24, 24), Vector2(40, 40))
						}
					]
				},
			}
		)
	)
	var caps = _triangles(layout).filter(
		func(triangle): return (triangle[0].y + triangle[1].y + triangle[2].y) / 3.0 > 4.9
	)
	_check(not caps.is_empty(), "Formation has no capstone")
	_check(
		caps.all(func(triangle): return triangle[3].y > 0.5),
		"Formation capstone and lips must face up"
	)


func _check(condition, message):
	if not condition:
		errors.append(message)
