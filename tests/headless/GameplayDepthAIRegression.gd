extends "res://tests/headless/CombatRegression.gd"

var tactics


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	_game.engineering.set_physics_process(false)
	tactics = load("res://source/match/players/skirmish-ai/SkirmishTactics.gd")
	await _suppression()
	await _clear()
	await _support()
	await _clear()
	await _mine_knowledge()
	await _clear()
	await _commander()
	await _clear()
	await _airdrop_budget()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Gameplay depth AI: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _suppression():
	var infantry = _spawn("Infantry", _enemy, Vector3(40, 0, 8))
	var opponent = _spawn("Tank", _human, Vector3(44, 0, 8))
	await _frames(3)
	infantry.suppression.add_pressure(100.0)
	var claimed = []
	tactics._withdraw_suppressed(_game, _enemy, [infantry], [opponent], claimed)
	_check(infantry in claimed, "AI did not reserve pinned infantry for withdrawal")
	_check(
		infantry.action != null and "_target_position" in infantry.action,
		"Pinned AI infantry received no legal movement order"
	)
	if infantry.action != null and "_target_position" in infantry.action:
		_check(
			infantry.action._target_position.x < infantry.global_position.x,
			"Pinned AI infantry moved toward the observed threat"
		)
	infantry.suppression._physics_process(7.0)
	claimed.clear()
	tactics._withdraw_suppressed(_game, _enemy, [infantry], [opponent], claimed)
	_check(claimed.is_empty(), "Recovered infantry permanently excluded from ordinary army orders")


func _support():
	_enemy.faction = "helix"
	_enemy.technology.completed.append("plasma_shields")
	var generator = _spawn("PowerPlant", _enemy, Vector3(40, 0, 8))
	var tank = _spawn("Tank", _enemy, Vector3(43, 0, 8))
	var drone = _spawn("Drone", _enemy, Vector3(44, 0, 8))
	var lab = _spawn("CommandLab", _enemy, Vector3(65, 0, 35))
	_spawn("VehicleFactory", _enemy, Vector3(48, 0, 48))
	_spawn("VehicleFactory", _enemy, Vector3(56, 0, 45))
	var missile = _spawn("AntiAirTurret", _human, Vector3(48, 0, 8))
	await _frames(3)
	var power = _enemy.power_totals()
	_check(power.x - power.y == 3, "AI Overdrive fixture does not have exactly 3 spare power")
	tank.shields = 0.0
	tactics._overdrive(_game, _enemy, [generator, tank, drone, lab])
	_check(
		generator.abilities.is_active("power_overdrive"),
		"AI ignored damaged shields with exactly 3 spare power"
	)
	tank.shields = tank.shields_max
	tactics._overdrive(_game, _enemy, [generator, tank, drone, lab])
	_check(
		not generator.abilities.is_active("power_overdrive"),
		"AI wasted power on fully restored shields"
	)
	var claimed = []
	tactics._kites(_game, _enemy, [drone, tank, generator, lab], [missile], claimed, true)
	_check(
		drone in claimed and drone.stance == drone.Stance.HOLD_FIRE,
		"AI put an unarmed Kite into attack acquisition"
	)
	_check(
		drone.abilities.is_active("drone_chaff"),
		"AI did not protect escort from observed missile threat"
	)


func _mine_knowledge():
	var worker = _spawn("Worker", _enemy, Vector3(40, 0, 8))
	var mine = _game.engineering._spawn_mine(_human, Vector3(60, 0, 8), "engineering-mine-ai")
	mine.deploy_left = 0.0
	mine.arm_left = 0.0
	await _frames(3)
	var claimed = []
	tactics._field_engineering(_game, _enemy, [worker], [], claimed)
	_check(claimed.is_empty() and worker.action == null, "AI acquired an undetected mine")
	mine.global_position = Vector3(42, 0, 8)
	_game.battlefield.invalidate()
	tactics._field_engineering(_game, _enemy, [worker], [], claimed)
	_check(
		(
			worker in claimed
			and worker.action != null
			and "operation" in worker.action
			and worker.action.operation == "sweep"
		),
		"AI did not explicitly assign worker to observed hazard"
	)
	var action = worker.action
	var again = tactics.command(_game, _enemy, [worker], [])
	_check(worker in again and worker.action == action, "AI overwrote its ongoing clearance order")
	mine.queue_free()


func _commander():
	_enemy.faction = "bastion"
	_enemy.resource_a = 1000
	_enemy.resource_b = 1000
	var lab = _spawn("CommandLab", _enemy, Vector3(40, 0, 8))
	_spawn("PowerPlant", _enemy, Vector3(36, 0, 8))
	var targets = []
	for index in 3:
		targets.append(_spawn("Infantry", _human, Vector3(46, 0, 8 + index)))
	await _frames(3)
	var support = _game.commander_support
	support.state(_enemy).started = true
	support.state(_enemy).left = 0.0
	var before = support.pending.size()
	tactics._commander(_game, _enemy, [lab], [])
	_check(support.pending.size() == before, "AI artillery used unseen targets")
	tactics._commander(_game, _enemy, [lab], targets)
	_check(support.pending.size() == before + 1, "AI ignored visible artillery cluster")
	_check(
		_enemy.resource_a == 950 and _enemy.resource_b == 970,
		"AI commander bypassed public resource costs"
	)
	support.pending.clear()


func _airdrop_budget():
	_enemy.faction = "frontier"
	var lab = _spawn("CommandLab", _enemy, Vector3(40, 0, 8))
	var anchor = _spawn("Tank", _enemy, Vector3(44, 0, 8))
	_spawn("PowerPlant", _enemy, Vector3(36, 0, 8))
	await _frames(3)
	var support = _game.commander_support
	support.state(_enemy).started = true
	support.state(_enemy).left = 0.0
	var cost = support.cost_for(_enemy)
	_enemy.resource_a = cost.resource_a - 1
	_enemy.resource_b = cost.resource_b
	var before = support.pending.size()
	tactics._commander(_game, _enemy, [lab, anchor], [])
	_check(support.pending.size() == before, "AI airdrop bypassed its faction-specific price")
	_enemy.resource_a = cost.resource_a
	tactics._commander(_game, _enemy, [lab, anchor], [])
	_check(
		support.pending.size() == before + 1 and support.pending[-1].kind == "airdrop",
		"AI rejected an otherwise safe airdrop at exactly its public price"
	)
	_check(
		_enemy.resource_a == 0 and _enemy.resource_b == 0,
		"AI airdrop did not pay its exact faction-specific price"
	)
	_check(support.reserved(_enemy) == 2, "AI airdrop bypassed population reservations")
	support.dispose_owner(_enemy)
