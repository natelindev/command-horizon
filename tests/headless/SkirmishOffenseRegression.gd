extends "res://tests/headless/SaveRestoreEdges.gd"

var attack_move


func _run():
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for region in ["alpine", "desert"]:
		await _archived_wave(region)
	await _archived_engineer()
	for faction in ["bastion", "helix"]:
		await _goal_contract(faction)
	manager.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish offense: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _archived_wave(region):
	var filename = "res://docs/playtests/2026-10-04/ai-composition-%s-ground-stall.json" % region
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(filename))
	_check(loaded.ok, "Could not restore offensive diversion archive: " + region)
	if not loaded.ok:
		return
	game = loaded.game
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	opponent.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var scouts = _units(human, "Drone")
	_check(not scouts.is_empty(), "Archived scout missing")
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, scouts[0]), "Archived scout not observed")
	var waves = opponent.attacks_launched
	game.simulation_time = maxf(200.0, game.simulation_time)
	opponent._last_wave = game.simulation_time - 70
	opponent._command_army(opponent._units())
	_check(opponent.attacks_launched == waves + 1, "Archived wave did not launch")
	var enemy_start = game.map.find_child("SpawnPoints").get_child(0).position
	var tanks = _units(opponent, "Tank")
	var departures = []
	for unit in tanks:
		if is_instance_of(unit.action, attack_move):
			print("ARCHIVE WAVE ", region, " ", unit.type, " ", unit.action.destination)
			if unit.action.destination.distance_to(enemy_start) < 12:
				departures.append(unit)
	_check(departures.size() >= 3, "Ground wave diverted toward scout: " + region)
	var points = departures.map(func(unit): return unit.position)
	for unit in opponent._units():
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	game.hud._toggle_pause()
	await _frames(450)
	game.hud._toggle_pause()
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Offensive departure snapshot failed")
	if data != null:
		var ids = departures.map(func(unit): return capture._reference(unit))
		var positions = departures.map(func(unit): return unit.position)
		var goals = departures.map(func(unit): return unit.action.destination)
		var age = game.simulation_time - opponent._last_wave
		var clock_before = game.simulation_time
		var archive = "user://ai-offense-%d.json" % OS.get_process_id()
		var store = FileStore.new()
		_check(store.write_file(archive, data), "Offensive departure archive write failed")
		var restore = Restore.new()
		var restored = await restore.restore(self, store.read_file(archive))
		DirAccess.remove_absolute(archive)
		_check(restored.ok, "Offensive departure archive restore failed")
		if restored.ok:
			game = restored.game
			departures = ids.map(func(id): return restore.entities[id])
			opponent = departures[0].player
			opponent.set_process(false)
			for unit in get_nodes_in_group("units"):
				unit.process_mode = (
					Node.PROCESS_MODE_INHERIT
					if unit.player == opponent
					else Node.PROCESS_MODE_DISABLED
				)
			await _frames(15)
			_check(paused and game.simulation_time == clock_before, "Offensive archive lost pause")
			_check(
				is_equal_approx(game.simulation_time - opponent._last_wave, age),
				"Offensive archive changed wave timer"
			)
			for index in departures.size():
				_check(departures[index].position == positions[index], "Paused wave moved")
				_check(
					departures[index].action.destination == goals[index],
					"Offensive archive changed goal"
				)
	game.hud._toggle_pause()
	# Allow a congested base exit and a detour around occupied structures.
	# A 15-second displacement sample can land during an ordinary repath.
	await _frames(1350)
	for index in departures.size():
		var travel = points[index].distance_to(departures[index].position)
		print("ARCHIVE DEPARTURE ", region, " ", travel)
		if travel <= 8.0:
			var unit = departures[index]
			var movement = unit.get_node("Movement")
			print(
				"DEPARTURE DETAIL ",
				unit.position,
				" ",
				movement.target_position,
				" path=",
				movement.get_current_navigation_path(),
				" action=",
				unit.action,
				" shot=",
				unit.action._shot if is_instance_of(unit.action, attack_move) else null
			)
			print(
				"DEPARTURE QUERY ",
				NavigationServer3D.map_get_path(
					movement.get_navigation_map(), unit.position, movement.target_position, true
				),
				" nearest=",
				NavigationServer3D.map_get_closest_point(
					movement.get_navigation_map(), unit.position
				)
			)
			print(
				"DEPARTURE PROCESS ",
				movement.is_physics_processing(),
				" ",
				movement.can_process(),
				" sync=",
				movement._synchronized,
				" has=",
				movement._has_destination,
				" velocity=",
				movement.velocity,
				" revision=",
				movement._command_revision,
				" layers=",
				movement.navigation_layers,
				" radius=",
				movement.radius,
				" paused=",
				paused
			)
			game.hud._toggle_pause()
			var failure = Snapshot.new().capture(game)
			if failure != null:
				var target_file = (
					"res://tmp/ai-offense-departure-stall-%s-%d.json"
					% [region, OS.get_process_id()]
				)
				print(
					"DEPARTURE ARCHIVE ",
					target_file,
					" ",
					FileStore.new().write_file(target_file, failure)
				)
			game.hud._toggle_pause()
		_check(travel > 8.0, "Corrected archived tank failed to depart: " + region)
	await _review_wave(region, departures)
	paused = false
	game.queue_free()
	await _frames(5)
	print("PASS: archived ", region, " wave, actual departure and paused disk restore")


