extends SceneTree

var _errors: Array[String] = []
var _checks := 0
var _native: RefCounted
var _portable: GDScript


func _initialize():
	_run.call_deferred()


func _run():
	_native = load("res://source/match/rendering/NativePosePacker.gd").create()
	_portable = load("res://source/match/rendering/FogTextureCompute.gd")
	_check(_native != null and _native.has_method("pack_fog"), "Native fog packer missing")
	if _native != null and _native.has_method("pack_fog"):
		_parity([], Vector2i(65, 67))
		var edges := []
		for x in [-32.0, -16.0, -.00001, 0.0, 15.99999, 16.0, 64.0, 65.0, 80.0]:
			for y in [-16.0, 0.0, 16.0, 67.0, 80.0]:
				for radius in [0.0, .00001, 1.0, 16.0, 32.0]:
					edges.append(_circle(Vector2(x, y), radius))
		_parity(edges, Vector2i(65, 67))
		_parity([_circle(Vector2(8, 8), 4)], Vector2i.ONE)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4819027
		for sample in 120:
			var size := Vector2i(rng.randi_range(1, 259), rng.randi_range(1, 263))
			var reveals := []
			for index in rng.randi_range(1, 100):
				var centre := Vector2(rng.randf_range(-64, 320), rng.randf_range(-64, 320))
				var reveal := _circle(centre, rng.randf_range(0, 64))
				if index % 3 == 0:
					for point in rng.randi_range(1, 14):
						reveal.triangles.append(
							Vector2(rng.randf_range(-96, 96), rng.randf_range(-96, 96))
						)
				reveals.append(reveal)
			_parity(reveals, size)
		var source := [_circle(Vector2(8, 8), 4.0)]
		var retained: Array = _native.pack_fog(source, Vector2i(65, 67))
		var original := retained.duplicate(true)
		source[0].position = Vector2(48, 48)
		_native.pack_fog(source, Vector2i(65, 67))
		_check(retained == original, "Later calls mutated retained fog buffers")
		for dimensions in [Vector2i.ZERO, Vector2i(-1, 10), Vector2i(16385, 10)]:
			_check(
				_native.pack_fog([], dimensions).is_empty(), "Invalid dimensions did not fall back"
			)
		for value in [
			{},
			_circle(Vector2.INF, 4.0),
			_circle(Vector2.ZERO, NAN),
			_circle(Vector2.ZERO, -1.0),
			{"position": Vector2.ZERO, "radius": 2.0, "triangles": [Vector2.ZERO]},
			{
				"position": Vector2.ZERO,
				"radius": 2.0,
				"triangles": PackedVector2Array([Vector2.INF, Vector2.ZERO, Vector2.ONE])
			},
		]:
			_check(
				_native.pack_fog([value], Vector2i(65, 67)).is_empty(),
				"Invalid reveal did not fall back"
			)
	for message in _errors:
		push_error(message)
	print("Fog packing regression: %d checks, %d failures" % [_checks, _errors.size()])
	quit(0 if _errors.is_empty() else 1)


func _circle(point: Vector2, radius) -> Dictionary:
	return {"position": point, "radius": radius, "triangles": PackedVector2Array()}


func _parity(reveals: Array, dimensions: Vector2i):
	var native: Array = _native.pack_fog(reveals, dimensions)
	var portable: Array = _portable.pack(reveals, dimensions)
	_check(native.size() == 3, "Native packing failed for supported reveals")
	if native.size() != 3:
		return
	for index in 3:
		_check(
			native[index] == portable[index], "Fog buffer %d differs at %s" % [index, dimensions]
		)


func _check(condition: bool, message: String):
	_checks += 1
	if not condition:
		_errors.append(message)
