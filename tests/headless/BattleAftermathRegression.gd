extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var aftermath = load("res://source/match/effects/BattleAftermath.gd").new()
	root.add_child(aftermath)
	var preferences = root.get_node("Globals").options
	var reduced = preferences.reduced_flashes
	preferences.reduced_flashes = false
	aftermath.burst(Vector3(8, 3, 8), 1.2, false)
	_check(aftermath.scars.is_empty(), "Air impact scarred ground")
	_check(aftermath.debris.size() <= 5, "Single blast creates excessive debris")
	aftermath.burst(Vector3(8, 0.5, 8), 1.2, true)
	_check(aftermath.scars.size() == 1, "Ground blast lacks scar")
	aftermath.advance(10.0)
	aftermath.burst(Vector3(8, 0.5, 8), 1.2, true)
	_check(aftermath.scars.size() == 1, "Repeated hit stacks ground planes")
	_check(aftermath.scars[0].age == 0, "Repeated hit did not refresh scar")
	for index in range(120):
		aftermath.burst(Vector3(index * 4, 0.5, 14), 2, true)
	_check(aftermath.scars.size() <= aftermath.MAX_SCARS, "Unbounded scars")
	_check(aftermath.debris.size() <= 32, "Debris exceeds visual clutter budget")
	_check(aftermath.lights.size() <= aftermath.MAX_LIGHTS, "Unbounded blast lights")
	preferences.reduced_flashes = true
	aftermath.advance(0.02)
	aftermath.burst(Vector3(8, 0.5, 8), 2, true)
	_check(aftermath.lights.is_empty(), "Reduced flashes still emits blast lights")
	for entry in aftermath.debris:
		_check(entry.node is RigidBody3D, "Debris bypasses physics engine")
		_check(
			entry.node.collision_layer == 0 and entry.node.collision_mask == 1,
			"Debris participates in gameplay collisions"
		)
		_check(not entry.node.input_ray_pickable, "Debris steals unit targeting")

	for _index in range(180):
		aftermath.advance(1.0 / 60.0)
	_check(aftermath.debris.is_empty(), "Debris lingers beyond three seconds")
	_check(not aftermath.scars.is_empty(), "Ground damage vanished with debris")
	aftermath.advance(aftermath.SCAR_LIFETIME)
	_check(aftermath.scars.is_empty(), "Old scars never expire")
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape = CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	aftermath.burst(Vector3(0, 1, 0), 1.0, false)
	var body = aftermath.debris[0].node
	var start = body.position
	for _index in range(25):
		await physics_frame
	_check(body.position.y > start.y, "Physics impulse did not lift fragment")
	paused = true
	var frozen_position = body.position
	for _index in range(12):
		await physics_frame
	_check(body.position == frozen_position, "Physics debris moved during tactical pause")
	paused = false
	for _index in range(150):
		await physics_frame
	_check(
		body.position.y > -0.05 and body.position.y < 0.2,
		"Fragment did not collide/settle on ground"
	)
	_check(body.linear_velocity.length() < 0.3, "Fragment failed to dissipate impact energy")
	floor_body.queue_free()
	preferences.reduced_flashes = reduced
	aftermath.queue_free()
	await process_frame
	await process_frame
	print("Battle aftermath regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value:
		errors.append(message)
		push_error(message)
