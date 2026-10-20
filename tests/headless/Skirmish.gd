extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")

var factions
var constants
var _errors = []


func _initialize():
	call_deferred("_run")


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	await _test_setup()
	for faction in factions.IDS:
		for opponent in factions.IDS:
			await _test_roster(faction, opponent)
	await _test_maps_and_combat()
	for opponent in factions.IDS:
		await _test_ai(opponent)
	if _errors.is_empty():
		print(
			(
				"PASS: skirmish setup/random, all faction pairings, production, construction, "
				+ "AA, pause, results, restart and AI economy/attacks"
			)
		)
	else:
		for message in _errors:
			push_error(message)
	quit(0 if _errors.is_empty() else 1)


func _test_setup():
	var scene = load("res://source/match/Match.tscn")
	var first = scene.instantiate()
	var second = scene.instantiate()
	for domain in ["Terrain", "Air"]:
		var path = "Navigation/%s/NavigationRegion3D" % domain
		_check(
			first.get_node(path).navigation_mesh != second.get_node(path).navigation_mesh,
			"Matches share mutable navigation mesh: " + domain
		)
	first.free()
	second.free()
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(setup)
	setup._player_faction.select(1)
	setup._enemy_faction.select(factions.IDS.size())
	var seen = {}
	for index in range(40):
		setup._map_list.select(index % 3)
		var settings = setup._create_match_settings()
		_check(
			settings.players.size() == 2 and settings.players[0].faction == "helix",
			"Setup player faction"
		)
		_check(settings.players[1].faction in factions.IDS, "Random faction unresolved")
		seen[settings.players[1].faction] = true
		var expected = constants.Match.MAPS[settings.map_path].players / 2 - 1
		_check(settings.players[1].spawn_index_offset == expected, "Opposite spawn index")
	_check(seen.size() == factions.IDS.size(), "Random selection did not cover all factions")
	setup.queue_free()
	await _frames(2)


func _settings(faction, opponent, advanced = true):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = advanced
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction if index == 0 else opponent
		player.color = Color.GOLD if index == 0 else Color.RED
		settings.players.append(player)
	return settings


func _start(settings):
	var game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)
	return game


func _test_roster(faction, opponent):
	var game = await _start(_settings(faction, opponent))
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_check(enemy.faction == opponent, "Opponent faction")
	var tank = _unit(human, "Tank")
	_check(
		tank.hp_max == {"bastion": 80, "helix": 64, "frontier": 68}[faction],
		"Faction HP distinction"
	)
	if faction in ["helix", "frontier"]:
		_check(tank.get_meta("model_faction", "") == faction, "Faction tank model")
	_check(game.find_child("Minimap").can_process(), "Minimap active")
	game.hud._toggle_pause()
	var before = game.simulation_time
	await _frames(10)
	_check(game.simulation_time == before, "Simulation clock advanced while paused")
	_check(game.find_child("Minimap").can_process(), "Minimap disabled while paused")
	_check(
		game.get_node("Handlers/UnitGroupSelectionHandler").can_process(),
		"Groups disabled while paused"
	)
	game.hud._toggle_pause()
	human.resource_a = 10000
	human.resource_b = 10000
	var air = load(Catalog.scene_path("AircraftFactory")).instantiate()
	game._setup_and_spawn_unit(air, Transform3D(Basis(), Vector3(32, 0, 12)), human, false)
	# HQs supply 8 power and generators 12: the airfield needs a second generator.
	var generator = load(Catalog.scene_path("PowerPlant")).instantiate()
	game._setup_and_spawn_unit(generator, Transform3D(Basis(), Vector3(26, 0, 12)), human, false)
	await _frames(2)
	_check(human.start_coordination(_unit(human, "CommandLab")), "Could not start Coordination")
	human._physics_process(30.0)
	_check(human.coordination_unlocked, "Coordination did not unlock")
	var parked = 0
	for producer_type in Catalog.PRODUCES:
		var producer = _unit(human, producer_type)
		for role in Catalog.PRODUCES[producer_type]:
			var funds = Vector2i(human.resource_a, human.resource_b)
			var price = factions.cost(human, role)
			var job = producer.production_queue.produce(load(Catalog.scene_path(role)))
			_check(job != null, "Could not queue " + faction + " " + role)
			_check(
				(
					funds - Vector2i(human.resource_a, human.resource_b)
					== Vector2i(price.resource_a, price.resource_b)
				),
				"Faction price mismatch"
			)
			producer.production_queue.cancel(job)
			_check(
				funds == Vector2i(human.resource_a, human.resource_b),
				"Cancellation refund mismatch"
			)
			var existing = human.get_children()
			producer.production_queue.produce(load(Catalog.scene_path(role)))
			producer.production_queue._process(1000)
			_check(_unit(human, role) != null, "Production failed " + role)
			# No frames pass here, so move each new unit off the exit for the next job.
			for unit in human.get_children():
				if not unit in existing and "type" in unit:
					unit.global_position = Vector3(8 + parked * 2.5, unit.global_position.y, 34)
					parked += 1
			if faction in ["helix", "frontier"]:
				_check(
					_unit(human, role).get_meta("model_faction", "") == faction,
					"Wrong faction produced " + role
				)
	for unit in human.get_children():
		if not "type" in unit:
			continue
		var team_surfaces = 0
		for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				if mesh.get_surface_override_material(surface) == human.get_color_material():
					team_surfaces += 1
		_check(team_surfaces > 0, "Team color missing: " + faction + " " + unit.type)
	var placement = human.get_node("StructurePlacementHandler")
	for role in Catalog.STRUCTURES:
		placement._start_structure_placement(load(Catalog.scene_path(role)))
		_check(placement._active_blueprint_node != null, "Missing construction preview")
		placement._cancel_structure_placement()
	var building = load(Catalog.scene_path("AntiAirTurret")).instantiate()
	game._setup_and_spawn_unit(building, Transform3D(Basis(), Vector3(35, 0, 20)), human)
	_check(building.is_under_construction(), "Building starts completed")
	building.construct(1.0)
	_check(building.is_constructed(), "Construction did not finish")
	var walker = _unit(human, "CombatRobot")
	if faction == "helix":
		_check(walker.request_weapon_mode("interception"), "Missing mobile AA stance")
		await _frames(125)
	_check(walker.attack_domains.has(constants.Match.Navigation.Domain.AIR), "Missing mobile AA")
	# Frontier's heavy tank needs a field workshop; the others need the lab.
	var gate = _unit(human, factions.requirement(human, "AdvancedTank"))
	gate._construction_progress = 0.0
	_check(not factions.available(human, "AdvancedTank"), "Heavy tank requirement bypassed")
	gate._construction_progress = 1.0
	# Finish a real skirmish through HQ loss; survivors cannot indefinitely stall it.
	var losers = [enemy]
	var expected_result = "Victory"
	if faction == opponent:
		losers = [human] if faction == "helix" else [human, enemy]
		expected_result = "Defeat" if faction == "helix" else "Draw"
	for loser in losers:
		_unit(loser, "CommandCenter").queue_free()
	await _frames(3)
	for loser in losers:
		game._defeat_timers[loser] = 60.0
	game._physics_process(59.0)
	_check(not game.finished, "Recovery countdown ended early")
	game._physics_process(1.1)
	_check(game.finished and paused and game.hud._overlay != null, "Result screen missing")
	_check(game.result == expected_result, "Incorrect match result")
	if faction == "helix" and opponent == "bastion":
		game.restart()
		await _frames(70)
		_check(
			current_scene != game and current_scene.settings.players[0].faction == faction,
			"Restart lost faction"
		)
		_check(not paused and not current_scene.finished, "Restart retained match end")
		current_scene.queue_free()
	else:
		paused = false
		game.queue_free()
	await _frames(6)


