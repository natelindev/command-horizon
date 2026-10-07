extends "res://tests/headless/WeaponModeRegression.gd"

const FRONTIER = "res://source/match/maps/DesertFrontier.tscn"
var factions
var observations = []


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	for scenario in [
		{
			"name": "infantry_swarm",
			"left":
			[
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry",
				"Infantry"
			],
			"right": ["CombatRobot", "CombatRobot", "CombatRobot"]
		},
		{
			"name": "prepared_lancers",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["CombatRobot", "CombatRobot", "CombatRobot"],
			"right_orders": "fire_support",
			"gap": 16.0
		},
		{
			"name": "prepared_prisms",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["AdvancedTank", "AdvancedTank"],
			"right_orders": "fire_support",
			"gap": 16.0
		},
		{"name": "lancer_close_duel", "left": ["Tank"], "right": ["CombatRobot"], "gap": 5.0},
		{"name": "tank_duel", "left": ["Tank"], "right": ["Tank"], "gap": 5.0},
		{"name": "tank_lines", "left": ["Tank", "Tank", "Tank"], "right": ["Tank", "Tank", "Tank"]},
		{
			"name": "lancers_vs_armor",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["CombatRobot", "CombatRobot", "CombatRobot"]
		},
		{
			"name": "prisms_vs_armor",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["AdvancedTank", "AdvancedTank"]
		},
		{
			"name": "precision_lines",
			"left": ["AdvancedTank", "AdvancedTank"],
			"right": ["AdvancedTank", "AdvancedTank"]
		},
		{
			"name": "mobile_aa",
			"left": ["CombatRobot", "CombatRobot"],
			"right": ["Helicopter", "Helicopter"]
		},
		{
			"name": "supported_armor",
			"left": ["Tank", "Tank", "RepairRobot"],
			"right": ["Tank", "Tank", "RepairRobot"]
		},
		{
			"name": "screened_lancers",
			"left": ["Tank", "Tank", "Tank"],
			"right": ["Infantry", "Infantry", "CombatRobot", "CombatRobot"]
		}
	]:
		for reverse in [false, true]:
			await _encounter(scenario, reverse)
	for result in observations:
		if result.name == "lancers_vs_armor":
			_check(
				result.remaining[0].is_empty() and not result.remaining[1].is_empty(),
				"Anti-armor Lancers lost their intended tank counter"
			)
		elif result.name == "infantry_swarm":
			_check(
				result.remaining[1].is_empty() and not result.remaining[0].is_empty(),
				"Lancers erased infantry counterplay"
			)
		elif result.name == "tank_duel":
			_check(
				result.seconds >= 8 and result.seconds <= 15, "Basic armor duel lost reaction time"
			)
	var path = "res://docs/playtests/2026-10-02/encounters.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Could not write encounter observations")
	if file != null:
		var report = {
			"method":
			(
				"Actual attack-move or named defender/support programs; mirrored placements; "
				+ "no production or signatures; fixed 60 Hz; costs kept as separate currencies"
			),
			"observations": observations
		}
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Encounter probe: %d harness failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _encounter(scenario, reverse):
	seed(20261002)
	await _skirmish("bastion", FRONTIER)
	var sides = _sides()
	sides[1].set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var teams = [[], []]
	var costs = []
	var stats = []
	var gap = scenario.get("gap", 12.0)
	for team in 2:
		var roles = scenario.left if team == 0 else scenario.right
		var total = Vector2.ZERO
		var roster = []
		for index in roles.size():
			var sign_x = (-1 if team == 0 else 1) * (-1 if reverse else 1)
			var point = Vector3(
				64 + sign_x * (gap / 2 + (index / 3) * 2.6),
				0,
				48 + ((index % 3) - min(roles.size() - 1, 2) / 2.0) * 3
			)
			var unit = _spawn_weapon(roles[index], sides[team], point)
			teams[team].append(unit)
			var cost = factions.cost(sides[team], roles[index])
			total += Vector2(cost.resource_a, cost.resource_b)
			roster.append(
				{
					"role": roles[index],
					"hp": unit.hp_max,
					"damage": unit.attack_damage,
					"reload": unit.attack_interval,
					"range": unit.attack_range
				}
			)
		costs.append({"materials": total.x, "electronics": total.y})
		stats.append(roster)
	await _frames(40)
	var started = game.simulation_time
	var first_hit = [-1.0, -1.0]
	var first_loss = [-1.0, -1.0]
	for team in 2:
		for unit in teams[team]:
			unit.process_mode = Node.PROCESS_MODE_PAUSABLE
			if unit.type == "RepairRobot":
				_check(
					unit.program.configure(unit.program.Library.defaults("escort_repair")),
					"Invalid support program"
				)
				unit.program.escort = teams[team][0]
				unit.program.run()
			elif team == 1 and scenario.has("right_orders"):
				var config = unit.program.Library.defaults(scenario.right_orders)
				config.radius = 12.0
				_check(unit.program.configure(config), "Invalid defensive probe program")
				unit.program.anchor = unit.global_position_yless
				_check(unit.program.run(), "Defensive probe program could not run")
			else:
				unit.issue_manual_order(
					load("res://source/match/units/actions/AttackMoving.gd").new(
						Vector3(
							64 + (1 if team == 0 else -1) * (-1 if reverse else 1) * gap / 2, 0, 48
						)
					)
				)
	for frame in 5400:
		await physics_frame
		var elapsed = game.simulation_time - started
		if frame == 120 and DisplayServer.get_name() != "headless":
			game.fog_of_war.reveal()
			var camera = game.get_node("IsometricCamera3D")
			camera.set_size_safely(26)
			camera.set_position_safely(Vector3(64, 0, 48))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				"res://art/skirmish/encounter-%s.png" % scenario.name
			)
		for team in 2:
			var alive = _alive(teams[team])
			if first_hit[team] < 0 and alive.any(func(unit): return unit.hp < unit.hp_max):
				first_hit[team] = elapsed
			if first_loss[team] < 0 and alive.size() < teams[team].size():
				first_loss[team] = elapsed
		if _combatants(teams[0]).is_empty() or _combatants(teams[1]).is_empty():
			break
	var remaining = []
	for team in 2:
		remaining.append(
			_alive(teams[team]).map(func(unit): return {"role": unit.type, "hp": unit.hp})
		)
	var ceiling = Vector2(
		maxf(costs[0].materials, costs[1].materials),
		maxf(costs[0].electronics, costs[1].electronics)
	)
	var unspent = costs.map(
		func(cost):
			return {
				"materials": ceiling.x - cost.materials, "electronics": ceiling.y - cost.electronics
			}
	)
	var result = {
		"budget": {"materials": ceiling.x, "electronics": ceiling.y},
		"unspent": unspent,
		"name": scenario.name,
		"reverse": reverse,
		"costs": costs,
		"stats": stats,
		"first_damage_received": first_hit,
		"first_loss": first_loss,
		"seconds": game.simulation_time - started,
		"remaining": remaining
	}
	_check(first_hit.any(func(t): return t >= 0), "Encounter never engaged: " + scenario.name)
	observations.append(result)
	print(JSON.stringify(result))
	await _clean_match()


func _alive(team):
	return team.filter(
		func(unit):
			return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0
	)


func _combatants(team):
	return _alive(team).filter(func(unit): return unit.type != "RepairRobot")
