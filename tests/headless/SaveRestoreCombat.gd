extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	save_path = "user://restore-combat-%d.json" % OS.get_process_id()
	path = "user://restore-combat-campaign-%d.json" % OS.get_process_id()
	await _skirmish("helix")
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	var attacker = _units(human, "Tank")[0]
	var target = _units(enemy, "Tank")[0]
	attacker.issue_manual_order(null)
	target.issue_manual_order(null)
	attacker.global_position = Vector3(24, 0, 20)
	target.global_position = Vector3(28, 0, 20)
	game.battlefield.invalidate()
	var shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	attacker.issue_manual_order(shooting.new(target))
	await _frames(20)
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Shooting capture failed: " + builder.error)
	if snapshot == null:
		await _finish()
		return
	var attacker_id = builder._reference(attacker)
	var target_id = builder._reference(target)
	var saved = _saved(snapshot, attacker_id)
	_check(saved.action.kind == "AttackingWhileInRange", "Shooting fixture lost action")
	_check(saved.action.state._shots > 0, "Shooting fixture did not fire")
	var restorer = Restore.new()
	var loaded = await restorer.restore(self, snapshot)
	_check(loaded.ok, "Shooting restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		await _finish()
		return
	game = loaded.game
	attacker = restorer.entities[attacker_id]
	target = restorer.entities[target_id]
	var shots = attacker.action._shots
	var left = saved.action.timers._one_shot_timer.left
	_check(shots == saved.action.state._shots, "Loading fired an extra shot")
	_check(is_equal_approx(attacker.action._one_shot_timer.time_left, left), "Shot timer reset")
	var hp = target.hp
	await _frames(50)
	_check(target.hp == hp and attacker.action._shots == shots, "Pause advanced restored weapons")
	game.hud._pause_button.pressed.emit()
	await _frames(ceili(left * 60.0) + 22)
	_check(target.hp < hp, "Restored repeating weapon never damaged its target")
	_check(
		is_instance_valid(attacker.action) and attacker.action._shots > shots,
		"Restored weapon did not repeat"
	)
	print("PASS: active shooting cooldown/timers, no duplicate shot, pause and repeat damage")
	await _finish()
