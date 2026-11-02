extends "res://tests/headless/MapResourceBalanceRegression.gd"

var _advanced = false
var _homes_checked = 0
var _piles_checked = 0


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var legacy = load("res://source/match/economy/LegacyHomeFields.gd")
	for map_path in constants.Match.MAPS:
		if map_path.get_file().get_basename() not in legacy.MAPS:
			continue
		for advanced in [false, true]:
			_advanced = advanced
			await _create(map_path)
			_verify_homes(map_path)
			game.queue_free()
			await _frames(6)
	for message in _errors:
		push_error(message)
	print(
		(
			"Legacy home navigation: %d homes, %d deposits, %d failures"
			% [_homes_checked, _piles_checked, _errors.size()]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _create(map_path):
	var settings = _settings("bastion", "helix", _advanced)
	settings.map_path = map_path
	for index in range(2, constants.Match.MAPS[map_path].players):
		var player = settings.players[1].duplicate()
		player.faction = "frontier" if index % 2 == 0 else "bastion"
		player.color = Color.from_hsv(index / 8.0, .7, .9)
		settings.players.append(player)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for player in get_nodes_in_group("players"):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(60)
	for frame in 600:
		if game.navigation.terrain.is_synchronized():
			break
		await physics_frame
	await _frames(10)


func _verify_homes(map_path):
	var plans = game.map.get_meta("home_field_plans", [])
	var players = get_nodes_in_group("players")
	_check(plans.size() == players.size(), "Missing home plans: " + map_path)
	var deposits = game.map.get_node("Resources").find_children("*", "", true, false).filter(
		func(node): return node.is_in_group("resource_units")
	)
	var native_expected = "--native-crowd-runtime" in OS.get_cmdline_user_args()
	for player in players:
		var hq = player.get_children().filter(func(node): return node.is_in_group("units") and node.type == "CommandCenter")[0]
		var start = Vector2(hq.global_position.x, hq.global_position.z)
		var matching = plans.filter(func(plan): return plan.origin.distance_to(start) < 10.1)
		_check(matching.size() == 1, "Home origin lost owning HQ: " + map_path)
		if matching.size() != 1:
			continue
		var plan = matching[0]
		var piles = deposits.filter(
			func(node):
				return (
					Vector2(node.harvest_origin.x, node.harvest_origin.z).distance_to(plan.origin)
					< .01
				)
		)
		_check(piles.size() == 7, "Home lost five materials/two electronics: " + map_path)
		var hq_ring = _ring(hq.global_position, hq.radius, HQ_SIDES)
		_check(not hq_ring.points.is_empty(), "Home HQ has no open approach: " + map_path)
		for pile in piles:
			var deposit_ring = _ring(pile.global_position, pile.radius, DEPOSIT_SIDES)
			_check(
				deposit_ring.points.size() >= 3,
				(
					"Deposit has no clear worker approach: %s %s advanced=%s open=%d"
					% [
						map_path.get_file(),
						pile.global_position,
						_advanced,
						deposit_ring.points.size()
					]
				)
			)
			var trip = _trip(hq_ring, deposit_ring)
			_check(
				is_finite(trip) and trip < 35,
				(
					"Home deposit route blocked or detoured: %s %s advanced=%s trip=%s"
					% [map_path.get_file(), pile.global_position, _advanced, trip]
				)
			)
			for structure in player.get_children().filter(
				func(node): return node.is_in_group("units") and node.has_node("MovementObstacle")
			):
				var clearance = (
					Vector2(pile.global_position.x, pile.global_position.z).distance_to(
						Vector2(structure.global_position.x, structure.global_position.z)
					)
					- pile.radius
					- structure.get_node("MovementObstacle").radius
				)
				_check(
					clearance >= .7 - .01,
					(
						"Deposit touches starting structure: %s pile=%s structure=%s position=%s radius=%s clearance=%s advanced=%s"
						% [
							map_path.get_file(),
							pile.global_position,
							structure.type,
							structure.global_position,
							structure.radius,
							clearance,
							_advanced
						]
					)
				)
			_piles_checked += 1
		for worker in player.get_children().filter(
			func(node): return node.is_in_group("units") and node.type == "Worker"
		):
			if native_expected:
				_check(
					worker.get_node("Movement")._native_handle >= 0,
					"Home QA disabled native worker binding"
				)
		_homes_checked += 1
	print(
		"HOME NAV ",
		map_path.get_file(),
		" advanced=",
		_advanced,
		" starts=",
		players.size(),
		" checked=",
		_piles_checked
	)
