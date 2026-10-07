extends "res://tests/headless/GuardArrivalRegression.gd"

const ENDPOINT_ARCHIVE = "res://docs/playtests/2026-10-06/regional-recovery/stall0.json"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _earned_endpoint()
	for faction in ["frontier"]:
		for mode in ["preset", "lua", "visual"]:
			await _endpoint_case(faction, mode)
	for message in errors:
		push_error(message)
	print("Guard endpoint: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _endpoint_case(faction, mode):
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(ENDPOINT_ARCHIVE))
	_check(loaded.ok, "Endpoint archive failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	var original = restore.entities["unit-11"]
	var center = original.program.anchor
	var point = original.position
	var owner = original.player
	_check(owner.faction == faction, "Endpoint fixture faction differs from archive")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	# Preserve the earned structures and navigation. Remove mobile traffic to
	# isolate completed-path arrival in each supported authoring form.
	for other in get_nodes_in_group("units"):
		if other.movement_speed > 0:
			other.queue_free()
	await _frames(6)
	var unit = _actor("Tank", owner, point)
	await _frames(6)
	game.battlefield.invalidate()
	_assign(unit, center, mode)
	paused = false
	await _frames(480)
	paused = true
	var movement = unit.get_node("Movement")
	var label = faction + "-" + mode
	print(
		"ENDPOINT ",
		label,
		" position=",
		unit.position,
		" anchor=",
		center,
		" state=",
		unit.program.mode,
		" reason=",
		unit.program.reason
	)
	_check(unit.position.distance_to(center) > 1.0, "Fixture did not retain projected endpoint")
	_check(unit.program.mode == "Running", label + ": completed guard endpoint became Blocked")
	_check(unit.action.is_settled_guard(), label + ": endpoint did not settle")
	_check(not movement._has_destination, label + ": guard keeps reissuing completed travel")
	_check(unit.program.anchor == center, "Endpoint moved the assigned guard area")
	await _review_endpoint(unit, label)
	if unit.program.mode == "Running":
		await _persist_endpoint(unit, label)
	paused = false
	game.queue_free()
	await _frames(5)


func _persist_endpoint(unit, label):
	var point = unit.position
	var center = unit.program.anchor
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(unit)
	var file = "user://guard-endpoint-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(file, data), "Endpoint save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Endpoint reload failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	unit = restore.entities[id]
	_check(unit.position == point and unit.program.anchor == center, "Paused reload moved guard")
	paused = false
	await _frames(360)
	_check(
		unit.program.mode == "Running" and unit.action.is_settled_guard(),
		"Reload lost settled endpoint"
	)
	_check(unit.position.distance_to(point) < 0.05, "Reload restarted completed travel")
	paused = true
	await _review_endpoint(unit, label + "-restored")
	await _endpoint_bounds(unit)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != unit.player)[0]
	var raider = _actor("Infantry", enemy, point + Vector3(-4, 0, 0))
	var hp = raider.hp
	paused = false
	await _frames(180)
	_check(
		not is_instance_valid(raider) or raider.hp < hp, "Settled endpoint ignored nearby combat"
	)
	if is_instance_valid(raider):
		raider.queue_free()
	paused = true
	# An explicit manual order still takes authority and leaves this point.
	unit.manual_orders.submit({"kind": "move", "point": point + Vector3(-7, 0, 0)})
	_check(unit.program.mode == "Manual", "Endpoint ignored manual authority")
	paused = false
	await _frames(360)
	_check(unit.position.distance_to(point) > 2, "Manual order could not leave endpoint")


func _review_endpoint(_unit, _label):
	pass


func _earned_endpoint():
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(ENDPOINT_ARCHIVE))
	_check(loaded.ok, "Unchanged earned archive failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	var unit = restore.entities["unit-11"]
	var anchor = unit.program.anchor
	await _frames(12)
	_check(unit.program.mode == "Blocked", "Restoration silently resumed a blocked program")
	_check(unit.program.run(), "Earned guard rejected explicit Resume")
	paused = false
	await _frames(720)
	paused = true
	_check(
		is_instance_valid(unit) and unit.program.mode == "Running",
		"Earned live guard blocked after Resume"
	)
	_check(unit.program.anchor == anchor, "Earned guard assignment changed")
	print(
		"EARNED ENDPOINT state=",
		unit.program.mode,
		" reason=",
		unit.program.reason,
		" position=",
		unit.position
	)
	await _review_endpoint(unit, "earned-live")
	paused = false
	game.queue_free()
	await _frames(5)


func _endpoint_bounds(unit):
	var action = unit.action
	var movement = unit.get_node("Movement")
	var point = unit.position
	var center = unit.program.anchor
	action.set_physics_process(false)
	action._guard_settled_at = null
	action._destination = center
	movement.move(center)
	paused = false
	await _frames(12)
	paused = true
	_check(movement.is_navigation_finished(), "Bounds fixture lacks completed navigation")
	_check(action._guard_point_reached(center, 6), "Completed endpoint not recognized")
	action._destination = center + Vector3(4, 0, 0)
	_check(not action._guard_point_reached(center, 6), "Unrelated action destination accepted")
	action._destination = center
	movement.move(center + Vector3(4, 0, 0))
	_check(not action._guard_point_reached(center, 6), "Unrelated navigation target accepted")
	movement.move(center)
	paused = false
	await _frames(12)
	paused = true
	var tolerance = movement.path_desired_distance
	movement.path_desired_distance = .01
	_check(
		not action._guard_point_reached(center, 6), "Endpoint distance ignored navigation tolerance"
	)
	movement.path_desired_distance = tolerance
	unit.position = center + Vector3(-3, 0, 0)
	action._guard_settled_at = center
	_check(
		not action._guard_point_reached(center, 6), "Settled guard accepted distant displacement"
	)
	unit.position = point
	_check(not action._guard_point_reached(center, .5), "Endpoint arrival escaped assigned radius")
	var factory = _units(unit.player, "VehicleFactory")[0]
	_check(
		not action._guard_point_reached(factory.position, 6),
		"Endpoint arrival accepted a structure center"
	)
	movement.stop()
	action._destination = null
	action._guard_settled_at = center
	action._stalled = 0.0
	action.set_physics_process(true)
