extends "res://tests/headless/CommandHorizonRegression.gd"


func _run():
	path = "user://horizon-rules-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	await _make_match()
	await _turret_archive()
	await _close()
	await _make_match()
	await _objective_archive()
	await _close()
	await _budgets()
	await _routes(false)
	await _routes(true)
	_progress_migration()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Command Horizon rules: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _isolate():
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = (
				Vector3(14, 0, 103)
				if unit.player == game._get_human_player()
				else Vector3(175, 0, 100)
			)
	game.battlefield.invalidate()


func _turret_archive():
	_isolate()
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var aircraft = _units(human, "Helicopter")[0]
	var turret = _units(game._enemy, "AntiGroundTurret")[1]
	var aa = _units(game._enemy, "AntiAirTurret")[0]
	tank.position = turret.position + Vector3(-4, 0, 0)
	aircraft.position = aa.position + Vector3(-4, 2, 0)
	turret.process_mode = Node.PROCESS_MODE_INHERIT
	aa.process_mode = Node.PROCESS_MODE_INHERIT
	game.battlefield.invalidate()
	await _frames(20)
	_check(
		turret.action._sub_action != null and aa.action._sub_action != null,
		"Turrets did not acquire actual targets"
	)
	await _round_trip()
	human = game._get_human_player()
	tank = _units(human, "Tank")[0]
	aircraft = _units(human, "Helicopter")[0]
	var hp = [tank.hp, aircraft.hp]
	turret = _units(game._enemy, "AntiGroundTurret")[1]
	aa = _units(game._enemy, "AntiAirTurret")[0]
	turret.process_mode = Node.PROCESS_MODE_INHERIT
	aa.process_mode = Node.PROCESS_MODE_INHERIT
	var action = turret.action
	turret.action = moving.new(Vector3(100, 0, 100))
	_check(turret.action == action, "Archive fix allowed ordinary turret movement orders")
	await _frames(180)
	_check(tank.hp < hp[0] and aircraft.hp < hp[1], "Restored turrets failed to resume actual fire")


