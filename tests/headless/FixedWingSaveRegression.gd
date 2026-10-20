extends "res://tests/headless/SaveRestoreEdges.gd"

# Fixed-wing flight state survives save/restore: phase, kinematics, stand,
# stores and air orders are exact; the aircraft keeps flying and lands at the
# same stand; corrupt flight state is rejected.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const FIELD_CENTER = Vector3(44, 0, 40)


func _run():
	save_path = "user://fixed-wing-save-%d.json" % OS.get_process_id()
	path = "user://fixed-wing-save-campaign-%d.json" % OS.get_process_id()
	await _skirmish("bastion")
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
	await _frames(5)
	var field = _place(game, "AircraftFactory", human, FIELD_CENTER)
	await _frames(10)
	var fighter = _place(game, "Fighter", human, FIELD_CENTER + Vector3(2, 0, -4))
	await _frames(10)
	fighter.action = load("res://source/match/units/actions/Moving.gd").new(Vector3(20, 0, 22))
	var flight = fighter.get_node("Movement")
	for _tick in range(900):
		await _frames(1)
		if flight.is_airborne() and flight.height_above_ground() > 3.0:
			break
	fighter.stores.missile = 3
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Flight capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var fighter_id = builder._reference(fighter)
	var field_id = builder._reference(field)
	var saved = _saved(snapshot, fighter_id)
	_check(saved.action.kind == "AirStation", "Station order not saved")
	_check(saved.air.flight.airfield == field_id, "Home airfield not saved")
	_check(Restore.new().prepare(snapshot), "Valid flight state rejected")
	for corruption in [
		func(data): _saved(data, fighter_id).air.flight.phase = 9,
		func(data): _saved(data, fighter_id).air.flight.mode = "teleport",
		func(data): _saved(data, fighter_id).air.flight.stand = 7,
		func(data): _saved(data, fighter_id).air.stores.missile = -1,
		func(data):
			_saved(data, field_id).action = {
				"kind": "AirIdle",
				"state": {"_scan_left": 0.0},
				"references": {},
				"children": {},
				"timers": {}
			},
	]:
		var broken = snapshot.duplicate(true)
		corruption.call(broken)
		_check(not Restore.new().prepare(broken), "Corrupt flight state accepted")
	var expected = {
		"phase": flight.phase,
		"heading": flight.heading,
		"airspeed": flight.airspeed,
		"stand": flight.stand,
		"position": fighter.global_position,
	}
	var restorer = Restore.new()
	var loaded = await restorer.restore(self, snapshot)
	_check(loaded.ok, "Flight restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		await _finish()
		return
	game = loaded.game
	fighter = restorer.entities[fighter_id]
	field = restorer.entities[field_id]
	flight = fighter.get_node("Movement")
	await _frames(2)
	_check(
		(
			flight.phase == expected.phase
			and is_equal_approx(flight.heading, expected.heading)
			and is_equal_approx(flight.airspeed, expected.airspeed)
			and flight.stand == expected.stand
			and flight.airfield == field
			and field.stand_of(fighter) == expected.stand
			and fighter.global_position.is_equal_approx(expected.position)
		),
		"Restored flight state changed"
	)
	_check(fighter.stores.missile == 3, "Restored stores changed")
	_check(str(fighter.action).begins_with("AirStation"), "Restored order changed")
	game.get_tree().paused = false
	paused = false
	var start = fighter.global_position
	await _frames(30)
	_check(fighter.global_position.distance_to(start) > 2.0, "Restored aircraft stopped flying")
	fighter.action = load("res://source/match/units/actions/RecoveringAtService.gd").new(field)
	var parked = false
	for _tick in range(3600):
		await _frames(1)
		if flight.is_parked():
			parked = true
			break
	_check(parked and flight.stand == expected.stand, "Restored aircraft did not land at its stand")
	await _finish()


func _place(match_game, role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	match_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _finish():
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	if errors.is_empty():
		print("PASS: flight phase, kinematics, stand, stores and air orders restore exactly")
	quit(0 if errors.is_empty() else 1)
