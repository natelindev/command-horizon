extends "res://tests/headless/SaveRestoreEdges.gd"

const CROWD_ARCHIVE = (
	"res://docs/playtests/2026-10-04/" + "mixed-operations-responsive-bastion-stall.json"
)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _endpoint_eligibility()
	for repetition in 3:
		await _captured_return(repetition)
	await _distant_endpoint()
	await _enemy_blocker()
	await _queue_archive()
	for error in errors:
		push_error(error)
	print("Crowded destination: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _endpoint_eligibility():
	var unit = await _open_capture()
	if unit == null:
		return
	var movement = unit.get_node("Movement")
	# Establish the restored path while paused, then exercise only the live
	# endpoint predicate so avoidance cannot move the eligibility fixtures.
	movement.get_next_path_position()
	var path = movement.get_current_navigation_path()
	_check(not path.is_empty(), "Endpoint eligibility fixture has no restored path")
	if path.is_empty():
		game.queue_free()
		paused = false
		await _frames(5)
		return
	var end: Vector3 = path[-1] * Vector3(1, 0, 1)
	var blocker
	var structure
	for other in unit.player.get_children():
		if other == unit or not other.is_in_group("units"):
			continue
		var navigation = other._get_navigation_trait()
		if navigation is NavigationAgent3D:
			navigation.ghosted = true
			navigation._has_destination = false
			navigation.velocity = Vector3.ZERO
			if blocker == null:
				blocker = other
		elif structure == null and navigation != null:
			structure = other
	_check(blocker != null and structure != null, "Endpoint fixture lacks mobile/structure bodies")
	if blocker != null and structure != null:
		var maximum: float = root.get_node("Constants").Match.Terrain.Navmesh.MAX_AGENT_RADIUS
		var neighbor = blocker.get_node("Movement")
		movement.radius = maximum
		neighbor.radius = maximum
		neighbor.ghosted = false
		neighbor.speed = 1.0
		unit.position = end + Vector3(0, 0, -(maximum * 2.0 + .1))
		blocker.position = end + Vector3(maximum * 2.0 - .01, 0, 0)
		# A large static body is present at the endpoint throughout these checks.
		# It must neither satisfy occupancy nor change the mobile-radius policy.
		structure.position = end
		structure._get_navigation_trait().radius = 4.0
		game.battlefield.invalidate()
		_check(movement.has_occupied_endpoint(false), "Maximum-radius settled ally was missed")
		blocker.position.x += .02
		_check(not movement.has_occupied_endpoint(false), "Ally beyond contact radius was accepted")
		blocker.position.x -= .02
		_check(movement.has_occupied_endpoint(false), "Same-tick ally position was stale")
		neighbor.radius = maximum * .5
		_check(not movement.has_occupied_endpoint(false), "Same-tick smaller ally radius was stale")
		neighbor.radius = maximum
		neighbor.ghosted = true
		_check(
			not movement.has_occupied_endpoint(false), "Ghost or static structure satisfied arrival"
		)
		neighbor.ghosted = false
		neighbor.speed = 0.0
		_check(
			not movement.has_occupied_endpoint(false), "Zero-speed ally satisfied mobile arrival"
		)
		neighbor.speed = 1.0
		neighbor.domain = root.get_node("Constants").Match.Navigation.Domain.AIR
		_check(not movement.has_occupied_endpoint(false), "Other-domain ally satisfied arrival")
		neighbor.domain = movement.domain
		neighbor._has_destination = true
		_check(
			not movement.has_occupied_endpoint(false), "Travelling ally satisfied settled arrival"
		)
		neighbor._has_destination = false
		neighbor.velocity = Vector3.RIGHT
		_check(not movement.has_occupied_endpoint(false), "Moving ally satisfied settled arrival")
		neighbor.velocity = Vector3.ZERO
		_check(movement.has_occupied_endpoint(false), "Restored live eligibility was not observed")
		blocker.queue_free()
		_check(not movement.has_occupied_endpoint(false), "Queued deletion satisfied arrival")
		print(
			"PASS live maximum-radius, position, ghost, speed, domain and settled endpoint filters"
		)
	game.queue_free()
	paused = false
	await _frames(5)


func _captured_return(repetition):
	var unit = await _open_capture()
	if unit == null:
		return
	var movement = unit.get_node("Movement")
	var start = unit.position
	var hp = unit.hp
	# Observe completion of the archived Move. Aggressive idle acquisition can
	# immediately start a separate pursuit after that command finishes.
	unit.stance = unit.Stance.HOLD_FIRE
	_check(
		unit.action.get_script().resource_path.ends_with("/Moving.gd"),
		"Capture no longer contains plain Move"
	)
	_check(movement._has_destination, "Capture lost its active destination")
	paused = false
	var max_step = 0.0
	var previous = start
	for frame in 240:
		await physics_frame
		max_step = maxf(max_step, unit.position.distance_to(previous))
		previous = unit.position
	_check(not movement._has_destination, "Captured unit kept pushing into the occupied endpoint")
	_check(unit.hp > hp, "Captured infantry could not start ordinary barracks treatment")
	_check(
		unit.position.distance_to(start) < 1.0,
		"Crowded arrival moved the unit to another destination"
	)
	_check(
		max_step <= unit.movement_speed / Engine.physics_ticks_per_second + 0.002,
		"Crowded arrival teleported the unit"
	)
	print(
		"CROWDED ARRIVAL ",
		repetition,
		" travel=",
		unit.position.distance_to(start),
		" hp=",
		hp,
		" -> ",
		unit.hp,
		" max_step=",
		max_step
	)
	game.queue_free()
	await _frames(5)


func _open_capture():
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(CROWD_ARCHIVE))
	_check(result.ok, "Captured recovery archive failed to restore")
	if not result.ok:
		return null
	game = result.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	return restore.entities["unit-13"]


