extends "res://tests/headless/DirectOrdersRegression.gd"

var human
var ground
var air
var building
var clear_point = Vector3(36, 0, 31)
var blocked_point = Vector3(40.5, 0, 22.5)
var label = ""


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		label = faction
		await _assignment_fixture(faction)
		await _assignment_cases()
		await _assignment_reload()
		await _real_guard()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Assignment footprints: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _assignment_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	building = _spawn_role(human, "AircraftFactory", Vector3(40, 0, 21))
	ground = _spawn_role(human, "Tank", Vector3(41.26, 0, 24.05))
	air = _spawn_role(human, "Helicopter", Vector3(45, 1.5, 31))
	await _frames(60)
	game.hud.pause_after_load()
	for unit in [ground, air]:
		unit.program.installed = true
		unit.program.configure(
			load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
		)
		unit.program.anchor = clear_point
		unit.program.safe_point = clear_point + Vector3(-4, 0, 0)
		unit.program.route = [clear_point, clear_point + Vector3(3, 0, 0)]
		_check(unit.program.run(), "Assignment fixture could not run")
	await _select_units([ground])


func _authority():
	var programs = []
	for unit in [ground, air]:
		programs.append(
			[
				unit.program.anchor,
				unit.program.safe_point,
				unit.program.route.duplicate(),
				unit.program.mode,
				unit.action,
				unit.manual_orders.pending.duplicate(true)
			]
		)
	return [programs, human.resource_a, human.resource_b, game.simulation_time, paused]


func _attempt(kind, units, point):
	game.hud.arm_program_assignment(kind, units)
	return await _click_assignment(point)


func _click_assignment(point):
	return game.hud.accept_program_assignment(point, null)


func _assignment_cases():
	var hud = game.hud
	for kind in ["anchor", "safe", "patrol"]:
		var before = _authority()
		_check(
			not await _attempt(kind, [ground], blocked_point),
			label + ": accepted obstructed " + kind
		)
		_check(_authority() == before, label + ": rejected assignment changed authority")
		_check(
			hud._assignment_kind == kind and hud._assignment_points.is_empty(),
			"Rejected point consumed targeting"
		)
		_check(
			"outside your buildings" in hud._assignment_hint.text, "Obstruction feedback missing"
		)
		await _review(kind + "-blocked")
	# A whole mixed selection remains untouched. Aircraft alone can fly above it.
	var before = _authority()
	_check(
		not await _attempt("anchor", [air, ground], blocked_point),
		"Mixed assignment ignored ground member"
	)
	_check(_authority() == before, "Mixed rejection partly applied")
	_check(
		await _attempt("anchor", [air], blocked_point), "Aircraft could not target above a building"
	)
	_check(air.program.anchor == blocked_point, "Air assignment changed destination")
	# Keep the first waypoint through a bad second click, then commit both together.
	before = _authority()
	_check(
		not await _attempt("patrol", [ground], clear_point), "First waypoint prematurely committed"
	)
	_check(not await _click_assignment(blocked_point), "Blocked second waypoint committed")
	_check(hud._assignment_points == [clear_point], "Bad second click lost the first waypoint")
	_check(_authority() == before, "Incomplete route mutated the live program")
	_check(
		await _click_assignment(clear_point + Vector3(4, 0, 0)),
		"Valid second waypoint did not commit"
	)
	_check(
		ground.program.route == [clear_point, clear_point + Vector3(4, 0, 0)],
		"Committed wrong route"
	)
	# A foundation arriving between clicks invalidates the staged first point.
	var first = Vector3(47, 0, 40)
	await _attempt("patrol", [ground], first)
	var foundation = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(foundation, Transform3D(Basis(), first), human, true)
	await _frames(5)
	before = _authority()
	_check(not await _click_assignment(clear_point), "Stale obstructed first waypoint committed")
	_check(
		hud._assignment_points.is_empty() and hud._assignment_kind == "patrol",
		"Stale first waypoint did not restart route input"
	)
	_check(_authority() == before, "Stale route rejection changed program")
	_check(not await _attempt("safe", [ground], first), "Foundation accepted as a retreat point")
	# Only owned, living structures participate: no hidden enemy geometry is queried.
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	foundation.reparent(enemy, true)
	_check(
		await _attempt("safe", [ground], first), "Foreign structure affected assignment feedback"
	)
	foundation.reparent(human, true)
	foundation.hp = 0
	_check(await _attempt("safe", [ground], first), "Dead structure blocked assignment")
	foundation.hp = foundation.hp_max
	foundation.queue_free()
	_check(await _attempt("safe", [ground], first), "Deleting structure blocked assignment")
	await _frames(5)
	# Sector activation is an area command, not a point to travel to.
	if human.faction == "bastion":
		_check(
			await _attempt("signature", [ground], blocked_point),
			"Anchor sector was treated as a movement destination"
		)
	await _attempt("safe", [ground], clear_point + Vector3(-4, 0, 0))
	_check(await _attempt("anchor", [ground], clear_point), "Clear assignment rejected")
	_check(ground.program.mode == "Manual", "Assignment silently resumed automation")
	_check(ground.program.run(), "Explicit Resume failed")
	await _review("clear-assignment")


func _assignment_reload():
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var ids = [builder._reference(ground), builder._reference(air), builder._reference(building)]
	var points = [
		ground.program.anchor, ground.program.safe_point, ground.program.route.duplicate()
	]
	var position = ground.position
	var file = "user://assignment-footprints-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Assignment snapshot write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Assignment snapshot restore failed")
	game = loaded.game
	ground = restore.entities[ids[0]]
	air = restore.entities[ids[1]]
	building = restore.entities[ids[2]]
	human = ground.player
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit not in [ground, air]:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(20)
	_check(paused and game.simulation_time == data.simulation_time, "Assignment load advanced time")
	_check(
		(
			ground.position == position
			and [ground.program.anchor, ground.program.safe_point, ground.program.route] == points
		),
		"Assignment load changed points or position"
	)
	var before = _authority()
	_check(
		not await _attempt("safe", [ground], blocked_point),
		"Restored footprint accepted a retreat point"
	)
	_check(_authority() == before, "Restored rejection changed authority")
	hud_cancel()
	await _review("restored")


func hud_cancel():
	game.hud.cancel_map_assignment()


func _real_guard():
	game.hud._toggle_pause()
	await _frames(900)
	_check(
		ground.program.mode == "Running" and ground.action.is_settled_guard(),
		"Clear guard failed actual arrival"
	)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var raider = _spawn_role(enemy, "Tank", clear_point + Vector3(4, 0, 0))
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	var hp = raider.hp
	await _frames(180)
	_check(
		not is_instance_valid(raider) or raider.hp < hp, "Reassigned guard did not defend its area"
	)
	game.hud.pause_after_load()
	await _review("defending")
	print(
		"ASSIGNMENT FOOTPRINT ",
		label,
		" state=",
		ground.program.mode,
		" point=",
		ground.program.anchor
	)


func _review(_stage):
	return
