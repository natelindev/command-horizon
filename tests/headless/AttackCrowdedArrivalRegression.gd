extends "res://tests/headless/CrowdedDestinationRegression.gd"

const ATTACK_CAPTURE = (
	"res://docs/playtests/2026-10-06/engineer-reassignment/" + "reassigned-2-stationary.json"
)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for repeat in 3:
		await _captured_attack(repeat)
	if "--capture-only" not in OS.get_cmdline_user_args():
		await _queued_attack_archive()
		await _distant_attack()
		await _active_combat()
	for error in errors:
		push_error(error)
	print("Crowded attack arrival: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_attack():
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(ATTACK_CAPTURE))
	_check(result.ok, "Earned attack crowd failed to restore")
	if not result.ok:
		return null
	game = result.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	return restore.entities["unit-16"]


func _captured_attack(repeat):
	var unit = await _open_attack()
	if unit == null:
		return
	var movement = unit.get_node("Movement")
	var action = unit.action
	var start = unit.position
	var previous = start
	var max_step = 0.0
	_check(action.get_script().resource_path.ends_with("/AttackMoving.gd"), "Lost captured attack")
	paused = false
	var elapsed = -1.0
	var started = game.simulation_time
	for frame in 360:
		await physics_frame
		max_step = maxf(max_step, unit.position.distance_to(previous))
		previous = unit.position
		if unit.action != action:
			elapsed = game.simulation_time - started
			break
	_check(elapsed > 0 and elapsed < 6, "Earned AttackMove kept pushing at its occupied endpoint")
	_check(not movement._has_destination, "Arrived AttackMove retained movement")
	_check(unit.position.distance_to(start) < 1, "Arrival changed the assigned location")
	_check(max_step <= unit.movement_speed / 60.0 + .002, "Arrival teleported infantry")
	print(
		"ATTACK CROWD ", repeat, " elapsed=", elapsed, " travel=", unit.position.distance_to(start)
	)
	game.queue_free()
	await _frames(5)


func _queued_attack_archive():
	var unit = await _open_attack()
	if unit == null:
		return
	unit.manual_orders.submit({"kind": "move", "point": Vector3(28, 0, 50)}, true)
	paused = false
	await _frames(45)
	paused = true
	var elapsed = unit.action._arrival_elapsed
	var progress = unit.action._arrival_progress
	_check(elapsed > 0 and progress != null, "No live arrival observation to save")
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(unit)
	var index = data.units.find(data.units.filter(func(row): return row.id == id)[0])
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Attack arrival state rejected")
	for invalid in [-.1, 2.1, INF, "invalid"]:
		var changed = data.duplicate(true)
		changed.units[index].action.state._arrival_elapsed = invalid
		_check(not schema.validate(changed), "Corrupt AttackMove timer accepted")
	for field in ["_arrival_elapsed", "_arrival_progress"]:
		var changed = data.duplicate(true)
		changed.units[index].action.state.erase(field)
		_check(not schema.validate(changed), "Partial AttackMove observation accepted")
	var stale = data.duplicate(true)
	stale.units[index].action.state.erase("_arrival_elapsed")
	stale.units[index].action.state.erase("_arrival_progress")
	_check(not schema.validate(stale), "AttackMove without arrival observation accepted")
	var disk = "user://attack-crowd-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, data), "Attack crowd disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(loaded.ok, "Attack crowd disk load failed")
	if not loaded.ok:
		return
	game = loaded.game
	unit = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var position = unit.position
	await _frames(90)
	_check(
		(
			unit.action._arrival_elapsed == elapsed
			and unit.action._arrival_progress == progress
			and unit.position == position
			and unit.manual_orders.pending.size() == 1
		),
		"Pause/load changed crowded attack observation or queue"
	)
	paused = false
	var started = game.simulation_time
	var handoff = -1.0
	for frame in 360:
		await physics_frame
		if unit.manual_orders.pending.is_empty():
			handoff = game.simulation_time - started
			break
	_check(handoff > 0 and handoff < 6, "Restored crowded attack did not hand off")
	_check(unit.manual_orders.current.get("kind") == "move", "Attack lost its queued move")
	print("ATTACK ARCHIVE handoff=", handoff, " restored_elapsed=", elapsed)
	game.queue_free()
	await _frames(5)


func _distant_attack():
	var unit = await _open_attack()
	if unit == null:
		return
	unit.position += Vector3(0, 0, 5)
	unit.get_node("Movement").speed = .05
	var action = unit.action
	paused = false
	await _frames(240)
	_check(unit.action == action, "Distant AttackMove completed beside a remote ally")
	_check(unit.get_node("Movement")._has_destination, "Distant attack lost its destination")
	print("ATTACK DISTANCE still active")
	game.queue_free()
	await _frames(5)


func _active_combat():
	var unit = await _open_attack()
	if unit == null:
		return
	var enemy = get_nodes_in_group("players").filter(func(side): return side != unit.player)[0]
	var target = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(
		target, Transform3D(Basis(), unit.position + Vector3(0, 0, 3)), enemy
	)
	target.hp = 1000
	target.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	unit.manual_orders.submit({"kind": "move", "point": Vector3(28, 0, 50)}, true)
	var action = unit.action
	paused = false
	await _frames(240)
	_check(target.hp < 1000, "Combat fixture did not receive real fire")
	_check(
		unit.action == action and unit.manual_orders.pending.size() == 1,
		"Crowded attack completed while fighting"
	)
	_check(
		action._arrival_elapsed == 0 and action._arrival_progress == null,
		"Combat retained stale arrival observation"
	)
	print("ATTACK COMBAT damage=", 1000 - target.hp, " queue retained")
	game.queue_free()
	await _frames(5)