func _test_maps_and_combat():
	for map_name in ["PlainAndSimple", "BigArena"]:
		for advanced in [false, true]:
			var settings = _settings("helix", "bastion", advanced)
			settings.map_path = "res://source/match/maps/%s.tscn" % map_name
			settings.players[1].spawn_index_offset = 1
			var game = await _start(settings)
			for unit in get_nodes_in_group("units"):
				_check(
					unit.global_position.x > 0 and unit.global_position.x < game.map.size.x,
					"Spawn outside map X"
				)
				_check(
					unit.global_position.z > 0 and unit.global_position.z < game.map.size.y,
					"Spawn outside map Z"
				)
			game.queue_free()
			await _frames(6)
	var game = await _start(_settings("helix", "bastion", false))
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	var walker = load(Catalog.scene_path("CombatRobot")).instantiate()
	var aircraft = load(Catalog.scene_path("Drone")).instantiate()
	game._setup_and_spawn_unit(walker, Transform3D(Basis(), Vector3(40, 0, 10)), human, false)
	game._setup_and_spawn_unit(aircraft, Transform3D(Basis(), Vector3(43, 2, 10)), enemy, false)
	aircraft.hp = 1000
	await _frames(3)
	var attack = load("res://source/match/units/actions/AutoAttacking.gd")
	_check(not attack.is_applicable(walker, aircraft), "Precision can target air")
	_check(walker.request_weapon_mode("interception"), "Interception switch rejected")
	await _frames(125)
	aircraft.hp = 1000
	_check(attack.is_applicable(walker, aircraft), "Walker cannot target air")
	walker.set_meta("next_attack_availability_time", int(game.simulation_time * 1000) + 600)
	game.hud._toggle_pause()
	walker.action = attack.new(aircraft)
	await _frames(45)
	_check(aircraft.hp == 1000, "Paused attack dealt damage")
	game.hud._toggle_pause()
	await _frames(12)
	_check(aircraft.hp == 1000, "Paused retarget bypassed weapon cooldown")
	await _frames(90)
	_check(aircraft.hp < 1000, "Helix mobile AA failed to damage aircraft")
	game.queue_free()
	await _frames(6)


func _test_ai(opponent):
	var game = await _start(_settings("bastion", opponent, false))
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	# Keep the human alive and stationary; exercise actual AI economy over six simulation minutes.
	human.process_mode = Node.PROCESS_MODE_DISABLED
	_unit(human, "CommandCenter").hp = 100000
	for _index in range(21600):
		await physics_frame
	_check(enemy.structures_built >= 3, "AI did not build its economy")
	_check(enemy.attacks_launched > 0, "AI never launched an attack")
	_check(game.units_produced > 3, "AI did not produce reinforcements")
	print(
		"AI OBSERVATION ",
		opponent,
		": structures=",
		enemy.structures_built,
		" attacks=",
		enemy.attacks_launched,
		" produced=",
		game.units_produced
	)
	game.queue_free()
	paused = false
	await _frames(6)


func _unit(player, role):
	for unit in player.get_children():
		if "type" in unit and unit.type == role and not unit.is_queued_for_deletion():
			return unit
	return null


func _frames(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
