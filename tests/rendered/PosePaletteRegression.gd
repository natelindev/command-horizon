extends SceneTree

const HIDDEN_BASIS = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
var failures: Array[String] = []
var comparisons := 0


func _initialize():
	_run.call_deferred()


func _run():
	if RenderingServer.get_rendering_device() == null:
		push_error("PosePaletteRegression requires graphical Forward+ rendering")
		quit(1)
		return
	Engine.max_fps = 120
	var palette_script = load("res://source/match/rendering/ComputePosePalette.gd")
	var palette = palette_script.new()
	palette.setup(130)
	# Grow across workgroup boundaries, shrink, then grow again. More than one
	# update before a draw must retain the final snapshot, including new rows.
	for count in [2, 65, 130, 7, 129]:
		var previous := _poses(130, false)
		var current := _poses(130, true)
		palette.upload(current, previous)
		palette.upload(previous, current)
		for weight in [0.0, 0.25, 0.5, 1.0]:
			# Subsequent frames change only the interpolation fraction. Input data
			# must remain available when there has been no new simulation update.
			palette.dispatch(weight, count)
			await RenderingServer.frame_post_draw
			var pixels: Image = palette.texture.get_image()
			for row in count:
				var a := pixels.get_pixel(0, row)
				var b := pixels.get_pixel(1, row)
				var c := pixels.get_pixel(2, row)
				var actual := Transform3D(
					Basis(Vector3(a.r, b.r, c.r), Vector3(a.g, b.g, c.g), Vector3(a.b, b.b, c.b)),
					Vector3(a.a, b.a, c.a)
				)
				var expected := Vector3(row, row * 0.25, -row).lerp(
					Vector3(row + 8, row * 0.25 - 4, -row + 2), weight
				)
				_check(actual.origin.distance_to(expected) < 0.0001, "Pose translation changed")
				_check(
					pixels.get_pixel(3, row).is_equal_approx(Color(row * 0.125, 0.25, 0.5, 0.75)),
					"Current pulse/track data was interpolated or lost"
				)
				if row % 7 == 0:
					_check(actual.basis == HIDDEN_BASIS, "Hidden pose became visible")
				else:
					_check(
						signf(actual.basis.determinant()) == (-1.0 if row % 2 else 1.0),
						"Nonuniform/reflected pose orientation changed"
					)
				comparisons += 1
	palette.release()
	var released = weakref(palette)
	palette = null
	await RenderingServer.frame_post_draw
	_check(released.get_ref() == null, "Released palette retained its owner")
	# Closing immediately after setup/dispatch must retain every queued callback
	# until its GPU resources are freed, even with a separate rendering thread.
	for index in 8:
		palette = palette_script.new()
		palette.setup(2)
		palette.upload(_poses(2, false), _poses(2, true))
		palette.dispatch(0.5, 2)
		palette.release()
		released = weakref(palette)
		palette = null
		await RenderingServer.frame_post_draw
		_check(released.get_ref() == null, "Queued palette teardown retained its owner")
	await process_frame
	for message in failures:
		push_error(message)
	print(
		"Pose palette regression: %d failures across %d GPU rows" % [failures.size(), comparisons]
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _poses(capacity: int, latest: bool) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(capacity * 64)
	for row in capacity:
		var basis := Basis(Vector3.UP, 0.7 if latest else -0.4).scaled(
			Vector3(1.5, 0.75, -2.0 if row % 2 else 2.0)
		)
		if row % 7 == 0:
			basis = HIDDEN_BASIS
		var origin := Vector3(row, row * 0.25, -row)
		if latest:
			origin += Vector3(8, -4, 2)
		for axis in 3:
			for column in 3:
				result.encode_float(row * 64 + axis * 16 + column * 4, basis[column][axis])
			result.encode_float(row * 64 + axis * 16 + 12, origin[axis])
		for column in 4:
			result.encode_float(
				row * 64 + 48 + column * 4,
				[row * 0.125, 0.25, 0.5, 0.75][column] if latest else -0.25
			)
	return result


func _check(condition: bool, message: String):
	if not condition and not message in failures:
		failures.append(message)
