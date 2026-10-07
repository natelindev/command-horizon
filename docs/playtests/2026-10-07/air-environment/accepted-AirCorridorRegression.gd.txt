extends "res://tests/headless/SupplyLineRegression.gd"


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "air_corridor"
	settings.map_path = "res://source/match/maps/AirCorridorMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = difficulty
		settings.players.append(side)
	game = load("res://source/match/campaign/AirCorridor.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _run():
	path = "user://air-progress-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _make_match()
	await _rules()
	await _close()
	await _make_match()
	await _play_air()
	await _close()
	await _exposed_flight()
	await _difficulty_and_limits()
	_migrate_progress()
	await _make_match()
	_check(
		_units(game._enemy, "Helicopter").is_empty() and game._get_human_player().resource_b == 80,
		"Network reward did not remove initial patrol"
	)
	await _close()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Air Corridor: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _rules():
	_check(
		game.flights.size() == 3 and game.sites.size() == 2, "Air Corridor objective setup failed"
	)
	_check(not game.launch_flight(), "Evacuation launched before batteries were cleared")
	_check(game._get_human_player().basic_programs_unlocked(), "Air/ground presets unavailable")
	var a = Vector3(36, 0, 52)
	var b = game.map.SCREEN
	var ground = NavigationServer3D.map_get_path(
		game.navigation.get_navigation_map_rid_by_domain(1), a, b, true
	)
	var air = NavigationServer3D.map_get_path(
		game.navigation.get_navigation_map_rid_by_domain(0), a, b, true
	)
	_check(_length(ground) > _length(air) + 15, "Quarry does not distinguish ground/air routes")
	# Controlled geometry/service/archive fixture, separate from the live combat run.
	for unit in game._enemy.get_children():
		if unit.is_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var tank = _units(game._get_human_player(), "Tank")[0]
	var scout = _units(game._get_human_player(), "Drone")[0]
	tank.issue_manual_order(moving.new(b))
	scout.issue_manual_order(moving.new(b))
	var start = game.simulation_time
	while tank.position.distance_to(b) > 3 and game.simulation_time - start < 100:
		await _frames(30)
	_check(tank.position.distance_to(b) < 3, "Ground force cannot traverse quarry bypass")
	_check(scout.global_position_yless.distance_to(b) < 3, "Aircraft cannot cross quarry")
	for site in game.sites:
		site.unit.hp = 0
	await _frames(5)
	paused = true
	_check(game.launch_flight(), "Cleared corridor cannot launch while paused")
	var ship = game.flights[0].unit
	var point = ship.position
	await _frames(30)
	_check(ship.position == point, "Paused evacuation moved")
	_check(
		ship.type == "EvacTransport" and ship.program == null, "Transport has combat/program role"
	)
	paused = false
	await _frames(180)
	_check(ship.position.distance_to(point) > 2, "Evacuation did not depart")
	_check(not game.launch_flight(), "Overlapping evacuation flights allowed")
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Air mission capture failed: " + capture.error)
	if data == null:
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Air mission schema failed: " + schema.error)
	var bad = data.duplicate(true)
	bad.mission.flights[1] = bad.mission.flights[0].duplicate(true)
	_check(not schema.validate(bad), "Duplicate active transport accepted")
	bad = data.duplicate(true)
	bad.mission.flights[0].response_left = 11.0
	_check(not schema.validate(bad), "Invalid response time accepted")
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var file_path = path + ".archive"
	_check(store.write_file(file_path, data), "Air archive could not write")
	data = store.read_file(file_path)
	DirAccess.remove_absolute(file_path)
	var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
	_check(restored.ok, "Air archive could not restore: " + restored.get("error", ""))
	if not restored.ok:
		return
	game = restored.game
	game.progress_path = path
	_check(
		paused and capture.capture(game).mission == data.mission, "Restored flight/timers changed"
	)
	var before = game._enemy.population()
	var remaining = game.flights[0].response_left
	game._check_outcome(remaining - 0.1)
	_check(game._enemy.population() == before, "Restored response arrived early")
	game._check_outcome(0.2)
	_check(game._enemy.population() == before + 3, "Standard ground/air response budget wrong")
	game._send_response(game.flights[0])
	_check(game._enemy.population() == before + 3, "Response replayed")
	# Air service heals the transport; a mobile repair robot must not heal aircraft.
	ship = game.flights[0].unit
	ship.issue_manual_order(null)
	ship.position = Vector3(14, ship.position.y, 64)
	ship.hp = 80
	paused = false
	await _frames(120)
	_check(ship.hp > 80, "Evacuation VTOL cannot use stationary hangar service")
	ship.hp = 0
	await _frames(5)
	_check(not game.finished and game.flights[0].state == "lost", "One flight loss ended mission")
	_check(game.launch_flight(), "Loss prevented next flight launch")
	paused = true
	var blockers = _units(game._get_human_player(), "Infantry")
	for index in 2:
		blockers[index].position = game.map.ENTRIES[index]
	before = game._enemy.population()
	game._check_outcome(10)
	_check(game._enemy.population() == before, "Occupied response entry was not denied")
	game.flights[1].unit.hp = 0
	paused = false
	await _frames(5)
	_check(game.finished and game.result == "Defeat", "Two flight losses did not cause defeat")


func _play_air():
	# Normal commander orders and shipped presets, with no altered enemy HP or deletions.
	var human = game._get_human_player()
	for index in 2:
		var point = game.map.SITES[index]
		for unit in human.get_children():
			if (
				unit.is_in_group("units")
				and unit.movement_speed > 0
				and unit.movement_domain == 1
				and unit.type != "Worker"
			):
				unit.issue_manual_order(
					(
						attack_move.new(point + Vector3(unit.get_index() % 3, 0, 0))
						if unit.attack_range != null
						else moving.new(point + Vector3(-5, 0, 0))
					)
				)
		var start = game.simulation_time
		while (
			not game.sites[index].cleared
			and not game.finished
			and game.simulation_time - start < 170
		):
			await _frames(30)
		await _stage_capture("air-corridor-battery-%d" % index, point)
		print(
			"AIR battery ",
			index,
			" cleared=",
			game.sites[index].cleared,
			" at ",
			game.simulation_time
		)
	_check(
		game.sites.all(func(site): return site.cleared), "Ground force did not clear both batteries"
	)
	if not game.sites.all(func(site): return site.cleared):
		return
	for unit in human.get_children():
		if (
			unit.is_in_group("units")
			and unit.movement_speed > 0
			and unit.type not in ["Worker", "Drone"]
		):
			unit.issue_manual_order(
				(
					attack_move.new(
						game.map.SCREEN + Vector3(unit.get_index() % 4, 0, unit.get_index() % 3 - 1)
					)
					if unit.attack_range != null
					else moving.new(game.map.SCREEN + Vector3(-4, 0, 0))
				)
			)
	var library = load("res://source/match/programs/ProgramLibrary.gd")
	for plane in _units(human, "Helicopter"):
		_check(
			plane.program.configure(library.defaults("strike_return")),
			"Strike-return preset rejected"
		)
		plane.program.anchor = game.map.SCREEN
		plane.program.safe_point = Vector3(14, 0, 62)
		plane.program.run()
	for repair in _units(human, "RepairRobot"):
		_check(
			repair.program.configure(library.defaults("hold_service")),
			"Service-area preset rejected"
		)
		repair.program.anchor = game.map.SCREEN + Vector3(-3, 0, 0)
		repair.program.run()
	await _frames(1800)
	for index in 3:
		if game.finished:
			break
		_check(await _launch_air(), "Commander could not launch next evacuation")
		var captured = false
		var start = game.simulation_time
		while (
			game.flights[index].state == "flying"
			and not game.finished
			and game.simulation_time - start < 100
		):
			if index == 0 and not captured and game.simulation_time - start >= 24:
				captured = true
				await _stage_capture("air-corridor-live-escort", game.map.SCREEN)
			await _frames(30)
		print("AIR flight ", index, " ", game.flights[index].state, " at ", game.simulation_time)
	if not game.finished:
		game.finish_evacuation()
	_check(game.finished and game.result == "Victory", "Combined-arms escort did not reach victory")
	print("AIR result ", game.result, " safe=", game.rescued(), " seconds=", game.simulation_time)


func _length(points):
	var distance = 0.0
	for index in range(1, points.size()):
		distance += points[index - 1].distance_to(points[index])
	return distance


func _migrate_progress():
	var progress = Progress.new()
	_check(progress.read_progress(path) and progress.air_complete, "Air victory not persisted")
	for version in [1, 2, 3]:
		var record = {"schema": version, "first_orders": true, "doctrine_badge": true}
		if version >= 2:
			record.merge({"split_signal": true, "network_badge": true})
		if version >= 3:
			record.supply_line = true
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(record))
		file.close()
		_check(progress.record_air_victory(true, path), "Legacy campaign migration failed")
		_check(
			(
				progress.read_progress(path)
				and progress.air_complete
				and progress.air_support
				and progress.complete
				and progress.doctrine_badge
			),
			"Campaign badge migration lost state"
		)
		_check(
			progress.network_badge == (version >= 2) and progress.supply_complete == (version == 3),
			"Legacy operation rewards changed"
		)


