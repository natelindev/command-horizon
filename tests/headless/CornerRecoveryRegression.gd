extends "res://tests/headless/SaveRestoreEdges.gd"

const CORNER_ARCHIVE = "res://docs/playtests/2026-10-04/guard-travel-after-3-0.json"
const RETURN_ARCHIVE = (
	"res://docs/playtests/2026-10-05/harvest-traffic/" + "simplified-corner-end-capture-0.json"
)
var watched
var support
var anchor
var last_position
var recovery_origin
var maximum_excursion = 0.0
var maximum_settled_distance = 0.0
var first_settled = -1.0
var observation_started = 0.0
var maximum_step = 0.0
var minimum_mobile_clearance = INF
var minimum_static_clearance = INF
var seen_recovery = false
var trace_label = ""
var overlap_captured = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for trial in 3:
		await _open_corner()
		await _travel("capture-%d" % trial)
		await _close()
	await _archive_recovery()
	await _manual_authority()
	for faction in ["bastion", "helix"]:
		await _fresh_corner(faction)
		await _travel("fresh-" + faction)
		await _close()
	await _displaced_return()
	for error in errors:
		push_error(error)
	print("Corner recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_corner():
	var data = FileStore.new().read_file(CORNER_ARCHIVE)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Corner archive did not restore")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	watched = restore.entities["unit-13"]
	support = restore.entities["unit-14"]
	anchor = watched.program.anchor
	_check(paused and game.simulation_time == data.simulation_time, "Load advanced the saved clock")
	_check(watched.program.mode == "Running", "Corner capture was already blocked")
	_check(watched.action._stalled > 4, "Replay reset the saved no-progress timer")
	_check(
		support.action.repair_target() == restore.entities["unit-12"], "Repair assignment changed"
	)
	_check_publication(Vector3(22, 0, 40))
	_reset_measurements()


func _check_publication(building_point):
	var navmap = game.navigation.terrain.navigation_map_rid
	var closest = (
		NavigationServer3D.map_get_closest_point(navmap, building_point) * Vector3(1, 0, 1)
	)
	_check(game.navigation.terrain.is_synchronized(), "Latest navigation mesh is not published")
	_check(closest.distance_to(building_point) >= 1.8, "Loaded navigation admits the lab interior")


func _reset_measurements():
	last_position = watched.position
	recovery_origin = watched.position
	maximum_excursion = 0.0
	maximum_settled_distance = 0.0
	first_settled = -1.0
	observation_started = game.simulation_time
	maximum_step = 0.0
	minimum_mobile_clearance = INF
	minimum_static_clearance = INF
	seen_recovery = false


func _observe():
	maximum_excursion = maxf(maximum_excursion, watched.position.distance_to(recovery_origin))
	if (
		watched.action != null
		and watched.action.has_method("is_settled_guard")
		and watched.action.is_settled_guard()
		and not watched.get_node("Movement")._has_destination
	):
		maximum_settled_distance = maxf(
			maximum_settled_distance, watched.position.distance_to(anchor)
		)
		if first_settled < 0:
			first_settled = game.simulation_time - observation_started
	maximum_step = maxf(maximum_step, watched.position.distance_to(last_position))
	last_position = watched.position
	seen_recovery = seen_recovery or watched.get_node("Movement")._recovery_left > 0
	for other in get_nodes_in_group("units"):
		if (
			other == watched
			or other.is_queued_for_deletion()
			or other.hp <= 0
			or other.movement_domain != watched.movement_domain
		):
			continue
		var clearance = watched.position.distance_to(other.position) - watched.radius - other.radius
		if other.movement_speed > 0:
			if clearance < minimum_mobile_clearance and clearance < -.08:
				print(
					"CORNER OVERLAP ",
					trace_label,
					" time=",
					game.simulation_time,
					" unit=",
					watched.position,
					" other=",
					other.type,
					" point=",
					other.position,
					" action=",
					other.action,
					" clearance=",
					clearance,
					" recovery=",
					watched.get_node("Movement")._recovery_left
				)
				if not overlap_captured and not trace_label.is_empty():
					var was_paused = paused
					paused = true
					var data = Snapshot.new().capture(game)
					FileStore.new().write_file(
						"res://docs/playtests/2026-10-04/corner-overlap-" + trace_label + ".json",
						data
					)
					paused = was_paused
					overlap_captured = true
			minimum_mobile_clearance = minf(minimum_mobile_clearance, clearance)
		elif other.get_node_or_null("MovementObstacle") != null:
			minimum_static_clearance = minf(minimum_static_clearance, clearance)


func _travel(label):
	trace_label = label
	overlap_captured = false
	var repair_target = support.action.repair_target()
	var reviewed_arrival = false
	paused = false
	for frame in 1200:
		await physics_frame
		_observe()
		if first_settled >= 0 and not reviewed_arrival:
			reviewed_arrival = true
			await _review_corner(label + "-arrival")
	_check(watched.program.mode == "Running", "Corner guard blocked: " + label)
	_check(
		first_settled >= 0 and first_settled <= 20,
		"Guard never reached its formation within 20 seconds: " + label
	)
	var return_after = 0.0
	if not label.begins_with("fresh-") and watched.position.distance_to(anchor) > 6:
		# Live workers can displace an arrived guard after it has formed up.
		# A continuing trip to the same anchor is not a larger formation.
		return_after = await _return_to_circle(label)
	_check(maximum_settled_distance <= 6, "Formation settled outside its original circle: " + label)
	# Live engineers keep pushing and reshaping the archived formation. An
	# arrived guard can legitimately rejoin later; stationary fresh groups
	# must still be settled at the end of the observation.
	if label.begins_with("fresh-"):
		_check(not watched.get_node("Movement")._has_destination, "Guard did not settle: " + label)
		_check(watched.action.is_settled_guard(), "Guard did not rejoin its formation: " + label)
	_check(maximum_excursion > 1, "Guard never left its blocked corner: " + label)
	_check(watched.program.anchor == anchor, "Recovery changed the assignment")
	_check(watched.position.distance_to(anchor) <= 6, "Recovery expanded the guard circle")
	_check(support.action.repair_target() == repair_target, "Recovery replaced the repair order")
	_check(maximum_step <= watched.movement_speed / 60.0 + .002, "Recovery exceeded movement speed")
	_check(minimum_mobile_clearance >= -.08, "Recovery crossed another mobile footprint")
	_check(minimum_static_clearance >= -.08, "Recovery crossed a building footprint")
	_check(seen_recovery, "Corner scenario never exercised recovery")
	print(
		"CORNER RECOVERY ",
		label,
		" position=",
		watched.position,
		" excursion=",
		maximum_excursion,
		" settled_radius=",
		maximum_settled_distance,
		" reentry_after=",
		return_after,
		" active_at_end=",
		watched.get_node("Movement")._has_destination,
		" settled_after=",
		first_settled,
		" step=",
		maximum_step,
		" mobile_clearance=",
		minimum_mobile_clearance,
		" static_clearance=",
		minimum_static_clearance
	)
	await _review_corner(label)


func _return_to_circle(label):
	var movement = watched.get_node("Movement")
	_check(not watched.action.is_settled_guard(), "Guard settled outside its circle: " + label)
	_check(
		movement._has_destination and movement.target_position.distance_to(anchor) < .1,
		"Displaced guard did not return to its assignment: " + label
	)
	var return_started = game.simulation_time
	paused = false
	for frame in 600:
		await physics_frame
		_observe()
		if watched.position.distance_to(anchor) <= 6:
			break
	_check(watched.position.distance_to(anchor) <= 6, "Guard did not re-enter within 10s: " + label)
	return game.simulation_time - return_started


func _displaced_return():
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(RETURN_ARCHIVE))
	_check(loaded.ok, "Displaced guard archive did not restore")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	watched = restore.entities["unit-13"]
	support = restore.entities["unit-14"]
	anchor = watched.program.anchor
	_check(watched.position.distance_to(anchor) > 6, "Return fixture already inside the circle")
	_reset_measurements()
	trace_label = "displaced-return"
	var elapsed = await _return_to_circle(trace_label)
	_check(watched.program.anchor == anchor, "Displaced guard changed its assignment")
	_check(maximum_step <= watched.movement_speed / 60.0 + .002, "Return exceeded movement speed")
	_check(minimum_mobile_clearance >= -.08, "Return crossed another mobile footprint")
	_check(minimum_static_clearance >= -.08, "Return crossed a building footprint")
	print("CORNER REENTRY seconds=", elapsed, " distance=", watched.position.distance_to(anchor))
	await _close()


