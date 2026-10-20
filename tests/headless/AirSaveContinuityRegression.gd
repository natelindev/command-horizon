extends "res://tests/headless/SaveRestoreEdges.gd"

# Ordinary turns can cross the map edge. Saving there must preserve the flight,
# weapon cadence, partial rearming and a bomber's already-started stick.
const Catalog = preload("res://source/match/BastionCatalog.gd")


func _run():
	save_path = "user://air-save-continuity-%d.json" % OS.get_process_id()
	path = "user://air-save-continuity-campaign-%d.json" % OS.get_process_id()
	await _skirmish("bastion")
	var human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type == "CommandCenter":
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			unit.queue_free()
	await _frames(5)
	var field = _place("AircraftFactory", human, Vector3(44, 0, 40))
	await _frames(10)
	var fighter = _place("Fighter", human, Vector3(4, 0, 25))
	var bomber = _place("Bomber", human, Vector3(25, 0, 54))
	var helicopter = _place("Helicopter", human, field.pad_point(0))
	helicopter.stance = helicopter.Stance.HOLD_FIRE
	await _frames(10)
	fighter.action = load("res://source/match/units/actions/Moving.gd").new(Vector3(3, 0, 25))
	var crossed_edge = false
	for _tick in range(2400):
		await _frames(1)
		if fighter.position.x < -1 or fighter.position.z < -1:
			crossed_edge = true
			break
	_check(crossed_edge, "Ordinary edge turn did not exercise the save boundary")
	paused = true
	fighter.stance = fighter.Stance.HOLD_FIRE
	bomber.stance = bomber.Stance.HOLD_FIRE
	helicopter.stance = helicopter.Stance.HOLD_FIRE
	fighter._cooldowns.missile = 0.7
	fighter._cooldowns.cannon = 0.04
	fighter._rearm_left = 0.2
	bomber.stores.bomb = 4
	bomber._stick_left = 4
	bomber._cooldowns.bomb = 0.1
	bomber._rearm_left = 0.3
	helicopter.rockets = 5
	helicopter._rearm_left = 0.2
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Air continuity capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var ids = {
		"fighter": builder._reference(fighter),
		"bomber": builder._reference(bomber),
		"helicopter": builder._reference(helicopter),
		"field": builder._reference(field)
	}
	var restorer = Restore.new()
	_check(restorer.prepare(snapshot), "Valid edge flight rejected: " + restorer.error)
	for corruption in [
		func(data): _saved(data, ids.field).position.x = -2.0,
		func(data): _saved(data, ids.fighter).position.x = -1000.0,
		func(data): _saved(data, ids.fighter).air.cooldowns.missile = -0.1,
		func(data): _saved(data, ids.fighter).air.cooldowns.missile = 2.0,
		func(data): _saved(data, ids.fighter).air.stores.cannon = 61,
		func(data): _saved(data, ids.fighter).air.stick_left = 1,
		func(data): _saved(data, ids.bomber).air.stick_left = 5,
		func(data): _saved(data, ids.helicopter).air.rearm_left = 1.0,
	]:
		var broken = snapshot.duplicate(true)
		corruption.call(broken)
		_check(not Restore.new().prepare(broken), "Invalid air state or ground position accepted")
	var loaded = await restorer.restore(self, snapshot)
	_check(loaded.ok, "Air continuity restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		await _finish()
		return
	game = loaded.game
	fighter = restorer.entities[ids.fighter]
	bomber = restorer.entities[ids.bomber]
	helicopter = restorer.entities[ids.helicopter]
	await _frames(10)
	_check(
		fighter.position == _saved(snapshot, ids.fighter).position,
		"Paused restore moved the aircraft inside the map"
	)
	for role in ["fighter", "bomber", "helicopter"]:
		var craft = restorer.entities[ids[role]]
		var air = craft.capture_air(
			func(entity): return restorer.entities.find_key(entity) if entity != null else ""
		)
		_check(air == _saved(snapshot, ids[role]).air, role + " air state changed while paused")
	var fired = game.projectile_system.rounds_fired
	paused = false
	await _frames(90)
	_check(
		bomber._stick_left == 0 and bomber.stores.bomb == 0,
		"Restored bomber abandoned its committed stick after losing its target"
	)
	_check(
		game.projectile_system.rounds_fired == fired + 4,
		"Restored stick repeated or lost bombs: %d" % (game.projectile_system.rounds_fired - fired)
	)
	_check(helicopter.rockets > 5, "Restored helicopter did not continue rearming")
	if errors.is_empty():
		print("PASS: edge flight, weapon cooldowns, rearm timers and committed bomb stick restore")
	await _finish()


func _place(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
