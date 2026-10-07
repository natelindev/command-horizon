extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _case(faction)
	for error in errors:
		push_error(error)
	print("Conventional recovery policy: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _case(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud._toggle_pause()
	var owner = game._get_human_player()
	var plan = load("res://source/match/SkirmishPlan.gd")
	var policy = load("res://tests/playtest/reference/ConventionalRecoveryPolicy.gd").new()
	var barracks = _units(owner, "Barracks")[0]
	var infantry = _units(owner, "Infantry").slice(0, 2)
	_check(infantry.size() == 2, "Recovery fixture needs two infantry")
	for index in infantry.size():
		infantry[index].hp = infantry[index].hp_max * (.2 if index == 0 else .6)
		infantry[index].position = barracks.position + Vector3(-8, 0, -5 - index * 2)
		infantry[index].issue_manual_order(null)
	var tank = _units(owner, "Tank")[0]
	tank.hp = tank.hp_max * .2
	var tank_action = tank.action
	var enemy = get_nodes_in_group("players").filter(func(player): return player != owner)[0]
	var raider = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(
		raider, Transform3D(Basis(), barracks.position + Vector3(4, 0, 0)), enemy
	)
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	var sights = {}
	for unit in plan.owned_units(owner):
		sights[unit] = unit.sight_range
		unit.sight_range = .1
	await _frames(5)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(owner, raider), "Hidden service threat is visible")
	var held = policy.update(game, owner, plan.owned_units(owner), false)
	_check(
		infantry[0] in held and infantry[1] not in held, "Wrong active-operation retreat threshold"
	)
	_check(tank.action == tank_action, "Conventional policy replaced armored/program authority")
	held = policy.update(game, owner, plan.owned_units(owner), true)
	_check(
		infantry.all(func(unit): return unit in held),
		"Regroup did not include moderately wounded infantry"
	)
	for unit in sights:
		unit.sight_range = sights[unit]
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(owner, raider), "Visible service threat unavailable")
	held = policy.update(game, owner, plan.owned_units(owner), true)
	_check(
		infantry.all(func(unit): return unit in held and unit.action._blocked),
		"Unsafe service did not hold recovery"
	)
	var action = infantry[0].action
	var retry = action._retry_left
	await _frames(60)
	policy.update(game, owner, plan.owned_units(owner), true)
	_check(
		infantry[0].action == action and action._retry_left == retry,
		"Pause/recheck churned blocked treatment"
	)
	raider.queue_free()
	barracks.queue_free()
	await _frames(5)
	var replacement = load("res://source/match/units/Barracks.tscn").instantiate()
	game._setup_and_spawn_unit(replacement, Transform3D(Basis(), Vector3(44, 0, 27)), owner, false)
	await _frames(60)
	game.battlefield.invalidate()
	held = policy.update(game, owner, plan.owned_units(owner), true)
	for unit in infantry:
		_check(
			unit in held and unit.action._target == replacement and not unit.action._blocked,
			"Safe replacement service did not resume treatment"
		)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	game.hud._toggle_pause()
	for frame in 5400:
		await physics_frame
		if frame % 30 == 0:
			held = policy.update(game, owner, plan.owned_units(owner), true)
		if infantry.all(func(unit): return unit.hp >= unit.hp_max * .8 and unit not in held):
			break
	_check(
		infantry.all(func(unit): return unit.hp >= unit.hp_max * .8 and unit not in held),
		"Treated soldiers never released"
	)
	_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "Treatment changed stockpiles")
	print(
		"CONVENTIONAL POLICY ",
		faction,
		" healed=",
		infantry.map(func(unit): return unit.hp / unit.hp_max),
		" episodes=",
		policy.episodes
	)
	game.queue_free()
	await _frames(5)
