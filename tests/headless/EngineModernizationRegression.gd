extends SceneTree

## Reusable queries, stitched tile publication and bounded obstacle rebakes.
var _errors: Array[String] = []
var _nav: RID
var _region: RID
var _baker_script: Script


func _initialize():
	_run.call_deferred()


func _run():
	_baker_script = load("res://source/match/TerrainTileBaker.gd")
	_check_fog_packing()
	_check_seam_splitting()
	await _check_path_queries()
	await _check_local_baking()
	for message in _errors:
		push_error(message)
	print("Engine modernization: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _check_fog_packing():
	var compute = load("res://source/match/rendering/FogTextureCompute.gd")
	var data: Array = compute.pack(
		[
			{"position": Vector2(8, 8), "radius": 3.0, "triangles": PackedVector2Array()},
			{
				"position": Vector2(32, 32),
				"radius": 8.0,
				"triangles": PackedVector2Array([Vector2.ZERO, Vector2(8, 0), Vector2(0, 8)])
			},
			{"position": Vector2(-100, -100), "radius": 1.0, "triangles": PackedVector2Array()}
		],
		Vector2i(64, 64)
	)
	var shapes: PackedFloat32Array = data[0].to_float32_array()
	_check(shapes.size() == 16, "Fog primitive packing lost shapes or included off-map geometry")
	if shapes.size() == 16:
		_check(
			shapes[0] == 8.0 and shapes[2] == 3.0 and shapes[6] == 0.0,
			"Circle ABI differs from shader"
		)
		_check(
			shapes[8] == 32.0 and shapes[12] == 32.0 and shapes[14] == 1.0,
			"Terrain triangle ABI differs from shader"
		)
	var ranges: PackedInt32Array = data[1].to_int32_array()
	var indices: PackedInt32Array = data[2].to_int32_array()
	_check(ranges.size() == 4 * 4 * 2, "Fog bins omit edge tiles")
	_check(ranges[1] == 1 and indices[ranges[0]] == 0, "Circle missing from its spatial bin")
	var triangle_bin := (2 * 4 + 2) * 2
	_check(
		ranges[triangle_bin + 1] == 1 and indices[ranges[triangle_bin]] == 1,
		"Occluded reveal triangle missing from its bin"
	)
	var empty: Array = compute.pack([], Vector2i(17, 19))
	_check(empty[1].to_int32_array().size() == 8, "Nonmultiple fog dimensions omit partial bins")
	for count in empty[1].to_int32_array():
		_check(count == 0, "Empty fog frame reuses stale bin ranges")


func _check_seam_splitting():
	var baker = _baker_script
	var vertices := PackedVector3Array(
		[
			Vector3(0, 0, 0),
			Vector3(32, 0, 0),
			Vector3(32, 0, 32),
			Vector3(0, 0, 32),
			Vector3(32, 0, 16)
		]
	)
	var seams := {Vector2i(0, roundi(32.0 / baker.WELD)): [1, 2, 4]}
	var polygon: PackedInt32Array = baker._split_seams(
		PackedInt32Array([0, 3, 2, 1]), vertices, seams
	)
	_check(polygon.size() == 5 and polygon.has(4), "Tile seam T-junction was not split")
	var plane := Plane(vertices[polygon[0]], vertices[polygon[1]], vertices[polygon[2]])
	_check(absf(plane.normal.y) > .99, "Stitched polygon starts with collinear plane corners")


func _open_map(mesh: NavigationMesh):
	_nav = NavigationServer3D.map_create()
	NavigationServer3D.map_set_use_async_iterations(_nav, false)
	NavigationServer3D.map_set_cell_size(_nav, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(_nav, mesh.cell_height)
	NavigationServer3D.map_set_active(_nav, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(_region, false)
	NavigationServer3D.region_set_map(_region, _nav)
	await _publish(mesh)


func _publish(mesh: NavigationMesh):
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	# An initial empty-map synchronization can advance its iteration before this
	# region is included. This server-only fixture needs the exact submitted mesh,
	# rather than accepting an unrelated asynchronous iteration as publication.
	NavigationServer3D.map_force_update(_nav)
	await physics_frame


func _close_map():
	NavigationServer3D.free_rid(_region)
	NavigationServer3D.free_rid(_nav)


func _check_path_queries():
	var mesh := NavigationMesh.new()
	mesh.set_vertices(
		PackedVector3Array(
			[
				Vector3.ZERO,
				Vector3(16, 0, 0),
				Vector3(16, 0, 16),
				Vector3(0, 0, 16),
				Vector3(64, 0, 0),
				Vector3(80, 0, 0),
				Vector3(80, 0, 16),
				Vector3(64, 0, 16)
			]
		)
	)
	mesh.add_polygon(PackedInt32Array([0, 3, 2, 1]))
	mesh.add_polygon(PackedInt32Array([4, 7, 6, 5]))
	await _open_map(mesh)
	var query = load("res://source/match/orders/PathQuery.gd").new()
	var retained: PackedVector3Array = query.path(_nav, Vector3(1, 0, 1), Vector3(15, 0, 15))
	var copy := retained.duplicate()
	for target in [Vector3(3, 0, 12), Vector3(70, 0, 8), Vector3(100, 0, 100)]:
		var expected := NavigationServer3D.map_get_path(_nav, Vector3.ONE, target, true)
		var actual: PackedVector3Array = query.path(_nav, Vector3.ONE, target)
		_check(actual == expected, "Reusable query changed reachable or partial path")
		_check(retained == copy, "Reusing a result mutated an earlier route")
	_check(query._parameters.metadata_flags == 0, "Path query collects unused metadata")
	_check(query._result.path_rids.is_empty(), "Path query retained region metadata")
	_close_map()


func _check_local_baking():
	var base := NavigationMeshSourceGeometryData3D.new()
	base.add_faces(
		PackedVector3Array(
			[
				Vector3(0, 0, 96),
				Vector3.ZERO,
				Vector3(96, 0, 0),
				Vector3(96, 0, 0),
				Vector3(96, 0, 96),
				Vector3(0, 0, 96)
			]
		),
		Transform3D.IDENTITY
	)
	var template := NavigationMesh.new()
	template.filter_baking_aabb = AABB(Vector3(0, -1, 0), Vector3(96, 4, 96))
	template.cell_size = .25
	template.cell_height = .25
	template.agent_radius = .5
	template.agent_height = 1.0
	template.region_min_size = 0.0
	template.region_merge_size = 0.0
	var baker = _baker_script.new()
	baker.setup(template, base)
	_check(baker.meshes.size() == 9, "Unexpected navigation tile dimensions")
	await _open_map(baker.combined())
	var across := NavigationServer3D.map_get_path(_nav, Vector3(8, 0, 8), Vector3(88, 0, 88), true)
	_check(
		not across.is_empty() and across[-1].distance_to(Vector3(88, .25, 88)) < 1.0,
		"Tile seams disconnect the open map"
	)
	var obstacle := NavigationObstacle3D.new()
	obstacle.affect_navigation_mesh = true
	obstacle.vertices = PackedVector3Array(
		[Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(3, 0, 3), Vector3(-3, 0, 3)]
	)
	root.add_child(obstacle)
	obstacle.position = Vector3(48, 0, 48)
	await _bake_obstacle(baker, base, obstacle)
	_check(baker.last_baked_tiles == 1, "Interior construction rebakes unrelated tiles")
	await _publish(baker.combined())
	_check(
		(
			NavigationServer3D.map_get_closest_point(_nav, obstacle.position).distance_to(
				obstacle.position
			)
			> 2.0
		),
		"Construction did not block its footprint"
	)
	obstacle.position = Vector3(32, 0, 48)
	await _bake_obstacle(baker, base, obstacle)
	_check(
		baker.last_baked_tiles > 1 and baker.last_baked_tiles < 9,
		"Seam construction misses neighbor clearance or rebakes everything"
	)
	obstacle.free()
	var completion := {"done": false}
	baker.rebake([], base, func(): completion.done = true)
	await _wait_bake(completion)
	await _publish(baker.combined())
	_check(
		(
			NavigationServer3D.map_get_closest_point(_nav, Vector3(32, 0, 48)).distance_to(
				Vector3(32, 0, 48)
			)
			< 1.0
		),
		"Destruction left stale blocked geometry"
	)
	_close_map()
	# Cancelling a match with work in flight must drain the owned workers without
	# invoking the old match's publication callback or scheduling queued tiles.
	var unknown_geometry := Node3D.new()
	var cancelled := {"published": false}
	baker.rebake([unknown_geometry], base, func(): cancelled.published = true)
	_check(
		baker._active > 0 and not baker._pending.is_empty(),
		"Cancellation fixture has no queued work"
	)
	baker.cancel()
	for frame in 600:
		if baker._active == 0:
			break
		await physics_frame
	_check(
		baker._active == 0 and baker._pending.is_empty() and baker._source == null,
		"Cancelled tile workers did not drain"
	)
	_check(not cancelled.published, "Cancelled match received an old bake publication")
	unknown_geometry.free()
	# A nonmultiple map extent must not put the entire short remainder at one edge.
	baker._template.cell_size = .3
	baker._step = 32.1
	for length in [144.0, 192.0]:
		var edges: PackedFloat32Array = baker._axis_boundaries(0, length)
		for index in edges.size():
			_check(
				absf(edges[index] + edges[-1 - index] - length) < .301,
				"Tile edges bias mirrored starts"
			)


func _bake_obstacle(baker, base, obstacle):
	var source: NavigationMeshSourceGeometryData3D = base.duplicate()
	var outline := PackedVector3Array()
	for vertex in obstacle.vertices:
		outline.append(obstacle.global_transform * vertex)
	source.add_projected_obstruction(outline, -.5, 3.0, false)
	var completion := {"done": false}
	baker.rebake([obstacle], source, func(): completion.done = true)
	await _wait_bake(completion)


func _wait_bake(completion: Dictionary):
	for frame in 600:
		if completion.done:
			return
		await physics_frame
	_check(false, "Tile baking timed out")


func _check(condition: bool, message: String):
	if not condition:
		_errors.append(message)