func _difficulty_and_limits():
	for mode in [0, 2]:
		difficulty = mode
		await _make_match()
		_check(game._enemy.population() == [7, 9, 11][mode], "Difficulty defender budget wrong")
		for site in game.sites:
			site.unit.hp = 0
		await _frames(5)
		var human = game._get_human_player()
		var added = []
		if mode == 0:
			for index in 100 - human.population():
				var unit = game._spawn(
					"Infantry", human, Vector3(7 + index % 8, 0, 92 + index / 8 * 0.7)
				)
				unit.process_mode = Node.PROCESS_MODE_DISABLED
				added.append(unit)
			_check(not game.launch_flight(), "Evacuation exceeded 100-unit limit")
			for unit in added:
				unit.queue_free()
			await _frames(5)
		_check(game.launch_flight(), "Difficulty launch failed")
		var before = game._enemy.population()
		paused = true
		game._check_outcome(10)
		_check(
			game._enemy.population() - before == [2, 3, 5][mode], "Difficulty response budget wrong"
		)
		game.flights[0].unit.issue_manual_order(null)
		_check(game.continue_flight(), "Held evacuation cannot resume")
		var repairing = load("res://source/match/units/actions/Repairing.gd")
		_check(
			not repairing.is_applicable(_units(human, "RepairRobot")[0], game.flights[0].unit),
			"Ground repair healed aircraft"
		)
		for unit in _units(human, "CommandCenter"):
			unit.hp = 0
		game._check_outcome(60.1)
		_check(game.finished and game.result == "Defeat", "HQ recovery deadline not enforced")
		await _close()
	difficulty = 1


func _exposed_flight():
	await _make_match()
	# Isolate the cost of launching without an escort after the static AA is gone.
	for site in game.sites:
		site.unit.hp = 0
	for unit in game._get_human_player().get_children():
		if unit.is_in_group("units") and unit.movement_speed > 0:
			unit.issue_manual_order(null)
			unit.position = Vector3(
				12 + unit.get_index() % 9 * 1.7, unit.position.y, 82 + unit.get_index() % 4 * 2
			)
	await _frames(10)
	_check(game.launch_flight(), "Unescorted exposure fixture cannot launch")
	var lowest = 150.0
	var start = game.simulation_time
	while game.flights[0].state == "flying" and game.simulation_time - start < 90:
		lowest = minf(lowest, game.flights[0].unit.hp)
		await _frames(15)
	_check(
		lowest < 150 or game.flights[0].state == "lost", "Unescorted route has no actual air threat"
	)
	print("AIR unescorted ", game.flights[0].state, " minimum HP=", lowest)
	await _close()


func _stage_capture(_title, _point):
	pass


func _launch_air():
	return game.launch_flight()
