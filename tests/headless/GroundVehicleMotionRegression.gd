extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _vehicle()
	await _unchanged_roles()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Ground vehicle motion: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _vehicle():
	var actor = _spawn_motion("Tank", Vector3(49, 0, 48))
	await _frames(30)
	var movement = actor.get_node("Movement")
	var origin = actor.position
	var goal = Vector3(59, 0, 48)
	var orders = load("res://source/match/orders/ManualOrders.gd")
	actor.manual_orders.submit(orders.point_order("move", goal))
	var early = []
	var previous = actor.position
	for frame in 4:
		await physics_frame
		early.append(previous.distance_to(actor.position) * Engine.physics_ticks_per_second)
		previous = actor.position
	_check(actor.position.distance_to(origin) > 0, "Vehicle did not respond promptly")
	_check(
		early.max() < movement.speed * 0.8,
		"Vehicle still jumps to cruise speed on its first frames"
	)
	_check(
		movement.velocity.length() > 0 and movement.velocity.length() < movement.speed,
		"Acceleration window is not observable"
	)
	paused = true
	var before = movement.velocity
	var point = actor.position
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Mid-acceleration snapshot failed: " + builder.error)
	if snapshot == null:
		return
	var id = builder._reference(actor)
	var restore = Restore.new()
	var result = await restore.restore(self, snapshot)
	_check(result.ok, "Mid-acceleration restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	actor = restore.entities[id]
	movement = actor.get_node("Movement")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT if unit == actor else Node.PROCESS_MODE_DISABLED
		)
	await _frames(5)
	_check(
		actor.position == point and movement.velocity == before,
		"Paused load altered intermediate motion"
	)
	var top = 0.0
	var slow_final = false
	paused = false
	for frame in 600:
		await physics_frame
		var requested = movement.velocity.length()
		top = maxf(top, requested)
		if actor.global_position_yless.distance_to(goal) < 0.5 and requested > 0:
			slow_final = slow_final or requested < movement.speed * 0.75
		if not movement._has_destination:
			break
	_check(top >= movement.speed * 0.95, "Vehicle acceleration never reached cruise speed")
	_check(slow_final, "Vehicle did not brake on final approach")
	_check(
		actor.global_position_yless.distance_to(goal) < 0.4, "Vehicle did not settle at destination"
	)
	var settled = actor.position
	await _frames(30)
	_check(actor.position.distance_to(settled) < 0.03, "Settled vehicle kept shuffling")
	var recruit_speed = movement.speed
	actor.experience = 600
	_check(
		is_equal_approx(movement.speed, recruit_speed * 1.09),
		"Vehicle throttle lost veterancy speed"
	)
	actor.manual_orders.submit(orders.point_order("move", Vector3(49, 0, 48)))
	actor.manual_orders.submit(orders.point_order("move", Vector3(57, 0, 48)), true)
	for frame in 1200:
		await physics_frame
		if not actor.manual_orders._engaged:
			break
	_check(
		not actor.manual_orders._engaged and actor.position.distance_to(Vector3(57, 0, 48)) < 0.4,
		"Reversed queued moves did not complete"
	)
	actor.manual_orders.submit(orders.point_order("move", Vector3(49, 0, 48)))
	await _frames(15)
	actor.issue_manual_order(null)
	_check(
		not movement._has_destination and movement.velocity == Vector3.ZERO,
		"Explicit Stop retained momentum"
	)
	print(
		"PASS actual launch ramp, braking, settling, queued reversal, pause/load, rank and Stop; early=",
		early
	)
	actor.queue_free()
	await _frames(3)


func _unchanged_roles():
	for role in ["Infantry", "Worker", "Tank"]:
		var actor = _spawn_motion(role, Vector3(49, 0, 48))
		await _frames(10)
		var movement = actor.get_node("Movement")
		if role == "Tank":
			movement.ghosted = true
		var desired = movement._ground_velocity(Vector3.RIGHT, 10, 1.0 / 30, movement.speed)
		_check(
			is_equal_approx(desired.length(), movement.speed),
			role + ": instant nonvehicle/ghosted movement changed"
		)
		actor.queue_free()
		await _frames(3)
	print("PASS infantry, engineers and ghosted units retain their movement")


func _spawn_motion(role, point):
	var actor = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(actor, Transform3D(Basis(), point), game._get_human_player(), false)
	actor.stance = actor.Stance.HOLD_FIRE
	return actor
