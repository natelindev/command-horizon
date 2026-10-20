extends "res://tests/headless/SaveRestoreEdges.gd"

# Zero planar avoidance velocity must not freeze a restored or teleported ground
# unit between its saved height and the navmesh's surface.


func _run():
	save_path = "user://ground-height-alignment-%d.json" % OS.get_process_id()
	path = "user://ground-height-alignment-campaign-%d.json" % OS.get_process_id()
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var soldier = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(
		soldier, Transform3D(Basis(), Vector3(30, 0, 82)), game._get_human_player(), false
	)
	soldier.stance = soldier.Stance.HOLD_FIRE
	await _frames(10)
	var ground = soldier.position.y
	soldier.position.y = ground + 0.6
	await _frames(30)
	_check(absf(soldier.position.y - ground) < 0.005, "Idle elevated soldier stopped settling")
	paused = true
	soldier.position.y = ground + 0.6
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Elevated ground capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var id = builder._reference(soldier)
	var restorer = Restore.new()
	var loaded = await restorer.restore(self, snapshot)
	_check(loaded.ok, "Elevated ground restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		await _finish()
		return
	game = loaded.game
	soldier = restorer.entities[id]
	_check(
		is_equal_approx(soldier.position.y, ground + 0.6),
		"Paused restore discarded the saved elevation"
	)
	var start = soldier.position
	soldier.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(24, ground, 82))
	)
	paused = false
	await _frames(60)
	_check(absf(soldier.position.y - ground) < 0.005, "Restored soldier stopped above the path")
	_check(
		soldier.position.x < start.x - 1, "Restored soldier could not advance its first waypoint"
	)
	soldier.issue_manual_order(null)
	soldier.position.y = ground - 0.6
	await _frames(30)
	_check(absf(soldier.position.y - ground) < 0.005, "Below-ground soldier stopped settling")
	if errors.is_empty():
		print("PASS: stationary height alignment, elevated restore and first-waypoint movement")
	await _finish()
