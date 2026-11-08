extends SceneTree

signal render_drained
var failures: Array[String] = []
var comparisons := 0
var viewport: SubViewport


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ChargeSparkRegression requires graphical rendering")
		quit(1)
		return
	Engine.max_fps = 120
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1})
	for frame in 3:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 640)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	# Compare a fixed render target; macOS window transitions can resize the
	# root between otherwise identical captures, especially with threaded draws.
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	stage.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	stage.add_child(camera)
	var factory = load("res://source/match/effects/WeaponPreparationVisual.gd")
	for tint in [Color("ffc16a"), Color("72dfff")]:
		# Exercise the production factory without constructing an unrelated battle.
		var display = factory.new()
		display._setup_sparks(tint)
		var candidate: MultiMeshInstance3D = display._sparks
		display.remove_child(candidate)
		stage.add_child(candidate)
		var material: ShaderMaterial = display._spark_material
		display.free()
		var reference := _reference(tint)
		stage.add_child(reference)
		for view in [Vector3(0, 0, 3), Vector3(2, 1, 3)]:
			camera.position = view
			camera.look_at(Vector3.ZERO)
			for sample in [[.05, .09], [.5, .47], [.98, .86], [1.0, .99999], [1.0, 1.00001]]:
				material.set_shader_parameter("charge", sample[0])
				material.set_shader_parameter("phase", sample[1])
				_pose_reference(reference.multimesh, sample[0], sample[1])
				candidate.show()
				reference.hide()
				var actual := await _capture()
				candidate.hide()
				reference.show()
				var expected := await _capture()
				_compare(actual, expected, "%s %s %s" % [tint, view, sample])
		candidate.queue_free()
		reference.queue_free()
		await process_frame
	for message in failures:
		push_error(message)
	options.restore(original)
	print(
		(
			"Charge spark parity: %d failures across %d rendered comparisons"
			% [failures.size(), comparisons]
		)
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _reference(tint: Color) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.022, .022, .11)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.5
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 24
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _pose_reference(batch: MultiMesh, progress: float, phase: float):
	# Independent original CPU presentation, including its material and matrices.
	for index in 24:
		var angle := index * 2.399963
		var y := 1.0 - 2.0 * (index + .5) / 24
		var radial := sqrt(1.0 - y * y)
		var direction := Vector3(cos(angle) * radial, y, sin(angle) * radial)
		var travel := fposmod(phase + index * .618034, 1.0)
		var radius := .07 + (1.0 - travel) * (1.0 - travel) * .95
		var activation := 1.0 if index < 8 else smoothstep(0.0, 1.0, progress * 16 - (index - 8))
		var size := pow(sin(travel * PI), 2.0) * (.65 + progress * .55) * activation
		var basis := Basis.looking_at(-direction).scaled(Vector3.ONE * size)
		batch.set_instance_transform(index, Transform3D(basis, direction * radius))


func _capture() -> Image:
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	# Threaded post-draw signals are deferred; fence the render queue after the
	# scene has flushed its transforms instead of relying on delivered signals.
	RenderingServer.call_on_render_thread(_render_barrier)
	await render_drained
	return viewport.get_texture().get_image()


func _render_barrier():
	render_drained.emit.call_deferred()


func _compare(actual: Image, expected: Image, label: String):
	comparisons += 1
	if actual.get_size() != expected.get_size():
		failures.append("Spark comparison raster changed: " + label)
		return
	var different := 0
	var visible_pixels := 0
	for y in expected.get_height():
		for x in expected.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			if b.r + b.g + b.b > .2:
				visible_pixels += 1
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > .1:
				different += 1
	if visible_pixels < 30 or different > 5:
		DirAccess.make_dir_recursive_absolute("user://spark-comparison")
		actual.save_png("user://spark-comparison/%d-actual.png" % comparisons)
		expected.save_png("user://spark-comparison/%d-expected.png" % comparisons)
		failures.append(
			"Spark shader differs: %s visible=%d different=%d" % [label, visible_pixels, different]
		)
