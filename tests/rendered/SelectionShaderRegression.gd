extends SceneTree

var failures: Array[String] = []
var comparisons := 0
var viewport: SubViewport


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("SelectionShaderRegression requires graphical rendering")
		quit(1)
		return
	Engine.max_fps = 120
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1})
	for frame in 3:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 400)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 400)
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
	camera.size = 5.0
	stage.add_child(camera)
	camera.position = Vector3(0, 6, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	var shader = load("res://source/shaders/3d/faction_selection.gdshader")
	# Use the previous material-uniform transport as a rendering oracle. The
	# shape/shading code is unchanged; two shared-material instances must retain
	# independent clocks, including a frozen reduced-flashes marker.
	var old_shader := Shader.new()
	old_shader.code = shader.code.replace(
		"instance uniform float animation_time", "uniform float animation_time"
	)
	var shared := ShaderMaterial.new()
	shared.shader = shader
	shared.set_shader_parameter("color", Color("78c8ee"))
	var candidates: Array[MeshInstance3D] = []
	var references: Array[MeshInstance3D] = []
	for index in 2:
		var candidate := _plane(shared, float(index) * 2.5 - 1.25)
		stage.add_child(candidate)
		candidates.append(candidate)
		var material := ShaderMaterial.new()
		material.shader = old_shader
		material.set_shader_parameter("color", Color("78c8ee"))
		var reference := _plane(material, candidate.position.x)
		stage.add_child(reference)
		references.append(reference)
	for faction in 3:
		for extents in [Vector2.ZERO, Vector2(1.0, .6)]:
			shared.set_shader_parameter("faction_style", faction)
			shared.set_shader_parameter("half_extents", extents)
			for clocks in [Vector2(0, .5), Vector2(2, 9), Vector2(0, 300)]:
				for index in 2:
					candidates[index].set_instance_shader_parameter("animation_time", clocks[index])
					var material = references[index].material_override
					material.set_shader_parameter("faction_style", faction)
					material.set_shader_parameter("half_extents", extents)
					material.set_shader_parameter("animation_time", clocks[index])
					candidates[index].show()
					references[index].hide()
				var actual := await _capture()
				for index in 2:
					candidates[index].hide()
					references[index].show()
				var expected := await _capture()
				_compare(actual, expected, "%d %s %s" % [faction, extents, clocks])
	for message in failures:
		push_error(message)
	options.restore(original)
	print(
		(
			"Selection shader parity: %d failures across %d rendered comparisons"
			% [failures.size(), comparisons]
		)
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _plane(material: ShaderMaterial, x: float) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	result.mesh = mesh
	result.material_override = material
	result.position.x = x
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


func _capture() -> Image:
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _compare(actual: Image, expected: Image, label: String):
	comparisons += 1
	if actual.get_size() != expected.get_size():
		failures.append("Selection %s: capture dimensions changed" % label)
		return
	var different := 0
	var lit := 0
	for y in actual.get_height():
		for x in actual.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			if b.r + b.g + b.b > .1:
				lit += 1
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > .025:
				different += 1
	if lit < 200 or different > 24:
		failures.append("Selection %s: %d lit, %d differing pixels" % [label, lit, different])
