extends "res://tests/headless/SaveRestoreEdges.gd"

# Rounds in flight: saved centrally, validated, restored with their exact state,
# and kept after the shooter is destroyed.


func _run():
	save_path = "user://projectile-system-%d.json" % OS.get_process_id()
	path = "user://projectile-system-campaign-%d.json" % OS.get_process_id()
	await _skirmish("bastion")
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	var shooter = _units(human, "Tank")[0]
	var gunner = _units(human, "Tank")[1]
	var target = _units(enemy, "Tank")[0]
	_hold_units()
	shooter.global_position = Vector3(24, 0, 20)
	gunner.global_position = Vector3(24, 0, 24)
	target.global_position = Vector3(28, 0, 22)
	game.battlefield.invalidate()
	var system = game.projectile_system
	system.clear()
	system.launch(shooter, target)
	system.launch(gunner, target)
	var expected = 2.0 * load("res://source/match/combat/CombatRules.gd").damage(shooter, target)
	gunner.queue_free()
	await _frames(1)
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Round capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var shooter_id = builder._reference(shooter)
	var target_id = builder._reference(target)
	var flying = snapshot.rounds.flying
	_check(flying.size() == 2, "Snapshot lost a round in flight")
	var saved = flying.filter(func(item): return item.shooter == shooter_id)
	_check(
		saved.size() == 1 and saved[0].target == target_id and saved[0].kind == "shell",
		"Round lost its shooter, target or kind"
	)
	var lost = flying.filter(func(item): return item.shooter == "")
	_check(lost.size() == 1 and lost[0].type == "Tank", "Round of a destroyed shooter not saved")
	_check(Restore.new().prepare(snapshot), "Valid rounds rejected")
	for corruption in [
		func(data): data.rounds.flying[0].kind = "laser",
		func(data): data.rounds.flying[0].age = data.rounds.flying[0].life + 1.0,
		func(data): data.rounds.flying[0].target = "player-1",
		func(data): data.rounds.flying[0].domains = [7],
		func(data): data.rounds.flying[0].serial = data.rounds.serial,
		func(data): data.rounds.flying[0].velocity = Vector3(1e6, 0, 0),
	]:
		var broken = snapshot.duplicate(true)
		corruption.call(broken)
		_check(not Restore.new().prepare(broken), "Corrupt round accepted")
	var restorer = Restore.new()
	var loaded = await restorer.restore(self, snapshot)
	_check(loaded.ok, "Round restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		await _finish()
		return
	game = loaded.game
	target = restorer.entities[target_id]
	_hold_units()
	system = game.projectile_system
	_check(system.round_count() == 2, "Reload duplicated or dropped rounds")
	var restored = system.rounds_at(target).filter(
		func(round): return round.shot.shooter() == restorer.entities[shooter_id]
	)
	_check(
		(
			restored.size() == 1
			and restored[0].position == saved[0].position
			and restored[0].velocity == saved[0].velocity
			and restored[0].age == saved[0].age
			and restored[0].kind == "shell"
		),
		"Reload moved or retimed a round"
	)
	_check(system.rounds_fired == snapshot.rounds.serial, "Round serial not restored")
	var hp = target.hp
	await _frames(40)
	_check(target.hp == hp and system.round_count() == 2, "Pause advanced restored rounds")
	paused = false
	game.get_tree().paused = false
	await _frames(60)
	_check(is_equal_approx(hp - target.hp, expected), "Restored rounds did not land exactly once")
	_check(system.round_count() == 0, "Landed rounds remained in flight")
	await _finish()


# Only the rounds under test may damage the target.
func _hold_units():
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED


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
		print("PASS: rounds save centrally, validate, keep exact state and outlive shooters")
	quit(0 if errors.is_empty() else 1)