func _archive_recovery():
	await _open_corner()
	paused = false
	for frame in 20:
		await physics_frame
		_observe()
	paused = true
	var movement = watched.get_node("Movement")
	_check(movement._recovery_left > 0, "Archive missed the active detour")
	var position = watched.position
	var clock = game.simulation_time
	var timeout = watched.action._stalled
	var remaining = movement._recovery_left
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [builder._reference(watched), builder._reference(support)]
	var store = FileStore.new()
	var path = "user://corner-recovery-%d.json" % OS.get_process_id()
	_check(store.write_file(path, data), "Recovery disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Recovery disk restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	watched = restore.entities[ids[0]]
	support = restore.entities[ids[1]]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	_check_publication(Vector3(22, 0, 40))
	await _frames(60)
	_check(game.simulation_time == clock and watched.position == position, "Paused recovery moved")
	_check(watched.action._stalled == timeout, "Load changed the no-progress clock")
	_check(
		watched.get_node("Movement")._recovery_left == remaining,
		"Paused load changed recovery time"
	)
	_reset_measurements()
	await _travel("disk-restored")
	await _close()


func _manual_authority():
	await _open_corner()
	paused = false
	await _frames(20)
	paused = true
	var movement = watched.get_node("Movement")
	_check(movement._recovery_left > 0, "Manual fixture missed recovery")
	var point = Vector3(10, 0, 40)
	watched.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(point))
	_check(watched.program.mode == "Manual", "Detour rejected manual authority")
	_check(
		movement.target_position == point and movement._recovery_left == 0,
		"Old detour survived replacement"
	)
	var position = watched.position
	await _frames(30)
	_check(watched.position == position, "Paused manual replacement moved the guard")
	paused = false
	await _frames(240)
	_check(watched.program.mode == "Manual", "Old guard resumed over the manual order")
	watched.issue_manual_order(null)
	_check(
		not movement._has_destination and movement._recovery_left == 0, "Stop retained the detour"
	)
	await _close()


func _fresh_corner(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for old in get_nodes_in_group("units"):
		if old.movement_speed > 0:
			old.queue_free()
	await _frames(60)
	var human = game._get_human_player()
	var buddy = _actor("Tank", human, Vector3(18.4965, 0, 39.1986))
	support = _actor("RepairRobot", human, Vector3(19.6342, 0, 37.7191))
	for point in [
		Vector3(19.2435, 0, 41.5939), Vector3(19.8904, 0, 36.263), Vector3(19.8305, 0, 38.6695)
	]:
		_actor("Infantry", human, point)
	watched = _actor("Tank", human, Vector3(21.2743, 0, 37.2257))
	await _frames(30)
	support.issue_manual_order(load("res://source/match/units/actions/Repairing.gd").new(buddy))
	anchor = Vector3(18.5, 0, 40)
	for unit in [buddy, watched]:
		unit.program.installed = true
		unit.program.anchor = anchor
		unit.program.safe_point = Vector3(10, 0, 40)
		unit.program.configure(
			load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
		)
		_check(unit.program.run(), "Fresh guard refused to run")
	_reset_measurements()


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _review_corner(_label):
	return true


func _close():
	paused = false
	game.queue_free()
	await _frames(5)
