extends "res://tests/headless/SaveRestoreEdges.gd"

const EVIDENCE = "res://docs/playtests/2026-10-06/regional-recovery/"
var recovery_action


func _run():
	recovery_action = load("res://source/match/units/actions/RecoveringAtService.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for index in [0, 2]:
		await _continue_recovery(index)
	for message in errors:
		push_error(message)
	print("Regional earned recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _continue_recovery(index):
	var file = EVIDENCE + "earned%d-case%d-10-armor_recovery.json" % [index, index]
	var snapshot = FileStore.new().read_file(file)
	var loaded = await Restore.new().restore(self, snapshot)
	_check(loaded.ok, "Earned armor archive failed to load")
	if not loaded.ok:
		return
	game = loaded.game
	var owner = game._get_human_player()
	var patients = _units(owner, "Tank").filter(
		func(unit): return is_instance_of(unit.action, recovery_action)
	)
	_check(patients.size() == 1, "Expected one earned conventional patient")
	if patients.size() != 1:
		game.queue_free()
		await _frames(5)
		return
	var tank = patients[0]
	var hp = tank.hp
	var before = game.simulation_time
	var action = tank.action
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	await _review(str(index) + "-withdrawal", tank)
	_check(tank.hp == hp and tank.action == action, "Paused review changed patient")
	_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "Paused review spent funds")
	await _resume()
	for frame in 6000:
		await _frames(1)
		if not is_instance_valid(tank) or tank.is_queued_for_deletion() or game.finished:
			break
		if tank.hp >= tank.hp_max * recovery_action.RETURN_HEALTH:
			break
	game.hud.pause_after_load()
	var ready = is_instance_valid(tank) and not tank.is_queued_for_deletion()
	ready = ready and tank.hp >= tank.hp_max * recovery_action.RETURN_HEALTH
	_check(ready, "Earned patient did not complete recovery with live enemy AI")
	print(
		"EARNED REGIONAL ",
		index,
		" ready=",
		ready,
		" elapsed=",
		game.simulation_time - before,
		" start_hp=",
		hp,
		" end_hp=",
		tank.hp if is_instance_valid(tank) else 0
	)
	if ready:
		await _review(str(index) + "-recovered", tank)
	paused = false
	game.queue_free()
	await _frames(5)


func _resume():
	game.hud._toggle_pause()


func _review(_label, _tank):
	await _frames(6)
