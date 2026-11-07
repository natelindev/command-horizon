extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var original = root.get_node("Globals").options.reduced_flashes
	root.get_node("Globals").options.reduced_flashes = false
	var script = load("res://source/match/effects/ManualParticleBuffer.gd")
	for kind in ["spark", "dust", "smoke", "trail_smoke", "fire", "debris", "clod"]:
		var buffer = script.new()
		buffer.setup(
			kind,
			8,
			.65,
			Vector3(0, -9.8, 0),
			0,
			0,
			.45 if kind == "debris" else (0.0 if kind == "clod" else -1.0)
		)
		root.add_child(buffer)
		if kind in ["smoke", "dust", "trail_smoke"]:
			_check(
				(
					buffer._surface.get_shader_parameter("billow")
					and buffer._surface.get_shader_parameter("vapor")
					and buffer._surface.get_shader_parameter("fade_in") > 0.0
				),
				"Vapor lacks decelerating growth and a soft birth: " + kind
			)
		elif kind in ["spark", "fire"]:
			_check(
				(
					not buffer._surface.get_shader_parameter("billow")
					and buffer._surface.get_shader_parameter("fade_in") == 0.0
				),
				"Instant hot particles inherited slow smoke timing: " + kind
			)
		_check(buffer.is_inactive() and not buffer.visible, "An empty particle pool draws")
		# Birth metadata must keep sub-second resolution after hours of gameplay.
		buffer._clock = 14400.125
		for index in 12:
			var pose = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .2), Vector3(index, 4, 7))
			buffer.emit_particle(pose, Vector3(1, 2, 3), Color(.7, .5, .2, .8), Color(3, 0, 0), 31)
		_check(buffer.multimesh.instance_count == 8, "Emission enlarged a bounded buffer")
		_check(buffer.multimesh.visible_instance_count == 8, "Overflow lost the visible buffer")
		# The dummy backend does not retain MultiMesh buffers. Run this same
		# fixture with a renderer to verify the actual emitted instance metadata.
		if DisplayServer.get_name() != "headless":
			# RenderingServer applies queued instance writes on the next frame.
			buffer.set_process(false)
			for frame in 3:
				await process_frame
				RenderingServer.force_draw(false)
			var latest = buffer.multimesh.get_instance_transform(3)
			_check(
				latest.origin == Vector3(11, 4, 7), "Overflow did not replace its oldest particle"
			)
			_check(latest.basis.x == Vector3(1, 2, 3), "Emission lost initial velocity")
			_check(is_equal_approx(latest.basis.y.y, 3.0), "Emission lost elevated ground contact")
			_check(latest.basis.z.x == 14400.125, "Long matches quantize brief particle births")
			buffer.set_process(true)
		var before = buffer._clock
		paused = true
		buffer._process(.3)
		_check(buffer._clock == before, "Tactical pause advanced particle lifetime")
		paused = false
		buffer._process(.3)
		_check(buffer.visible and not buffer.is_inactive(), "Particles expired prematurely")
		buffer._process(.4)
		_check(buffer.is_inactive() and not buffer.visible, "Expired particles retain a draw")
		_check(not buffer.is_processing(), "Empty particle pool keeps per-frame updates")
		buffer.free()
	root.get_node("Globals").options.reduced_flashes = original
	for message in errors:
		push_error(message)
	print("Manual particle buffers: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)
