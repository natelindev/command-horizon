extends "res://tests/headless/FixedWingFlightRegression.gd"

# Repeatable open-ground, near-equal-cost engagements. These measurements cover
# one carried aircraft load, without an airfield or free scenario ammunition.
# They are diagnostics for tuning, not a claim about whole-match faction balance.

const BUDGET = 180
const DURATION = 60.0
const PAIRS = [
	["Fighter", "Helicopter"],
	["AntiAirVehicle", "Fighter"],
	["AntiAirVehicle", "Helicopter"],
	["Tank", "AntiAirVehicle"],
	["Helicopter", "Tank"],
	["Bomber", "Tank"],
	["Drone", "Tank"],
	["AntiAirVehicle", "Drone"],
]
var _results = []


func _run():
	_combat_rules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.match_seed = 713
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		settings.players.append(side)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	_game.repair_service.set_physics_process(false)
	await _ticks(30)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _ticks(5)
	var factions = ["bastion", "helix", "frontier"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--faction="):
			factions = [argument.get_slice("=", 1)]
	for faction in factions:
		_human.faction = faction
		_enemy.faction = faction
		for pair in PAIRS:
			await _engagement(faction, pair)
	_game.queue_free()
	await _ticks(5)
	print("AIR MATCHUPS ", JSON.stringify(_results))
	for message in _errors:
		push_error(message)
	quit(0 if _errors.is_empty() else 1)


func _engagement(faction, roles):
	var costs = load("res://source/match/FactionRules.gd").unit_costs(faction)
	var teams = []
	var invested = []
	var health = []
	var prices = []
	for side in 2:
		var price = costs[roles[side]][0] + costs[roles[side]][1]
		var count = maxi(1, roundi(float(BUDGET) / price))
		var team = []
		var initial_health = []
		for index in count:
			var point = Vector3(45 if side == 0 else 55, 0, 44 + index * 1.8)
			var unit = _spawn(roles[side], _human if side == 0 else _enemy, point)
			unit.stance = unit.Stance.HOLD_FIRE
			if "unlimited_stores" in unit:
				unit.unlimited_stores = false
			team.append(unit)
			initial_health.append(unit.hp_max)
		teams.append(team)
		health.append(initial_health)
		prices.append(price)
		invested.append(price * count)
	await _ticks(10)
	var started = _game.simulation_time
	var largest_round_count = 0
	while _game.simulation_time - started < DURATION:
		var living = [_living(teams[0]), _living(teams[1])]
		if living[0].is_empty() or living[1].is_empty():
			break
		for side in 2:
			for index in living[side].size():
				var unit = living[side][index]
				var targets = living[1 - side]
				var target = targets[0]
				for candidate in targets:
					if (
						unit.global_position.distance_squared_to(candidate.global_position)
						< unit.global_position.distance_squared_to(target.global_position)
					):
						target = candidate
				if not _combat_rules.can_target(unit, target):
					continue
				if (
					unit.action == null
					or str(unit.action).begins_with("WaitingForTargets")
					or (
						"_target_unit" in unit.action
						and not is_instance_valid(unit.action._target_unit)
					)
					or str(unit.action).begins_with("AirIdle")
				):
					unit.issue_manual_order(load(ACTIONS + "AutoAttacking.gd").new(target))
		largest_round_count = maxi(largest_round_count, _game.projectile_system.round_count())
		await _ticks(10)
	var surviving_value = []
	for side in 2:
		var value = 0.0
		for index in teams[side].size():
			var unit = teams[side][index]
			if is_instance_valid(unit) and unit.hp > 0:
				value += prices[side] * unit.hp / health[side][index]
		surviving_value.append(snappedf(value, 0.01))
	var row = {
		"faction": faction,
		"roles": roles,
		"count": [teams[0].size(), teams[1].size()],
		"cost": invested,
		"remaining_value": surviving_value,
		"seconds": snappedf(_game.simulation_time - started, 0.01),
		"peak_rounds": largest_round_count,
	}
	print("AIR MATCHUP ", JSON.stringify(row))
	_results.append(row)
	_check(
		surviving_value[0] < invested[0] or surviving_value[1] < invested[1],
		"No combat damage in %s %s" % [faction, roles]
	)
	for team in teams:
		for unit in _living(team):
			unit.queue_free()
	_game.projectile_system.clear()
	await _ticks(5)


func _living(team):
	return team.filter(func(unit): return is_instance_valid(unit) and unit.hp > 0)
