extends "res://tests/headless/SaveRestoreEdges.gd"

const CAPTURE = "res://docs/playtests/2026-10-04/corner-recovery-final-match-2-stall.json"
var watched
var buddy
var started
var original_point
var largest_step = 0.0
var least_clearance = INF


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for repetition in 3:
		await _open_capture()
		await _arrival("capture-%d" % repetition)
		await _close()
	# Retain coverage of short polygon tails even when the shipping path
	# simplifier removes redundant points from the same captured route.
	await _open_capture()
	var movement = watched.get_node("Movement")
	movement.simplify_path = false
	var destination = movement.target_position
	movement.target_position = destination
	await _arrival("unsimplified-capture", true)
	await _close()
	await _disk_queue()
	await _manual_replacement()
	for faction in ["bastion", "helix"]:
		await _fresh(faction)
		await _arrival("fresh-" + faction)
		await _close()
	await _route_detour()
	for exclusion in ["enemy", "moving", "air", "distant", "empty"]:
		await _excluded_neighbor(exclusion)
	for error in errors:
		push_error(error)
	print("Endpoint tail: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_capture():
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(CAPTURE))
	_check(result.ok, "Endpoint capture failed to restore")
	game = result.game
	watched = restore.entities["unit-42"]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	original_point = watched.get_node("Movement").target_position
	_check(
		watched.action.get_script().resource_path.ends_with("/Moving.gd"),
		"Capture lost its plain Move"
	)


func _arrival(label, require_path_bend = false):
	var movement = watched.get_node("Movement")
	var origin = watched.position
	var previous = origin
	var finished_after = -1.0
	largest_step = 0.0
	least_clearance = INF
	started = game.simulation_time
	var saw_short_tail = false
	paused = false
	for frame in 360:
		await physics_frame
		largest_step = maxf(largest_step, watched.position.distance_to(previous))
		previous = watched.position
		var points = movement.get_current_navigation_path()
		if movement._has_destination and points.size() > 2:
			saw_short_tail = (
				saw_short_tail or movement.get_current_navigation_path_index() < points.size() - 1
			)
		if not movement._has_destination and finished_after < 0:
			finished_after = game.simulation_time - started
		for other in get_nodes_in_group("units"):
			if (
				other != watched
				and other.hp > 0
				and other.movement_domain == watched.movement_domain
			):
				least_clearance = minf(
					least_clearance,
					watched.position.distance_to(other.position) - watched.radius - other.radius
				)
	if require_path_bend:
		_check(saw_short_tail, "Fixture did not exercise a remaining path bend: " + label)
	_check(
		finished_after > 0 and finished_after < 4.2, "Short occupied route never finished: " + label
	)
	_check(not movement._has_destination, "Completed route resumed: " + label)
	_check(
		not watched.action.get_script().resource_path.ends_with("/Moving.gd"),
		"Finished Move did not retire: " + label
	)
	_check(watched.position.distance_to(origin) < 1, "Arrival moved to a different area: " + label)
	_check(largest_step <= watched.movement_speed / 60.0 + .002, "Arrival exceeded speed: " + label)
	_check(least_clearance >= -.08, "Arrival crossed a footprint: " + label)
	print(
		"ENDPOINT ARRIVAL ",
		label,
		" seconds=",
		finished_after,
		" travel=",
		watched.position.distance_to(origin),
		" step=",
		largest_step,
		" clearance=",
		least_clearance
	)
	await _review(label)


func _disk_queue():
	await _open_capture()
	var point = Vector3(100, 0, 52)
	_check(
		watched.manual_orders.submit({"kind": "move", "point": point}, true),
		"Queued follow-up refused"
	)
	paused = false
	await _frames(30)
	paused = true
	var position = watched.position
	var clock = game.simulation_time
	var elapsed = watched.action._arrival_elapsed
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(watched)
	_check_archive_validation(data, id)
	var disk = "user://endpoint-tail-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, data), "Queue disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(result.ok, "Queue disk restore failed")
	game = result.game
	watched = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(60)
	_check(watched.position == position and game.simulation_time == clock, "Paused queue advanced")
	_check(
		watched.action._arrival_elapsed == elapsed and watched.manual_orders.pending.size() == 1,
		"Paused queue state changed"
	)
	var handoff = -1.0
	paused = false
	for frame in 720:
		await physics_frame
		if watched.manual_orders.pending.is_empty() and handoff < 0:
			handoff = game.simulation_time - clock
	_check(handoff > 0 and handoff < 4, "Occupied route did not hand off queue")
	_check(
		watched.position.distance_to(point) < .6, "Queued route did not reach its clear destination"
	)
	print("ENDPOINT QUEUE handoff=", handoff, " distance=", watched.position.distance_to(point))
	await _close()


func _manual_replacement():
	await _open_capture()
	var point = Vector3(100, 0, 52)
	_assign_move(point)
	var position = watched.position
	await _frames(30)
	_check(watched.position == position, "Paused replacement moved")
	paused = false
	await _frames(600)
	_check(watched.position.distance_to(point) < .6, "Replacement did not reach new point")
	watched.issue_manual_order(null)
	_check(not watched.get_node("Movement")._has_destination, "Stop retained route")
	await _close()


