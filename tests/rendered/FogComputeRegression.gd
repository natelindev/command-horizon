extends SceneTree

## Exercises the GPU kernel and queued cleanup without constructing a match.
signal render_drained
var _errors: Array[String] = []


func _initialize():
	_run.call_deferred()


func _run():
	var backend = load("res://source/match/rendering/FogTextureCompute.gd").new()
	backend.initialize(Vector2i(65, 67))
	for frame in 300:
		await process_frame
		if backend.ready or backend.failed:
			break
	_check(backend.ready, "Compute fog did not initialize; use an RD renderer and import shaders")
	if backend.ready:
		await _check_visibility(backend)
	var released := weakref(backend)
	backend.close()
	backend = null
	RenderingServer.call_on_render_thread(_render_barrier)
	await render_drained
	_check(released.get_ref() == null, "Queued fog cleanup retained its owner")
	for message in _errors:
		push_error(message)
	print("Compute fog: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _render_barrier():
	render_drained.emit.call_deferred()


func _check_visibility(backend):
	var reveals := [
		{"position": Vector2(8, 8), "radius": 4.0, "triangles": PackedVector2Array()},
		{
			"position": Vector2(24, 24),
			"radius": 8.0,
			"triangles": PackedVector2Array([Vector2.ZERO, Vector2(8, 0), Vector2(0, 8)])
		}
	]
	backend.update(reveals, false, Color(.25, .25, .25), Color.WHITE)
	await _draws()
	var history: Image = backend.history.get_image()
	var current: Image = backend.texture.get_image()
	_check(history.get_size() == Vector2i(65, 67), "GPU fog truncates partial workgroups")
	_near(history.get_pixel(8, 8).r, .25, "Circle exploration missing")
	_near(history.get_pixel(25, 25).r, .25, "Terrain triangle exploration missing")
	_near(history.get_pixel(30, 30).r, 0.0, "Triangle reveal leaked through terrain occlusion")
	_near(current.get_pixel(8, 8).r, 1.0, "Currently visible ground is not fully revealed")
	backend.update([], false, Color(.25, .25, .25), Color.WHITE)
	await _draws()
	_near(
		backend.history.get_image().get_pixel(8, 8).r, .25, "Removing a revealer erased exploration"
	)
	_near(
		backend.texture.get_image().get_pixel(8, 8).r,
		.25,
		"Removing a revealer left current vision"
	)
	var saved: Image = backend.history.get_image()
	backend.update([], true, Color(.25, .25, .25), Color.WHITE)
	await _draws()
	_near(
		backend.texture.get_image().get_pixel(64, 66).r,
		1.0,
		"Full reveal omits partial edge pixels"
	)
	_check(
		saved.get_data() == backend.history.get_image().get_data(),
		"Full reveal changed saved exploration"
	)
	var restored := Image.create(65, 67, false, Image.FORMAT_RGBA8)
	restored.fill(Color(0, 0, 0, 0))
	restored.set_pixel(48, 48, Color(.25, .25, .25))
	backend.restore(restored)
	backend.update([], false, Color(.25, .25, .25), Color.WHITE)
	await _draws()
	_near(
		backend.history.get_image().get_pixel(48, 48).r, .25, "Saved exploration was not restored"
	)
	_near(
		backend.history.get_image().get_pixel(8, 8).r,
		0.0,
		"Restore retained exploration from the old match"
	)


func _draws():
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _near(actual: float, expected: float, message: String):
	_check(absf(actual - expected) < .01, message)


func _check(condition: bool, message: String):
	if not condition:
		_errors.append(message)
