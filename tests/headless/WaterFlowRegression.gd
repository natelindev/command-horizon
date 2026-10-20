extends SceneTree

var errors = []


func _initialize():
	call_deferred("_run")


func _run():
	var builder_script = load("res://source/match/maps/terrain/WaterSurface.gd")
	var river = {
		"line": PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(12, 12)]),
		"polygon":
		PackedVector2Array(
			[
				Vector2(0, -2),
				Vector2(14, -2),
				Vector2(14, 12),
				Vector2(10, 12),
				Vector2(10, 2),
				Vector2(0, 2)
			]
		)
	}
	var builder = builder_script.new()
	var mesh = builder.build(river, [river], -.3)
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uv = arrays[Mesh.ARRAY_TEX_UV]
	var directions = arrays[Mesh.ARRAY_TEX_UV2]
	_check(vertices.size() > river.polygon.size(), "Water has no vertices for travelling waves")
	_check(builder.speed == 1.2, "River does not flow faster than a pool")
	var horizontal = 0
	var vertical = 0
	for index in vertices.size():
		var point = Vector2(vertices[index].x, vertices[index].z)
		_check(is_equal_approx(vertices[index].y, -.3), "Water changed gameplay level")
		if point.x < 8 and absf(point.y) < 2.01:
			horizontal += 1
			_check(
				directions[index].is_equal_approx(Vector2.RIGHT),
				"Current cuts across first river reach"
			)
			_check(is_equal_approx(uv[index].x, point.x), "Downstream distance lost before bend")
		if point.y > 4:
			vertical += 1
			_check(
				directions[index].is_equal_approx(Vector2.DOWN), "Current does not turn with river"
			)
			_check(is_equal_approx(uv[index].x, 12 + point.y), "Downstream distance resets at bend")
	_check(horizontal > 5 and vertical > 5, "River bend test lacks coverage")
	var indices = arrays[Mesh.ARRAY_INDEX]
	for index in range(0, indices.size(), 3):
		for edge in 3:
			var a = vertices[indices[index + edge]]
			var b = vertices[indices[index + (edge + 1) % 3]]
			_check(a.distance_to(b) <= 3.01, "Water triangles cannot carry waves at battle zoom")
	var ford = {
		"ford": true,
		"polygon":
		PackedVector2Array([Vector2(4, -2), Vector2(6, -2), Vector2(6, 2), Vector2(4, 2)])
	}
	var crossing = builder_script.new()
	crossing.build(ford, [river, ford], -.08)
	_check(crossing._line == river.line, "Ford current is disconnected from its river")
	var continuous = builder_script.new()
	var crossing_mesh = continuous.build(river, [river, ford], -.3)
	var crossing_arrays = crossing_mesh.surface_get_arrays(0)
	var crossing_vertices = crossing_arrays[Mesh.ARRAY_VERTEX]
	var crossing_colors = crossing_arrays[Mesh.ARRAY_COLOR]
	var shallow_vertices = 0
	for index in crossing_vertices.size():
		var point = crossing_vertices[index]
		if Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), ford.polygon):
			shallow_vertices += 1
			_check(is_equal_approx(point.y, -.08), "Continuous river falls below the ford bed")
			_check(crossing_colors[index].r < .2, "Ford waves are too high for the shallow bed")
	_check(shallow_vertices > 0, "Continuous ford test has no shallow vertices")
	var pool = builder_script.new()
	pool.build({"polygon": ford.polygon}, [], -.3)
	_check(pool.speed < builder.speed, "Harbor/lake uses river current speed")
	var registry = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	for filename in DirAccess.get_files_at(registry.ROOT):
		if not filename.ends_with(".tscn"):
			continue
		var map_name = filename.get_basename()
		var layout = registry.layout("res://source/match/maps/battlefields/%s.tscn" % map_name)
		for water in layout.water:
			var surface = builder_script.new()
			var result = surface.build(water, layout.water, water.get("level", 0.0) - .3)
			_check(
				result.surface_get_array_len(0) < 30000, map_name + ": water mesh exceeds budget"
			)
			if water.has("line"):
				_check(
					surface._line == PackedVector2Array(water.line),
					"Symmetry lost river current path"
				)
	for message in errors:
		push_error(message)
	print("Water flow regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value and message not in errors:
		errors.append(message)
