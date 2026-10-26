extends SceneTree

var failures = 0


func _initialize():
	_run.call_deferred()


func _run():
	var model = load("res://source/match/maps/terrain/TerrainModel.gd").new(
		{
			"size": Vector2(32, 32),
			"tiers":
			[
				{
					"polygon":
					PackedVector2Array(
						[Vector2(8, 8), Vector2(16, 8), Vector2(16, 22), Vector2(8, 22)]
					),
					"height": 3.0
				}
			],
			"forests":
			[
				{
					"polygon":
					PackedVector2Array(
						[Vector2(20, 4), Vector2(27, 4), Vector2(27, 14), Vector2(20, 14)]
					)
				}
			],
			"blockers":
			[
				{
					"polygon":
					PackedVector2Array(
						[Vector2(3, 22), Vector2(7, 22), Vector2(7, 27), Vector2(3, 27)]
					),
					"height": 4.5
				}
			]
		}
	)
	var sight = load("res://source/match/maps/terrain/TerrainSight.gd")
	if model.native_sight == null:
		push_error("Native terrain regression requires the current native module")
		quit(1)
		return
	var random = RandomNumberGenerator.new()
	random.seed = 5281
	var rays = []
	for index in 12000:
		var a = Vector3(
			random.randf_range(-10, 42), random.randf_range(-2, 10), random.randf_range(-10, 42)
		)
		var b = Vector3(
			random.randf_range(-10, 42), random.randf_range(-2, 10), random.randf_range(-10, 42)
		)
		if index % 8 == 0:
			# Exact lattice, eye-height and endpoint-clearance boundaries.
			a = Vector3(
				floorf(a.x * 2.0) * .5, .8 if index % 16 == 0 else 3.8, floorf(a.z * 2.0) * .5
			)
			b = a + Vector3([0.0, .75, 1.5, 3.0, 8.0][index % 5], 0, 0)
		for forest in [false, true]:
			var expected = sight.segment_clear_script(model, a, b, forest)
			_check(
				sight.segment_clear(model, a, b, forest) == expected,
				"Native ray differs: %s -> %s forest=%s" % [a, b, forest]
			)
			rays.append([a, b, forest])
	var outlines = []
	for index in 1200:
		var centre = Vector2(random.randf_range(-2, 34), random.randf_range(-2, 34))
		if index % 4 == 0:
			centre = centre.snapped(Vector2(.5, .5))
		var reach = [0.25, 1.5, 3.0, 8.0, 15.0][index % 5]
		var level_reach = -1.0 if index % 3 == 0 else reach * .6
		_compare_outline(sight, model, centre, reach, level_reach)
		outlines.append([centre, reach, level_reach])
	for native in [false, true]:
		var start = Time.get_ticks_usec()
		for outline in outlines:
			if native:
				sight.reveal_triangles(model, outline[0], outline[1], outline[2])
			else:
				sight.reveal_triangles_script(model, outline[0], outline[1], outline[2])
		print(
			"TERRAIN_OUTLINES native=",
			native,
			" count=",
			outlines.size(),
			" ms=",
			(Time.get_ticks_usec() - start) / 1000.0
		)
	var registry = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	for file in DirAccess.get_files_at("res://source/match/maps/battlefields"):
		if not file.ends_with(".tscn"):
			continue
		var layout = registry.layout("res://source/match/maps/battlefields/" + file)
		if layout.is_empty():
			continue
		var authored = load("res://source/match/maps/terrain/TerrainModel.gd").new(layout)
		for index in 40:
			var centre = Vector2(
				random.randf_range(0, authored.size.x), random.randf_range(0, authored.size.y)
			)
			_compare_outline(sight, authored, centre, 18.0, -1.0 if index % 2 == 0 else 12.0)
	# Replacement packed arrays must be read live rather than retained as stale
	# native pointers. The scripted result remains the oracle after every edit.
	model.ground_tops.fill(9.0)
	model.coarse_tops.fill(9.0)
	model.coarse_bottoms.fill(9.0)
	for outline in outlines.slice(0, 100):
		_compare_outline(sight, model, outline[0], outline[1], outline[2])
	for ray in rays.slice(0, 1000):
		_check(
			(
				sight.segment_clear(model, ray[0], ray[1], ray[2])
				== sight.segment_clear_script(model, ray[0], ray[1], ray[2])
			),
			"Terrain array edit became stale"
		)
	for native in [false, true]:
		var start = Time.get_ticks_usec()
		for ray in rays:
			if native:
				sight.segment_clear(model, ray[0], ray[1], ray[2])
			else:
				sight.segment_clear_script(model, ray[0], ray[1], ray[2])
		print(
			"TERRAIN_RAYS native=",
			native,
			" count=",
			rays.size(),
			" ms=",
			(Time.get_ticks_usec() - start) / 1000.0
		)
	print("Native terrain sight: %d failures" % failures)
	await root.get_node("Globals").quit_game(0 if failures == 0 else 1)


func _compare_outline(sight, model, centre, reach, level_reach):
	var expected = sight.reveal_triangles_script(model, centre, reach, level_reach)
	var actual = sight.reveal_triangles(model, centre, reach, level_reach)
	_check(
		actual.size() == expected.size(),
		(
			"Native outline interval count differs at %s reach=%s level=%s (%s/%s)"
			% [centre, reach, level_reach, actual.size(), expected.size()]
		)
	)
	if actual.size() == expected.size():
		for point in actual.size():
			if actual[point].distance_to(expected[point]) > .0001:
				_check(
					false,
					(
						"Native outline vertex differs at %s: %s/%s"
						% [centre, actual[point], expected[point]]
					)
				)
				break


func _check(condition, message):
	if not condition:
		failures += 1
		if failures <= 10:
			push_error(message)
