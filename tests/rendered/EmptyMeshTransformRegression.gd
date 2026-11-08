extends SceneTree

# A baseless MeshInstance remains a visible transform parent. Compare its
# moving descendants and restored mesh against an ordinary Node3D hierarchy.
var failures: Array[String] = []
var comparisons := 0
var targets: Array[SubViewport] = []
var branches: Array[Node3D] = []
var reference_mesh: MeshInstance3D
var mesh: BoxMesh


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("EmptyMeshTransformRegression requires graphical rendering")
		quit(1)
		return
	Engine.max_fps = 120
	mesh = BoxMesh.new()
	mesh.size = Vector3(.45, .45, .45)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("5bd2e7")
	mesh.material = material
	for index in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 256)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		targets.append(viewport)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 5.0
		viewport.add_child(camera)
		camera.position = Vector3(0, 0, 8)
		var branch: Node3D
		if index == 0:
			var source := MeshInstance3D.new()
			source.mesh = mesh
			source.set_base(RID())
			branch = source
		else:
			branch = Node3D.new()
			reference_mesh = MeshInstance3D.new()
			reference_mesh.mesh = mesh
			reference_mesh.hide()
			branch.add_child(reference_mesh)
		viewport.add_child(branch)
		branches.append(branch)
		var child := MeshInstance3D.new()
		child.mesh = mesh
		child.position = Vector3(.7, .4, 0)
		branch.add_child(child)
		var grandchild := MeshInstance3D.new()
		grandchild.mesh = mesh
		grandchild.position = Vector3(-1.4, -.8, 0)
		child.add_child(grandchild)
	for interpolated in [false, true]:
		physics_interpolation = interpolated
		for restored in [false, true, false]:
			branches[0].set_base(mesh.get_rid() if restored else RID())
			reference_mesh.visible = restored
			for sample in 18:
				await physics_frame
				for branch in branches:
					branch.position = Vector3(sin(sample * .4) * 1.2, cos(sample * .4) * .8, 0)
					branch.rotation.z = sample * .14
				await process_frame
				await RenderingServer.frame_post_draw
				_compare(
					targets[0].get_texture().get_image(),
					targets[1].get_texture().get_image(),
					"%s/%s/%d" % [interpolated, restored, sample]
				)
	print(
		(
			"Empty mesh transforms: %d failures across %d image comparisons"
			% [failures.size(), comparisons]
		)
	)
	for failure in failures:
		push_error(failure)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _compare(actual: Image, expected: Image, label: String):
	comparisons += 1
	var visible := 0
	var differences := 0
	for y in actual.get_height():
		for x in actual.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			if b.g > .3:
				visible += 1
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > .03:
				differences += 1
	if visible < 200 or differences > 12:
		failures.append("%s: %d visible, %d different" % [label, visible, differences])