func _distant_endpoint():
	var unit = await _open_capture()
	if unit == null:
		return
	unit.position += Vector3(4, 0, -1)
	unit.get_node("Movement").speed = 0.05
	var action = unit.action
	paused = false
	await _frames(240)
	_check(
		unit.action == action and unit.get_node("Movement")._has_destination,
		"Crowded endpoint completed a distant Move"
	)
	print("PASS distant occupied endpoint retains movement")
	game.queue_free()
	await _frames(5)


func _enemy_blocker():
	var unit = await _open_capture()
	if unit == null:
		return
	var blockers = unit.player.get_children().filter(
		func(other):
			return (
				other != unit
				and other.is_in_group("units")
				and other.type == "Infantry"
				and other.position.distance_to(unit.position) < 1.5
			)
	)
	_check(blockers.size() == 1, "Capture no longer has the expected settled blocker")
	var enemy = get_nodes_in_group("players").filter(func(player): return player != unit.player)[0]
	for blocker in blockers:
		blocker.reparent(enemy, true)
		blocker.hp = 10000
		blocker.action.process_mode = Node.PROCESS_MODE_DISABLED
		# Keep the claimed occupied endpoint stationary. Disabling its action
		# alone leaves passive avoidance free to move it out of the way.
		blocker.get_node("Movement").avoidance_enabled = false
		blocker.get_node("Movement").set_physics_process(false)
	var blocker_points = blockers.map(func(blocker): return blocker.position)
	var action = unit.action
	paused = false
	await _frames(240)
	_check(
		blockers.map(func(blocker): return blocker.position) == blocker_points,
		"Enemy occupancy fixture moved"
	)
	_check(
		unit.action == action and unit.get_node("Movement")._has_destination,
		"Enemy occupancy ended a blind Move"
	)
	print("PASS enemy blocker does not satisfy friendly arrival")
	game.queue_free()
	await _frames(5)


func _queue_archive():
	var unit = await _open_capture()
	if unit == null:
		return
	var point = Vector3(30, 0, 15)
	_check(
		unit.manual_orders.submit({"kind": "move", "point": point}, true),
		"Queued follow-up was refused"
	)
	var snapshotter = Snapshot.new()
	var record = snapshotter.capture(game)
	var id = snapshotter._reference(unit)
	var nearby = unit.player.get_children().filter(
		func(other):
			return (
				other != unit
				and other.is_in_group("units")
				and other.type == "Infantry"
				and other.position.distance_to(unit.position) < 1.5
			)
	)
	var blocker = nearby[0]
	var blocker_id = snapshotter._reference(blocker)
	var disk = "user://crowded-arrival-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, record), "Crowded queue disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(result.ok, "Crowded queue disk restore failed")
	if not result.ok:
		return
	game = result.game
	unit = restore.entities[id]
	blocker = restore.entities[blocker_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var hp = unit.hp
	var position = unit.position
	await _frames(180)
	_check(
		unit.position == position and unit.hp == hp and unit.manual_orders.pending.size() == 1,
		"Paused arrival changed position, healing or orders"
	)
	paused = false
	var handoff = -1.0
	var started = game.simulation_time
	for frame in 720:
		await physics_frame
		if handoff < 0 and unit.manual_orders.pending.is_empty():
			handoff = game.simulation_time - started
			# The same infantry also blocks this narrow exit. Clear it after the
			# first order hands off, so the next route can make ordinary progress.
			blocker.issue_manual_order(
				load("res://source/match/units/actions/Moving.gd").new(Vector3(36, 0, 15))
			)
	_check(handoff > 0 and handoff < 3, "Crowded Move did not hand off its queued order promptly")
	_check(
		unit.position.distance_to(point) < 0.5, "Queued Move failed to reach its own destination"
	)
	print("PASS paused disk queue handoff=", handoff, " destination=", unit.position)
	game.queue_free()
	await _frames(5)
