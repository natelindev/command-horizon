class_name ParticleQueueLifetimeMainLoop
extends SceneTree

## Emitter teardown overlaps threaded scene culling. Complete camera-facing
## updates in their render pass, before queued resource frees can run.


func _initialize():
	_run.call_deferred()


func _run():
	root.size = Vector2i(640, 480)
	var world = Node3D.new()
	root.add_child(world)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 8, 10)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	camera.current = true
	var mesh = QuadMesh.new()
	mesh.size = Vector2(.2, .2)
	var surface = StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.albedo_color = Color(.2, .8, 1)
	mesh.material = surface
	# Exceed the default parallel-culling threshold without extra visible draws.
	for index in 1024:
		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(instance)
		instance.position = Vector3(100 + index * .25, 0, 0)
	var process = ParticleProcessMaterial.new()
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = .2
	process.initial_velocity_max = .4
	process.direction = Vector3.UP
	var batches = []
	for cycle in 48:
		var batch = Node3D.new()
		world.add_child(batch)
		for index in 96:
			var particles = GPUParticles3D.new()
			particles.amount = 8
			particles.lifetime = 1.0
			particles.preprocess = .3
			particles.process_material = process
			particles.draw_pass_1 = mesh
			particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
			particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
			particles.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
			batch.add_child(particles)
			particles.position = Vector3(index % 12 - 5.5, 0, floori(index / 12.0) - 3.5)
		batches.append(batch)
		for frame in 3:
			await process_frame
		if batches.size() > 2:
			batches.pop_front().free()
	for batch in batches:
		batch.free()
	for frame in 8:
		await process_frame
	world.free()
	print("Particle queue lifetime: completed 4608 emitters")
	await root.get_node("Globals").quit_game(0)
