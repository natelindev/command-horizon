extends "res://tests/headless/RelayExpeditionRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var script = (
		"RelayExpeditionPolicy"
		if "--original-policy" in OS.get_cmdline_user_args()
		else "CautiousRelayPolicy"
	)
	policy_script = load("res://tests/playtest/reference/%s.gd" % script)
	for faction in ["bastion", "helix", "frontier"]:
		if not "--risk-only" in OS.get_cmdline_user_args():
			for map_name in ["AlpineRelay", "IndustrialCrossroads"]:
				await _capture_case(faction, map_name)
		await _risk_case(faction)
	for message in errors:
		push_error(message)
	print("Cautious relay: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _setup(faction, map_name):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name, false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	return game._get_human_player()


func _extra_infantry(player, home):
	# Controlled reserve fixture; complete paid matches exercise actual production.
	var unit = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), home + Vector3(2, 0, 0)), player, false)
	return unit


func _capture_case(faction, map_name):
	var player = await _setup(faction, map_name)
	var home = _units(player, "CommandCenter")[0].position + Vector3(0, 0, 6)
	var initial = policy_script.new()
	_check(
		initial.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Expedition spent two-infantry home reserve"
	)
	for unit in _units(player, "Infantry"):
		unit.issue_manual_order(null)
	_extra_infantry(player, home)
	await _frames(5)
	var policy = policy_script.new()
	var funds = Vector2i(player.resource_a, player.resource_b)
	var held = policy.update(game, player, _owned(player), "defend", [], home)
	_check(held.size() == 1, "Three healthy infantry did not dispatch one scout")
	if not held.is_empty():
		var unit = held[0]
		var objective = policy.relay.get_ref()
		var travelling = await _travel_roundtrip(unit, objective)
		if not travelling.is_empty():
			unit = travelling.unit
			objective = travelling.objective
			player = unit.player
		paused = false
		for frame in 3600:
			await _frames(1)
			if objective.candidate == player and objective.progress >= 2:
				break
		_check(objective.progress >= 2, "Cautious scout did not start real capture")
		_check(Vector2i(player.resource_a, player.resource_b) == funds, "Scout changed funds")
		if objective.progress >= 2:
			await _capture_roundtrip(unit, objective, faction + " " + map_name)
	paused = false
	game.queue_free()
	await _frames(5)


func _risk_case(faction):
	var player = await _setup(faction, "IndustrialCrossroads")
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	var home = _units(player, "CommandCenter")[0].position + Vector3(0, 0, 6)
	_extra_infantry(player, home)
	await _frames(5)
	var units = _owned(player)
	var objective = game.map.relays[0]
	var tank_scene = load("res://source/match/units/Tank.tscn")
	var hostile = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		hostile, Transform3D(Basis(), objective.position + Vector3(5, 0, 0)), enemy, false
	)
	await _frames(5)
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(player, hostile), "Hidden opposition fixture is visible"
	)
	var policy = policy_script.new()
	var held = policy.update(game, player, units, "defend", [], home)
	_check(held.size() == 1, "Hidden armor leaked into scouting decision")
	if held.is_empty():
		game.queue_free()
		await _frames(5)
		return
	var scout = held[0]
	objective = policy.relay.get_ref()
	# Keep both units outside the relay's solid pole and on the same clear side.
	hostile.position = objective.position + Vector3(3, 0, -2)
	scout.position = objective.position + Vector3(-2, 0, -2)
	await _frames(2)
	game.battlefield.invalidate()
	print(
		"RELAY CONTACT ",
		faction,
		" sight=",
		scout.sight_range,
		" scout=",
		scout.global_position,
		" hostile=",
		hostile.global_position,
		" observed=",
		game.battlefield.is_observed(player, hostile)
	)
	_check(game.battlefield.is_observed(player, hostile), "New opposition fixture is hidden")
	var order = scout.action
	paused = true
	_check(
		policy.update(game, player, units, "defend", [], home) == held,
		"Paused threat changed expedition"
	)
	_check(scout.action == order, "Paused threat replaced order")
	paused = false
	var protected = policy.update(game, player, units, "defend", [], home)
	_check(
		scout in protected and policy.relay == null,
		"Observed armor did not begin protected withdrawal"
	)
	_check(policy.episodes[-1].result == "opposition", "Opposition recall reason missing")
	_check(
		is_instance_of(scout.action, load("res://source/match/units/actions/Moving.gd")),
		"Outmatched scout attacks during withdrawal"
	)
	var returned = false
	for frame in 1800:
		await _frames(1)
		if not is_instance_valid(scout) or scout.hp <= 0:
			break
		if frame % 30 == 0:
			protected = policy.update(game, player, _owned(player), "attack", [], home)
			if scout.position.distance_to(home) > 6:
				_check(scout in protected, "Main assault reclaimed withdrawing scout")
		if scout.position.distance_to(home) <= 6:
			returned = true
			break
	_check(returned, faction + ": scout did not survive actual withdrawal")
	policy.update(game, player, _owned(player), "attack", [], home)
	if "withdrawals" in policy and not policy.withdrawals.is_empty():
		_check(
			policy.withdrawals[-1].result == "home", "Successful withdrawal did not release scout"
		)
	hostile.queue_free()
	await _frames(5)
	# Healthy infantry away from the base do not satisfy the nearby reserve.
	for unit in _units(player, "Infantry"):
		unit.position = objective.position
	game.battlefield.invalidate()
	policy = policy_script.new()
	_check(
		policy.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Distant infantry counted as home reserve"
	)
	for unit in _units(player, "Infantry"):
		unit.position = home
		unit.hp = unit.hp_max
		unit.issue_manual_order(null)
	var raider = tank_scene.instantiate()
	game._setup_and_spawn_unit(raider, Transform3D(Basis(), home + Vector3(8, 0, 0)), enemy, false)
	await _frames(5)
	game.battlefield.invalidate()
	policy = policy_script.new()
	_check(
		policy.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Home raid launched expedition"
	)
	raider.queue_free()
	await _frames(5)
	game.battlefield.invalidate()
	_check(
		policy.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Expedition ignored quiet-home interval"
	)
	await _frames(1210)
	_check(
		not policy.update(game, player, _owned(player), "defend", [], home).is_empty(),
		"Quiet recovered home never released scout"
	)
	print(
		"CAUTIOUS RELAY ", faction, " observation, reserve, pause, live withdrawal and quiet home"
	)
	game.queue_free()
	await _frames(5)
