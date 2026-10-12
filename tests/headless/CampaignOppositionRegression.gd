extends "res://tests/headless/CommandHorizonRegression.gd"


func _run():
	path = "user://opposition-regression-%d.json" % OS.get_process_id()
	await _make_match()
	var enemy = game._enemy
	var opposition = game.opposition
	for side in [game._get_human_player(), enemy]:
		for unit in side.get_children():
			if not unit.is_in_group("units"):
				continue
			if side == enemy and unit.type == "Worker":
				continue
			if side == enemy and unit.has_node("ProductionQueue"):
				continue
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.resource_a = 0
	enemy.resource_b = 0
	opposition.activate()
	await _frames(2700)
	_check(
		enemy.resource_a > 0 and enemy.resource_b > 0,
		"Enemy workers did not deliver actual harvested income"
	)
	_check(opposition.admitted == 0, "Base ignored its advertised initial production delay")
	for worker in _units(enemy, "Worker"):
		worker.hp = 0
	await _frames(2)
	enemy.resource_a = 0
	enemy.resource_b = 0
	opposition._try_produce()
	_check(opposition.admitted == 0, "Enemy base manufactured an unpaid reinforcement")
	enemy.resource_a = 100
	enemy.resource_b = 30
	var cost = load("res://source/match/FactionCatalog.gd").cost(enemy, "Infantry")
	opposition._try_produce()
	_check(opposition.admitted == 1, "Funded enemy base failed to admit normal production")
	_check(
		enemy.resource_a == 100 - cost.resource_a and enemy.resource_b == 30 - cost.resource_b,
		"Enemy reinforcement did not debit faction price"
	)
	var timer = opposition.production_left
	paused = true
	await create_timer(.1, true).timeout
	_check(opposition.production_left == timer, "Paused campaign opposition advanced its timer")
	paused = false
	await _frames(1800)
	_check(
		not opposition.reinforcements.is_empty(), "Paid reinforcement did not leave its producer"
	)
	for unit in opposition.reinforcements:
		_check(unit.action != null, "Reinforcement left factory without a combat order")
	await _boss_rules()
	await _close()
	for message in errors:
		push_error(message)
	print("Campaign opposition: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _boss_rules():
	var opposition = game.opposition
	var boss = opposition.boss
	_check(game._alive(boss), "Finale has no siege commander objective")
	var target = game._spawn("Tank", game._get_human_player(), boss.position + Vector3(-5, 0, 0))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(45)
	opposition.salvo_left = 0
	opposition._step_boss(.1)
	_check(opposition.warning_left == 4.0, "Boss fired without a full warning")
	_check(opposition.boss_started, "Boss encounter did not activate")
	var locked = opposition.target_point
	var entities = {"boss": boss}
	for index in opposition.reinforcements.size():
		entities["reinforcement-%d" % index] = opposition.reinforcements[index]
	var state = opposition.capture_state(
		func(unit):
			for key in entities:
				if entities[key] == unit:
					return key
			return ""
	)
	opposition.restore_state(state, entities)
	_check(
		(
			opposition.boss == boss
			and opposition.warning_left == 4.0
			and opposition.target_point == locked
		),
		"Restored boss warning changed its source, timer or locked point"
	)
	var hp = target.hp
	target.position = locked + Vector3(-6, 0, 0)
	await _frames(2)
	opposition._step_boss(4.0)
	_check(target.hp == hp, "Boss homed onto a unit after locking its ground target")
	target.position = boss.position + Vector3(-5, 0, 0)
	await _frames(45)
	opposition.salvo_left = 0
	opposition._step_boss(.1)
	_check(opposition.warning_left == 4.0, "Boss did not rearm after cooldown")
	opposition._step_boss(4.0)
	_check(target.hp < hp, "Stationary unit in telegraphed barrage took no weapon damage")
	opposition.salvo_left = 0
	opposition._step_boss(.1)
	boss.hp = 0
	var after_death = opposition.capture_state(func(_unit): return "unexpected-dead-reference")
	_check(
		after_death.boss == "" and after_death.boss_defeated and after_death.warning_left < 0,
		"Immediate death snapshot retained a pending barrage source"
	)
	opposition._step_boss(.1)
	_check(
		opposition.boss_defeated and opposition.warning_left < 0,
		"Killing commander did not cancel pending barrage"
	)
