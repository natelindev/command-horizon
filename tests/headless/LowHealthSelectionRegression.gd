extends "res://tests/headless/BattlePlanRegression.gd"

const EARNED = "res://docs/playtests/2026-10-06/program-recovery/pressure-helix-unsupported.json"
var capture_prefix = ""


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	await _earned_selection()
	for faction in ["bastion", "helix", "frontier"]:
		await _cohort(faction)
	for error in errors:
		push_error(error)
	print("Low-health selection: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _button():
	return game.hud.battle_plan.find_child("SelectLowHealth", true, false)


func _earned_selection():
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(EARNED))
	_check(loaded.ok, "Earned pressure state did not restore")
	if not loaded.ok:
		return
	game = loaded.game
	var owner = game._get_human_player()
	var before_step = plan_rules.next_step(owner)
	_check(before_step.id == "defend_economy", "Earned fixture no longer has defense priority")
	game.hud.battle_plan.refresh()
	var button = _button()
	_check(button != null, "No low-health shortcut during earned defense pressure")
	if button != null:
		var tank = _units(owner, "Tank")[0]
		var action = tank.action
		var safe = tank.program.safe_point
		var hp = tank.hp
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var time = game.simulation_time
		await _activate(button, "earned")
		_check(tank in get_nodes_in_group("selected_units"), "Earned wounded guard was omitted")
		_check(
			tank.action == action and tank.program.safe_point == safe,
			"Selection changed guard authority"
		)
		_check(tank.hp == hp and game.simulation_time == time, "Selection advanced recovery")
		_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "Selection spent funds")
		_check(
			plan_rules.next_step(owner).id == before_step.id, "Shortcut changed defense priority"
		)
		await _review("earned-selected")
	paused = false
	game.queue_free()
	await _frames(5)


func _cohort(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud.pause_after_load()
	var owner = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var enemy_tank = _units(enemy, "Tank")[0]
	enemy_tank.hp = enemy_tank.hp_max * .25
	var wanted = []
	for role in ["Infantry", "Tank", "Drone", "RepairRobot"]:
		var choices = _units(owner, role)
		var unit = (
			choices[0]
			if not choices.is_empty()
			else _spawn_for_plan(role, owner, Vector3(35, 0, 25))
		)
		unit.hp = unit.hp_max * .25
		wanted.append(unit)
	var worker = _units(owner, "Worker")[0]
	worker.hp = worker.hp_max * .25
	var hq = _units(owner, "CommandCenter")[0]
	hq.hp = hq.hp_max * .25
	game.hud.battle_plan.refresh()
	var button = _button()
	_check(button != null, faction + ": missing wounded selection")
	if button != null:
		_check(button.visible and "4" in button.text, faction + ": wrong wounded count")
		var actions = wanted.map(func(unit): return unit.action)
		await _activate(button, faction)
		var selected = get_nodes_in_group("selected_units")
		_check(
			selected.size() == 4 and wanted.all(func(unit): return unit in selected),
			"Wrong wounded cohort"
		)
		_check(
			wanted.map(func(unit): return unit.action) == actions, "Wounded selection issued orders"
		)
		# Recompute on activation: a healed unit and a dead unit leave the cohort
		# even if the quarter-second UI refresh has not run yet.
		wanted[0].hp = wanted[0].hp_max * .5
		wanted[1].hp = 0
		button.pressed.emit()
		selected = get_nodes_in_group("selected_units")
		_check(
			selected.size() == 2 and wanted[2] in selected and wanted[3] in selected,
			"Stale wounded selection"
		)
		wanted[2].hp = wanted[2].hp_max
		wanted[3].hp = wanted[3].hp_max
		game.hud.battle_plan.refresh()
		_check(not button.visible, "Empty wounded shortcut remains visible")
		var previous = get_nodes_in_group("selected_units")
		button.pressed.emit()
		_check(
			get_nodes_in_group("selected_units") == previous, "Empty activation cleared selection"
		)
		await _review(faction + "-healthy")
		if faction == "frontier":
			for index in 90:
				_spawn_for_plan("Infantry", owner, Vector3(40 + index % 10, 0, 30 + index / 10))
			for unit in plan_rules.owned_units(owner):
				if unit.movement_speed > 0 and unit.hp > 0:
					unit.hp = unit.hp_max * .25
			game.hud.battle_plan.refresh()
			await _review("frontier-large-cohort")
			worker.last_enemy_damage_time = game.simulation_time
			game.hud.battle_plan.refresh()
			await _review("frontier-large-pressure")
	paused = false
	game.queue_free()
	await _frames(5)


func _activate(button, _label):
	button.pressed.emit()
	await _frames(8)


func _review(_label):
	pass