func _round_trip():
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Horizon capture failed: " + capture.error)
	if data == null:
		return
	var validator = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(validator.validate(data), "Horizon schema failed: " + validator.error)
	for change in [
		{"waves_sent": 5},
		{"deployed": true, "hold_seconds": 1.0},
		{"challenge": "invalid"},
		{"target_command": ""}
	]:
		var bad = data.duplicate(true)
		bad.mission.merge(change, true)
		if change.has("target_command") and data.mission.command_destroyed:
			bad.mission.target_command = (
				data
				. units
				. filter(
					func(unit): return unit.player == "player-0" and unit.role == "CommandCenter"
				)[0]
				. id
			)
		_check(not validator.validate(bad), "Invalid Horizon progression accepted: " + str(change))
	var file = load("res://source/match/saves/SaveFile.gd").new()
	_check(file.write_file(path + ".archive", data), "Horizon disk write failed: " + file.error)
	data = file.read_file(path + ".archive")
	DirAccess.remove_absolute(path + ".archive")
	var result = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
	_check(result.ok, "Horizon restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	game.progress_path = path
	var again = capture.capture(game)
	_check(
		again != null and again.mission == data.mission,
		"Horizon phase/route/timers changed on reload"
	)
	for saved in data.units:
		if saved.role in ["AntiAirTurret", "AntiGroundTurret"]:
			var restored = again.units.filter(func(unit): return unit.id == saved.id)[0]
			_check(restored.action == saved.action, "Turret discarded archived action or timer")
	_check(
		(
			game.map.alternate_route == data.mission.alternate_route
			and game.settings.campaign_challenge == data.mission.challenge
		),
		"Restoration changed route geometry/challenge"
	)
	await _frames(60)
	_check(capture.capture(game).mission == data.mission, "Paused mission advanced")
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false


func _objective_archive():
	_isolate()
	var human = game._get_human_player()
	_units(human, "Infantry")[0].position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(180)
	_check(
		game.map.relay.progress > 2 and not game.defence_started,
		"Deployment capture does not require ten seconds"
	)
	await _round_trip()
	human = game._get_human_player()
	var blocker = _units(game._enemy, "Tank")[0]
	blocker.position = game.map.DEPLOYMENT + Vector3(1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(2)
	var before = game.map.relay.progress
	await _frames(120)
	_check(
		game.map.relay.contested and game.map.relay.progress == before,
		"Ground combatant did not freeze capture"
	)
	blocker.position = Vector3(175, 0, 100)
	game.battlefield.invalidate()
	await _frames(660)
	_check(
		game.defence_started and game.hold_seconds > 0 and game.map.relay.captured_by == human,
		"Friendly capture did not start deployment/response clock"
	)
	var infantry = _units(human, "Infantry")[0]
	infantry.position = Vector3(14, 0, 103)
	game.battlefield.invalidate()
	await _frames(2)
	before = game.hold_seconds
	await _frames(120)
	_check(game.hold_seconds == before, "Empty owned deployment gained hold time")
	await _round_trip()
	human = game._get_human_player()
	infantry = _units(human, "Infantry")[0]
	infantry.position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(1800)
	_check(
		game.deployed and game.hold_seconds == 30 and not game.finished,
		"Deployment did not unlock HQ assault"
	)
	infantry.position = Vector3(14, 0, 103)
	game.battlefield.invalidate()
	game.target_command.hp = 0
	await _frames(2)
	_check(
		game.command_destroyed and not game.finished,
		"HQ destruction won without deployment infantry"
	)
	await _round_trip()
	human = game._get_human_player()
	_units(human, "Infantry")[0].position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(2)
	_check(not game.finished, "Returning infantry completed the finale without Aegis")
	game.campaign_hero.unit.position = game.map.TARGET + Vector3(-6, 0, 0)
	game.battlefield.invalidate()
	await _frames(2)
	_check(not game.finished, "Aegis bypassed the living siege commander")
	game.opposition.boss.hp = 0
	game.opposition._step_boss(0)
	await _frames(2)
	_check(
		game.finished and game.result == "Victory", "Aegis at the controls did not complete finale"
	)
	var progress = Progress.new()
	_check(
		(
			progress.read_progress(path)
			and progress.horizon_complete
			and not progress.campaign_finished()
		),
		"Finale progress falsely completed every mission"
	)


func _budgets():
	for mode in [0, 1, 2]:
		for variant in ["", "lean", "reinforced"]:
			difficulty = mode
			challenge = variant
			await _make_match()
			paused = true
			var human = game._get_human_player()
			_check(
				_units(human, "Tank").size() == (4 if variant == "lean" else 8),
				"Challenge tank budget wrong"
			)
			_check(
				_units(human, "Worker").size() == (2 if variant == "lean" else 4),
				"Challenge economy budget wrong"
			)
			_check(
				(
					human.coordination_unlocked
					and _units(human, "CombatRobot").size() == 4
					and _units(human, "Helicopter").size() == 2
				),
				"Challenge removed required counters"
			)
			if mode == 1 and variant != "":
				await _round_trip()
				paused = true
			var count = game._enemy.population()
			for index in 6:
				game._send_wave()
			var budget = [2, 3, 4][mode] + [1, 1, 2][mode] + (1 if variant == "reinforced" else 0)
			_check(
				game.waves_sent == 4 and game._enemy.population() == count + 4 * budget,
				"Response budget was wrong or unbounded"
			)
			await _close()
	challenge = ""
	difficulty = 1
	await _make_match()
	paused = true
	var human = game._get_human_player()
	for index in 2:
		_units(human, "Tank")[index].position = game.map.ENTRIES[index]
	var count = game._enemy.population()
	game._send_wave()
	_check(
		game.waves_sent == 1 and game._enemy.population() == count,
		"Occupied response entries spawned into friendly units"
	)
	_units(human, "CommandCenter")[0].hp = 0
	game._check_outcome(59)
	_check(not game.finished, "HQ recovery ended prematurely")
	game._check_outcome(1.1)
	_check(
		game.finished and game.result == "Defeat", "Missing HQ did not defeat after recovery window"
	)
	await _close()


func _routes(alternate):
	DirAccess.remove_absolute(path)
	if alternate:
		Progress.new().record_foundry_victory(path)
	await _make_match()
	_check(game.alternate_route == alternate, "Foundry progress did not select map route")
	var nav = game.navigation.get_navigation_map_rid_by_domain(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	var north_path = NavigationServer3D.map_get_path(
		nav, game.map.NORTH + Vector3(-15, 0, 0), game.map.NORTH + Vector3(15, 0, 0), true
	)
	var length = 0.0
	for index in range(1, north_path.size()):
		length += north_path[index - 1].distance_to(north_path[index])
	_check(
		north_path.size() > 1 and (length < 40 if alternate else length > 140),
		"North reward did not replace the long south detour"
	)
	_isolate()
	var unit = _units(game._get_human_player(), "Tank")[0]
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	var pass_point = game.map.NORTH if alternate else game.map.SOUTH
	unit.position = pass_point + Vector3(-15, 0, 0)
	var goal = pass_point + Vector3(15, 0, 0)
	unit.issue_manual_order(moving.new(goal))
	var start = game.simulation_time
	while unit.position.distance_to(goal) > 2 and game.simulation_time - start < 30:
		await _frames(15)
	_check(
		unit.position.distance_to(goal) < 2, "Actual tank could not traverse rewarded/default pass"
	)
	await _round_trip()
	await _close()


func _progress_migration():
	for version in range(1, 6):
		var data = {"schema": version, "first_orders": true, "doctrine_badge": true}
		if version >= 2:
			data.merge({"split_signal": true, "network_badge": true})
		if version >= 3:
			data.supply_line = true
		if version >= 4:
			data.merge({"air_corridor": true, "air_support": true})
		if version >= 5:
			data.broken_foundry = true
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var progress = Progress.new()
		_check(progress.record_horizon_victory("lean", path), "Legacy finale migration failed")
		_check(
			(
				progress.complete
				and progress.doctrine_badge
				and progress.horizon_complete
				and progress.lean_complete
			),
			"Legacy completion lost on finale write"
		)
		_check(
			(
				progress.record_horizon_victory("reinforced", path)
				and progress.lean_complete
				and progress.reinforced_complete
			),
			"Challenge write erased previous completion"
		)
		_check(progress.campaign_finished() == (version == 5), "Campaign completion count wrong")