func _fresh(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/IndustrialCrossroads.tscn"
	)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(30)
	var human = game._get_human_player()
	var player = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	# Use the eastern lab geometry with fresh units of each faction.
	watched = _actor("Tank", player, Vector3(105.5541, 0, 50.35256))
	buddy = _actor("AdvancedTank", player, Vector3(107.2818, 0, 50.88178))
	_actor("Tank", player, Vector3(104.778, 0, 48.72841))
	await _frames(30)
	original_point = Vector3(107, 0, 49)
	_assign_move(original_point)


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _review(_label):
	return true


func _close():
	paused = false
	game.queue_free()
	await _frames(5)


func _route_detour():
	await _fresh("bastion")
	for other in get_nodes_in_group("units"):
		if other.movement_speed > 0 and other not in [watched, buddy]:
			other.queue_free()
	await _frames(5)
	watched.issue_manual_order(null)
	watched.position = Vector3(106.75, 0, 45.25)
	buddy.position = Vector3(109, 0, 45.25)
	var point = Vector3(108.5, 0, 45.25)
	var movement = watched.get_node("Movement")
	movement.speed = .01
	_assign_move(point)
	var action = watched.action
	var longest_route = 0.0
	var nearby_occupied = false
	for frame in 180:
		await physics_frame
		var points = movement.get_current_navigation_path()
		var length = 0.0
		var previous = watched.position
		for index in range(movement.get_current_navigation_path_index(), points.size()):
			var next = points[index] * Vector3(1, 0, 1)
			length += previous.distance_to(next)
			previous = next
		longest_route = maxf(longest_route, length)
		nearby_occupied = nearby_occupied or movement.has_occupied_endpoint(false)
		_check(
			watched.action == action and movement._has_destination,
			"Arrival skipped the route around an obstacle"
		)
	_check(nearby_occupied, "Detour fixture lacks a nearby occupied endpoint")
	_check(longest_route > 6, "Detour fixture no longer requires a long route")
	_check(watched.position.distance_to(point) < 2, "Detour fixture is not geometrically nearby")
	print("ENDPOINT DETOUR direct=", watched.position.distance_to(point), " route=", longest_route)
	await _close()


func _excluded_neighbor(exclusion):
	await _fresh("helix")
	for other in get_nodes_in_group("units"):
		if other.movement_speed > 0 and other not in [watched, buddy]:
			other.queue_free()
	await _frames(5)
	watched.get_node("Movement").speed = .01
	match exclusion:
		"enemy":
			var enemy = get_nodes_in_group("players").filter(func(side): return side != watched.player)[0]
			buddy.reparent(enemy, true)
			buddy.action.process_mode = Node.PROCESS_MODE_DISABLED
		"moving":
			buddy.get_node("Movement").move(Vector3(114, 0, 50))
			buddy.get_node("Movement").set_physics_process(false)
		"air":
			var point = buddy.position
			buddy.queue_free()
			buddy = _actor("Drone", watched.player, point)
			await _frames(10)
		"distant":
			watched.position = Vector3(101, 0, 50)
		"empty":
			buddy.queue_free()
	var action = watched.action
	await _frames(180)
	_check(
		watched.action == action and watched.get_node("Movement")._has_destination,
		"Invalid crowded completion: " + exclusion
	)
	print(
		"ENDPOINT EXCLUSION ", exclusion, " active=", watched.get_node("Movement")._has_destination
	)
	await _close()


func _check_archive_validation(data, id):
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	var index = -1
	for i in data.units.size():
		if data.units[i].id == id:
			index = i
	_check(index >= 0, "Archive lost arrival unit")
	if index < 0:
		return
	_check(schema.validate(data), "New arrival fields failed validation")
	for invalid in [-.1, 2.1, INF, "invalid"]:
		var changed = data.duplicate(true)
		changed.units[index].action.state._arrival_elapsed = invalid
		_check(not schema.validate(changed), "Invalid arrival timer accepted")
	for field in ["_arrival_elapsed", "_arrival_progress"]:
		var changed = data.duplicate(true)
		changed.units[index].action.state.erase(field)
		_check(not schema.validate(changed), "Partial arrival observation accepted")
	var missing_position = data.duplicate(true)
	missing_position.units[index].action.state._arrival_progress = null
	_check(not schema.validate(missing_position), "Active arrival timer lacks origin")
	# Version 15 archives always carry the arrival observation.
	var incomplete = data.duplicate(true)
	incomplete.units[index].action.state.erase("_arrival_elapsed")
	incomplete.units[index].action.state.erase("_arrival_progress")
	_check(not schema.validate(incomplete), "Move archive without arrival state accepted")
	print("ENDPOINT ARCHIVE missing and corrupt-state checks")


func _assign_move(point):
	watched.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(point))
