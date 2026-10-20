extends "res://tests/headless/SupplyLineRegression.gd"

var reserve = []


func _initialize():
	create_timer(1400).timeout.connect(func(): push_error("Foundry regression timeout"); quit(1))
	_run.call_deferred()


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "broken_foundry"
	settings.map_path = "res://source/match/maps/BrokenFoundryMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = difficulty
		settings.players.append(side)
	game = load("res://source/match/campaign/BrokenFoundry.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _run():
	path = "user://foundry-progress-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	if "--play-only" in OS.get_cmdline_user_args():
		await _make_match()
		await _play_foundry()
		await _close()
		DirAccess.remove_absolute(path)
		for message in errors:
			push_error(message)
		print("Foundry focused playthrough: %d failures" % errors.size())
		quit(0 if errors.is_empty() else 1)
		return
	await _make_match()
	await _geometry_support()
	await _close()
	await _make_match()
	await _production_archive()
	await _close()
	await _make_match()
	await _capture_rules_foundry()
	await _close()
	await _make_match()
	await _play_foundry()
	await _close()
	await _difficulty_budgets()
	await _rewards()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Broken Foundry: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _geometry_support():
	var human = game._get_human_player()
	var artillery = _units(game._enemy, "AdvancedTank")[0]
	for unit in game._enemy.get_children():
		if unit.is_in_group("units") and unit != artillery:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var infantry = _units(human, "Infantry")[0]
	var original_point = infantry.position
	infantry.process_mode = Node.PROCESS_MODE_DISABLED
	infantry.position = game.map.CONTROL + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	var infantry_hp = infantry.hp
	await _frames(360)
	_check(not is_instance_valid(infantry) or infantry.hp < infantry_hp, "Foundry artillery does not threaten control yard")
	_check(artillery.stance == artillery.Stance.HOLD_POSITION and artillery.global_position_yless.distance_to(game.map.CONTROL) <= 12, "Artillery post excludes its defended objective")
	if is_instance_valid(infantry):
		infantry.position = original_point
		infantry.process_mode = Node.PROCESS_MODE_INHERIT
	for unit in game._enemy.get_children():
		if unit.is_in_group("units") and unit.movement_speed > 0:
			unit.issue_manual_order(null)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.position = Vector3(150, 0, 108)
	var a = Vector3(44, 0, 43)
	var b = Vector3(66, 0, 43)
	var route = NavigationServer3D.map_get_path(game.navigation.get_navigation_map_rid_by_domain(1), a, b, true)
	var distance = 0.0
	for index in range(1, route.size()):
		distance += route[index - 1].distance_to(route[index])
	_check(distance > a.distance_to(b) + 5, "Warehouse does not change ground path")
	_check(not game.battlefield.line_clear(a + Vector3.UP, b + Vector3.UP), "Warehouse does not block shots/sight")
	_check(game.battlefield.line_clear(Vector3(44, 1, 58), Vector3(66, 1, 58)), "Central street sightline is closed")
	var tank = _units(human, "Tank")[0]
	tank.position = a
	tank.issue_manual_order(moving.new(b))
	var start = game.simulation_time
	while tank.position.distance_to(b) > 2 and game.simulation_time - start < 35:
		await _frames(15)
	_check(tank.position.distance_to(b) < 2, "Tank cannot traverse warehouse bypass")
	# A guard engages a visible target inside its area, then stops pursuing outside it.
	tank.issue_manual_order(null)
	tank.position = Vector3(68, 0, 58)
	var target = _units(game._enemy, "Tank")[0]
	target.position = Vector3(73, 0, 58)
	load("res://source/match/campaign/CampaignPosts.gd").guard(tank, Vector3(68, 0, 58))
	game.battlefield.invalidate()
	var hp = target.hp
	await _frames(180)
	_check(target.hp < hp, "Guard failed to engage visible street target")
	target.position = Vector3(85, 0, 58)
	game.battlefield.invalidate()
	await _frames(360)
	_check(tank.position.distance_to(Vector3(68, 0, 58)) <= 8, "Guard pursued outside its assignment")
	# Ordinary mobile support actually repairs damaged armor in the service area.
	tank.issue_manual_order(null)
	tank.position = Vector3(39, 0, 58)
	tank.hp = tank.hp_max * 0.4
	var repairs = _units(human, "RepairRobot")
	for repair in repairs:
		repair.issue_manual_order(null)
		repair.position = tank.position + Vector3(1.4, 0, 0)
	var damaged = tank.hp
	tank.last_enemy_damage_time = -100
	var repair_started = game.simulation_time
	await _frames(120)
	var recovered = tank.hp - damaged
	var single_channel_limit = (
		tank.hp_max * 0.025 * (game.simulation_time - repair_started + 0.25)
	)
	_check(
		recovered > 0 and recovered <= single_channel_limit,
		"Mobile repair failed or stacked channels"
	)


func _difficulty_budgets():
	for mode in [0, 2]:
		difficulty = mode
		await _make_match()
		paused = true
		game.alarm = true
		game._check_outcome(10.1)
		for node in game.nodes:
			_check(node.unit.get_node("ProductionQueue").size() == [1, 2, 3][mode], "Difficulty batch budget wrong")
			node.unit.hp = 0
		game._check_outcome(0)
		var count = game._enemy.population()
		game._check_outcome(10.1)
		_check(game._enemy.population() == count + [3, 5, 7][mode], "Final response budget wrong")
		game._send_response()
		_check(game._enemy.population() == count + [3, 5, 7][mode], "Final response repeated")
		await _close()
	difficulty = 1


func _production_archive():
	_check(game.nodes.size() == 2 and not game.production_disabled(), "Production nodes missing")
	var human = game._get_human_player()
	var scout = _units(human, "Drone")[0]
	scout.position.x = 47
	await _frames(2)
	_check(game.alarm, "District entry did not start alarm")
	scout.position.x = 35
	await _frames(720)
	for entry in game.nodes:
		_check(entry.batches == 1 and entry.unit.get_node("ProductionQueue").size() == 2, "First paid batch missing")
	_check(game._enemy.resource_a < 600, "Production did not spend finite materials")
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Foundry capture failed: " + capture.error)
	if data == null:
		return
	var validator = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(validator.validate(data), "Foundry schema failed: " + validator.error)
	var bad = data.duplicate(true)
	bad.mission.nodes[1].unit = bad.mission.nodes[0].unit
	_check(not validator.validate(bad), "Duplicate production node accepted")
	bad = data.duplicate(true)
	bad.mission.nodes[0].batches = 4
	_check(not validator.validate(bad), "Unbounded production accepted")
	bad = data.duplicate(true)
	bad.mission.relay.owner = "player-0"
	_check(not validator.validate(bad), "Premature capture accepted")
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var archive = path + ".archive"
	_check(store.write_file(archive, data), "Foundry archive write failed")
	data = store.read_file(archive)
	DirAccess.remove_absolute(archive)
	var result = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
	_check(result.ok, "Foundry archive restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	game.progress_path = path
	var again = capture.capture(game)
	_check(again != null and again.mission == data.mission, "Paused archive changed production/capture state")
	for old in data.units:
		if old.role == "VehicleFactory":
			var renewed = again.units.filter(func(unit): return unit.id == old.id)[0]
			_check(renewed.production == old.production, "Paid jobs/chips changed on reload")
	var entry = game.nodes[0]
	var pending = entry.unit.get_node("ProductionQueue").get_elements()[0].time_left
	await _frames(60)
	_check(entry.unit.get_node("ProductionQueue").get_elements()[0].time_left == pending, "Paused factory produced")
	var tanks = _units(game._enemy, "Tank").size()
	var surviving_queue = game.nodes[1].unit.get_node("ProductionQueue")
	var first_batch = surviving_queue.get_elements().duplicate()
	entry.unit.hp = 0
	paused = false
	await _frames(2)
	_check(entry.disabled and entry.unit == null, "Destroyed production node stayed active")
	# Wait for the jobs restored above, before later scheduled batches finish.
	# _frames now counts physics ticks; a fixed 3300 ticks spans 110 seconds.
	var batch_wait_started = game.simulation_time
	while (
		first_batch.any(func(job): return job in surviving_queue.get_elements())
		and game.simulation_time - batch_wait_started < 120
	):
		await _frames(1)
	_check(_units(game._enemy, "Tank").size() == tanks + 2, "Destroyed factory completed paid units or surviving factory failed")
	var start = game.simulation_time
	while game.nodes[1].batches < 3 and game.simulation_time - start < 120:
		await _frames(30)
	await _frames(3600)
	_check(game.nodes[1].batches == 3, "Finite production budget incomplete")
	var count = _units(game._enemy, "Tank").size()
	await _frames(3600)
	_check(count == _units(game._enemy, "Tank").size(), "Production continued beyond three batches")
	_check(count == tanks + 6, "Standard node did not finish six actual tanks")
	for unit in _units(game._enemy, "Tank"):
		_check(unit.stance == unit.Stance.HOLD_POSITION, "Factory output lacks a guard post")


func _capture_rules_foundry():
	var human = game._get_human_player()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = Vector3(10 + unit.get_index() % 10, 0, 103) if unit.player == human else Vector3(151, 0, 105)
	var infantry = _units(human, "Infantry")[0]
	infantry.position = game.map.CONTROL + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(660)
	_check(game.map.relay.progress == 0 and game.map.relay.captured_by == null, "Control captured before nodes disabled")
	for entry in game.nodes:
		entry.unit.hp = 0
	await _frames(120)
	_check(game.production_disabled() and game.response_left > 0, "Production destruction did not unlock control/warn response")
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null and data.mission.relay.progress > 0, "Partial capture did not save")
	if data != null:
		var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
		_check(restored.ok, "Partial control restore failed: " + restored.get("error", ""))
		if restored.ok:
			game = restored.game
			game.progress_path = path
			_check(capture.capture(game).mission == data.mission, "Capture/response changed on reload")
			human = game._get_human_player()
			for unit in get_nodes_in_group("units"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
	# A tank contests infantry; accumulated capture is frozen, not reset.
	var blocker = _units(game._enemy, "Tank")[0]
	blocker.position = game.map.CONTROL + Vector3(0, 0, 1.6)
	game.battlefield.invalidate()
	paused = false
	await _frames(2)
	var before = game.map.relay.progress
	await _frames(120)
	_check(game.map.relay.contested and game.map.relay.progress == before, "Enemy tank did not contest foundry")
	blocker.position = Vector3(151, 0, 105)
	# Deny the final response with an explicit friendly position at its public entry.
	_units(human, "Tank")[0].position = game.map.ENTRY
	game.battlefield.invalidate()
	await _frames(600)
	_check(game.response_done and game.map.relay.captured_by == human, "Foundry capture/final entry denial failed")
	var hold = game.hold_seconds
	var active_infantry = _units(human, "Infantry").filter(func(unit): return unit.position.distance_to(game.map.CONTROL) < 4)[0]
	active_infantry.position = Vector3(10, 0, 103)
	game.battlefield.invalidate()
	await _frames(120)
	_check(game.hold_seconds <= hold + 0.1, "Remote capture accrued hold without infantry")
	paused = true
	data = capture.capture(game)
	_check(data != null and data.mission.hold_seconds > 0, "Secured time did not save")
	if data != null:
		var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(self, data)
		_check(restored.ok, "Owned foundry archive failed: " + restored.get("error", ""))
		if restored.ok:
			game = restored.game
			game.progress_path = path
			human = game._get_human_player()
			_check(capture.capture(game).mission == data.mission, "Secured time/response replayed on load")
	for hq in _units(human, "CommandCenter"):
		hq.hp = 0
	game._check_outcome(60.1)
	_check(game.finished and game.result == "Defeat", "Foundry HQ loss did not defeat")


func _play_foundry():
	var human = game._get_human_player()
	reserve = _units(human, "Infantry").slice(0, 2)
	for unit in reserve:
		unit.issue_manual_order(null)
	for index in 2:
		var point = game.map.NODES[index]
		_order_army(point + Vector3(-4, 0, 0))
		var start = game.simulation_time
		while not game.nodes[index].disabled and not game.finished and game.simulation_time - start < 180:
			await _frames(30)
		print("FOUNDRY node ", index, " disabled=", game.nodes[index].disabled, " time=", game.simulation_time, " army=", human.population())
		await _stage_capture("foundry-node-%d" % index, point)
	_check(game.production_disabled(), "Army did not disable both production nodes in combat")
	if not game.production_disabled():
		return
	_order_army(game.map.CONTROL)
	# Paid capturer replacements and a small reserve keep infantry behind the armor.
	var queue = _units(human, "Barracks")[0].get_node("ProductionQueue")
	var materials = human.resource_a
	for index in 4:
		_check(queue.produce(load("res://source/match/units/Infantry.tscn")) != null, "Could not buy capture reinforcements")
	_check(human.resource_a == materials - 24, "Capture reinforcements were not paid")
	var start = game.simulation_time
	while not game.finished and game.simulation_time - start < 240:
		if int(game.simulation_time - start) % 15 == 0:
			var clear = not game.battlefield.observed_enemies_near(_units(human, "Drone")[0], 200).any(
				func(unit): return unit.attack_range != null and unit.global_position_yless.distance_to(game.map.CONTROL) < 12
			)
			for unit in _units(human, "Infantry"):
				if unit not in reserve or clear or game.simulation_time - start > 60:
					unit.issue_manual_order(attack_move.new(game.map.CONTROL + Vector3(-1.6, 0, 0)))
		await _frames(60)
	_check(game.finished and game.result == "Victory", "Urban combat/capture did not win")
	print("FOUNDRY result ", game.result, " seconds=", game.simulation_time, " survivors=", human.population())
	for side in [human, game._enemy]:
		var counts = {}
		for unit in side.get_children():
			if unit.is_in_group("units") and game._alive(unit):
				counts[unit.type] = counts.get(unit.type, 0) + 1
		print("FOUNDRY survivors ", side.faction, " ", counts)
	print("FOUNDRY control ", game.map.relay.progress, " hold ", game.hold_seconds, " contested ", game.map.relay.contested)
	await _stage_capture("foundry-live-result", game.map.CONTROL)


func _order_army(point):
	for unit in game._get_human_player().get_children():
		if not unit.is_in_group("units") or unit.movement_speed <= 0 or unit.type in ["Worker", "Drone"] or unit in reserve:
			continue
		if unit.type == "RepairRobot":
			load("res://source/match/orders/UnitBehavior.gd").guard(unit, point + Vector3(-5, 0, 0))
		else:
			unit.issue_manual_order(attack_move.new(point + Vector3(unit.get_index() % 3, 0, 0)))


func _rewards():
	var progress = Progress.new()
	_check(progress.read_progress(path) and progress.foundry_complete, "Foundry completion not saved")
	_check(
		progress.record_operation("bastion_cinder_ford", path), "Cinder Ford result could not be written"
	)
	await _make_match()
	_check(
		game._get_human_player().resource_b == 100, "Cinder Ford support did not grant +20 electronics"
	)
	await _close()
	for version in [1, 2, 3, 4]:
		var data = {"schema": version, "first_orders": true, "doctrine_badge": true}
		if version >= 2:
			data.merge({"split_signal": true, "network_badge": true})
		if version >= 3:
			data.supply_line = true
		if version >= 4:
			data.merge({"air_corridor": true, "air_support": true})
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		_check(progress.record_foundry_victory(path), "Foundry legacy migration failed")
		_check(progress.foundry_complete and progress.complete and progress.doctrine_badge and progress.air_support == (version == 4), "Foundry migration lost completion/badges")


func _stage_capture(_title, _point):
	pass