func _goal_contract(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	opponent.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var observer = _actor("Worker", opponent, Vector3(62, 0, 18))
	observer.sight_range = 20
	var tanks = _units(opponent, "Tank")
	tanks.append(_actor("Tank", opponent, Vector3(96, 0, 70)))
	var scout = _actor("Drone", human, Vector3(62, 2, 16))
	var fighter = _actor("Infantry", human, Vector3(63, 0, 20))
	var worker = _actor("Worker", human, Vector3(65, 0, 16))
	var power = _actor("PowerPlant", human, Vector3(70, 0, 12))
	var factory = _actor("VehicleFactory", human, Vector3(70, 0, 24))
	var hq = _actor("CommandCenter", human, Vector3(78, 0, 18))
	var own = _units(opponent, "CommandCenter")[0]
	var base = game.map.find_child("SpawnPoints").get_child(0).position
	await _frames(20)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, hq), "Offensive HQ fixture hidden")
	var contacts = [scout, fighter, worker, power, factory, hq, own]
	_check(
		opponent._offensive_goal(tanks, contacts, base) == hq.global_position_yless,
		"Offense failed to prioritize observed enemy HQ"
	)
	contacts.reverse()
	_check(
		opponent._offensive_goal(tanks, contacts, base) == hq.global_position_yless,
		"Enemy enumeration order changed economic priority"
	)
	_check(
		(
			opponent._offensive_goal(tanks, [scout, fighter, worker, power, factory], base)
			== factory.global_position_yless
		),
		"Offense failed to prioritize observed production"
	)
	_check(
		(
			opponent._offensive_goal(tanks, [scout, fighter, worker, power], base)
			== power.global_position_yless
		),
		"Offense failed to prioritize infrastructure"
	)
	_check(
		(
			opponent._offensive_goal(tanks, [scout, fighter, worker], base)
			== worker.global_position_yless
		),
		"Offense ignored exposed enemy engineer"
	)
	_check(
		opponent._offensive_goal(tanks, [scout, fighter, own], base) == base,
		"Scout/combat/friendly contact diverted strategic objective"
	)
	_check(
		opponent._offensive_goal([observer], [hq], base) == base,
		"Unarmed force selected an attack objective"
	)
	observer.sight_range = 0
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(opponent, hq), "Hidden offensive fixture observed")
	_check(
		opponent._offensive_goal(tanks, contacts, base) == base,
		"Hidden economic contacts changed strategic objective"
	)
	observer.sight_range = 20
	game.battlefield.invalidate()
	if opponent.faction == "helix":
		var lancer = _actor("CombatRobot", opponent, Vector3(62, 0, 10))
		lancer.weapon_mode = "interception"
		lancer.configure_weapon()
		_check(
			opponent._offensive_goal([lancer], [hq, own], base) == hq.global_position_yless,
			"Mode-switching ground counter lost strategic objective"
		)
		_check(
			opponent._offensive_goal([lancer], [own], base) == base,
			"Mode-switching counter targeted its own economy"
		)
		lancer.sight_range = 0
	var funds = Vector2(opponent.resource_a, opponent.resource_b)
	var waves = opponent.attacks_launched
	game.simulation_time = 200
	opponent._last_wave = 200
	opponent._command_army(tanks)
	_check(opponent.attacks_launched == waves, "Offensive selection ignored wave interval")
	opponent._last_wave = 130
	opponent._command_army(tanks)
	_check(opponent.attacks_launched == waves + 1, "Eligible economic wave failed to launch")
	var actions = tanks.map(func(unit): return unit.action)
	var destinations = tanks.map(func(unit): return unit.action.destination)
	for destination in destinations:
		_check(destination.distance_to(hq.global_position_yless) < 3, "Wave missed economic goal")
	observer.sight_range = 0
	hq.position += Vector3(2, 0, 0)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(opponent, hq), "Lost economic goal remains observed")
	game.simulation_time = 220
	opponent._command_army(tanks)
	for index in tanks.size():
		_check(
			(
				tanks[index].action == actions[index]
				and tanks[index].action.destination == destinations[index]
			),
			"Unseen economic movement changed an in-progress wave"
		)
	game.simulation_time = 266
	opponent._command_army(tanks)
	_check(opponent.attacks_launched == waves + 2, "Next offensive interval failed to launch")
	for unit in tanks:
		_check(unit.action.destination.distance_to(base) < 3, "New wave chased a hidden economy")
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds,
		"Offensive command spent resources"
	)
	observer.sight_range = 20
	game.battlefield.invalidate()
	hq.hp = 0
	_check(
		opponent._offensive_goal(tanks, [hq, factory], base) == factory.global_position_yless,
		"Destroyed HQ remained the offensive objective"
	)
	game.queue_free()
	await _frames(5)
	print("PASS: ", faction, " priorities, hidden contacts, ownership, domains and wave interval")


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _archived_engineer():
	var archive = "res://docs/playtests/2026-10-04/ai-composition-alpine-worker-stall.json"
	var restored = await Restore.new().restore(self, FileStore.new().read_file(archive))
	_check(restored.ok, "Could not restore delayed engineer")
	if not restored.ok:
		return
	game = restored.game
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	for unit in human.get_children():
		if unit.is_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var workers = _units(opponent, "Worker")
	var origin = Vector3(113.6852, 0, 87.61482)
	workers.sort_custom(
		func(a, b): return a.position.distance_to(origin) < b.position.distance_to(origin)
	)
	var worker = workers[0]
	_check(worker.position.distance_to(origin) < 0.1, "Wrong archived engineer selected")
	_check(worker.resource_a == 0, "Archived engineer already carried materials")
	var first_cargo = -1.0
	var returned = false
	var clock_before = game.simulation_time
	var previous = worker.position
	var maximum_step = 0.0
	game.hud._toggle_pause()
	for frame in 3600:
		await physics_frame
		if not is_instance_valid(worker):
			break
		maximum_step = maxf(maximum_step, worker.position.distance_to(previous))
		previous = worker.position
		if first_cargo < 0 and worker.resource_a > 0:
			first_cargo = game.simulation_time - clock_before
		if first_cargo >= 0 and worker.resource_a == 0:
			returned = true
			break
		if frame % 600 == 599:
			var movement = worker.get_node("Movement")
			print(
				"ENGINEER TRACE ",
				game.simulation_time - clock_before,
				" position=",
				worker.position,
				" action=",
				worker.action,
				" destination=",
				movement.target_position,
				" path=",
				movement.get_current_navigation_path()
			)
	_check(returned, "Archived engineer did not collect and deliver within sixty seconds")
	if is_instance_valid(worker):
		_check(
			maximum_step <= worker.movement_speed / 60.0 + 0.002, "Engineer replay exceeded speed"
		)
	print(
		"ARCHIVED ENGINEER cargo=",
		first_cargo,
		" delivered=",
		returned,
		" elapsed=",
		game.simulation_time - clock_before
	)
	game.queue_free()
	await _frames(5)


func _review_wave(_region, _departures):
	pass
