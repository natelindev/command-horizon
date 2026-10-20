extends "res://tests/headless/CampaignRegression.gd"

var difficulty = 1
var moving
var attack_move


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "supply_line"
	settings.map_path = "res://source/match/maps/SupplyLineMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = difficulty
		settings.players.append(side)
	game = load("res://source/match/campaign/SupplyLine.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _run():
	path = "user://supply-progress-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	await _make_match()
	await _rules_archive()
	await _close()
	await _make_match()
	await _play()
	await _close()
	await _make_match()
	game.convoy[0].unit.hp = 0
	await _frames(3)
	_check(not game.finished, "One truck loss ended mission")
	game.convoy[1].unit.hp = 0
	await _frames(3)
	_check(game.finished and game.result == "Defeat", "Two truck losses did not cause defeat")
	await _close()
	for mode in [0, 2]:
		difficulty = mode
		await _make_match()
		_check(
			game._enemy.population() == [11, 14, 17][mode],
			"Difficulty changed wrong defender budget"
		)
		game.responses[0] = 0
		var before = game._enemy.population()
		game._send_response(0)
		_check(
			game._enemy.population() - before == [2, 3, 4][mode],
			"Difficulty changed wrong response budget"
		)
		await _close()
	await super._make_match()
	_check(
		game._get_human_player().resource_a == 100,
		"Supply completion did not grant First Orders starting support"
	)
	await _close()
	var progress = Progress.new()
	_check(
		progress.read_progress(path) and progress.supply_complete,
		"Convoy victory was not persisted"
	)
	_check(progress.record_victory(true, path), "Later campaign victory failed")
	_check(
		progress.supply_complete and progress.complete and progress.doctrine_badge,
		"Campaign progress erased previous reward"
	)
	_legacy_progress()
	DirAccess.remove_absolute(path)
	for error in errors:
		push_error(error)
	print("Supply Line: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _close():
	paused = false
	game.queue_free()
	await _frames(5)


func _rules_archive():
	_check(
		game.trucks().size() == 3 and not game._get_human_player().lab_research_unlocked(),
		"Conventional convoy setup failed"
	)
	_check(
		"Order advance" in game.hud._truck_labels[0].text,
		"Idle truck outside pad has no order hint"
	)
	var truck = game.convoy[0].unit
	_check(
		truck.attack_range == null,
		"Supply truck acquired a weapon"
	)
	truck.hp = 90
	var repair = game.escorts().filter(func(u): return u.type == "RepairRobot")[0]
	repair.position = truck.position + Vector3(5, 0, 0)
	var orders = load("res://source/match/orders/ManualOrders.gd")
	_check(
		repair.manual_orders.submit(orders.target_order("repair", truck)),
		"Truck repair order rejected"
	)
	var repair_started = game.simulation_time
	while truck.hp <= 90 and game.simulation_time - repair_started < 15:
		await _frames(15)
	_check(truck.hp > 90, "Supply truck cannot receive ordered repairs")
	# Reach a checkpoint in a controlled clear-area fixture, then archive a real
	# partially elapsed clearance and already-announced response.
	var defenders = game.battlefield.nearby_units(game.map.POINTS[0], 12).filter(
		func(u): return u.player == game._enemy
	)
	for defender in defenders:
		defender.position = Vector3(150, 0, 110)
		defender.issue_manual_order(null)
	truck.position = game.map.POINTS[0]
	await _frames(180)
	_check(game.convoy[0].clearance > 0, "Clear checkpoint did not advance clearance")
	_check(game.responses[0] > 0 and game.responses[0] < 10, "Checkpoint did not warn response")
	game.advance_convoy()
	paused = true
	var position_before = truck.position
	var clock_before = game.simulation_time
	await _frames(50)
	_check(
		truck.position == position_before and game.simulation_time == clock_before,
		"Paused convoy moved"
	)
	_check("Hold to clear" in game.hud._truck_labels[0].text, "Arrived truck has no stop hint")
	root.get_node("MatchSignals").deselect_all_units.emit()
	truck.get_node("Selection").select()
	await _frames(3)
	_check(game.find_child("UnitMenus")._title.text == "Supply truck", "Single truck menu failed")
	_check(game.find_child("UnitMenus")._buttons.is_empty(), "Truck exposes engineer construction")
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var saved = capture.capture(game)
	_check(saved != null, "Convoy capture failed: " + capture.error)
	if saved != null:
		var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
		_check(schema.validate(saved), "Convoy schema failed: " + schema.error)
		var bad = saved.duplicate(true)
		bad.mission.convoy[1].unit = bad.mission.convoy[0].unit
		_check(not schema.validate(bad), "Duplicate truck reference accepted")
		bad = saved.duplicate(true)
		bad.mission.responses[0] = 11
		_check(not schema.validate(bad), "Oversized response timer accepted")
		var store = load("res://source/match/saves/SaveFile.gd").new()
		var archive = "user://supply-archive-%d.json" % OS.get_process_id()
		_check(store.write_file(archive, saved), "Convoy archive file failed")
		saved = store.read_file(archive)
		DirAccess.remove_absolute(archive)
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var loaded = await restore.restore(self, saved)
		_check(loaded.ok, "Convoy restore failed: " + loaded.get("error", ""))
		if loaded.ok:
			game = loaded.game
			game.progress_path = path
			_check(
				game.trucks().size() == 3 and game.convoy[0].unit.position == position_before,
				"Loaded convoy lost identity or position"
			)
			var again = capture.capture(game)
			_check(again.mission == saved.mission, "Convoy state changed during restore")
	paused = false
	game.hold_convoy()
	var point = game.map.POINTS[0]
	game.convoy[0].unit.position = point
	var enemy = game._enemy.get_children().filter(func(u): return u.is_in_group("units"))[0]
	enemy.position = point + Vector3(0, 0, -4)
	enemy.issue_manual_order(null)
	# Fixture teleports occur after the spatial snapshot for this tick.
	game.battlefield.invalidate()
	var clearance = game.convoy[0].clearance
	await _frames(90)
	_check(game.convoy[0].clearance == clearance, "Enemy-contested checkpoint advanced clearance")
	# Deny an announced entry; it is consumed once and never silently retried.
	game.escorts()[0].position = game.map.ENTRIES[0]
	var before = game._enemy.population()
	game.responses[0] = 0
	game._send_response(0)
	_check(
		game.resolved[0] and game._enemy.population() == before,
		"Occupied response spawned over player"
	)
	enemy.position = Vector3(150, 0, 110)
	game.hold_convoy()
	await _frames(750)
	if game.convoy[0].leg != 1:
		print(
			"CLEARANCE leg=",
			game.convoy[0].leg,
			" seconds=",
			game.convoy[0].clearance,
			" position=",
			game.convoy[0].unit.position,
			" destination=",
			game.convoy[0].unit.get_node("Movement")._has_destination
		)
		for candidate in game.battlefield.nearby_units(point, 10):
			if candidate.player == game._enemy:
				print("CLEARANCE enemy=", candidate.type, " at=", candidate.position)
	_check(game.convoy[0].leg == 1, "Hold at a clear checkpoint did not complete clearance")


func _play():
	# Real manual commander: clear each checkpoint, bring trucks and support forward,
	# then issue the next leg. No health, money or enemy removals in this playthrough.
	for stage in 3:
		var destination = game.map.POINTS[stage]
		for unit in game.escorts():
			if unit.attack_range != null:
				unit.issue_manual_order(
					attack_move.new(destination + Vector3(unit.get_index() % 3, 0, 0))
				)
			else:
				unit.issue_manual_order(moving.new(destination + Vector3(-5, 0, 3)))
		var time = game.simulation_time
		while game.simulation_time - time < 150 and not game.finished:
			var defenders = game.battlefield.nearby_units(destination, 12).filter(
				func(u): return u.player == game._enemy
			)
			if defenders.is_empty():
				break
			await _frames(30)
		game.advance_convoy()
		time = game.simulation_time
		while game.simulation_time - time < 160 and not game.finished:
			# Stop individual arrivals well inside the pad, and explicitly recover
			# a straggler pushed outside it. These are test commander decisions,
			# not automatic convoy orders added to the mission.
			for index in game.convoy.size():
				var entry = game.convoy[index]
				if not game._alive(entry) or entry.leg > stage:
					continue
				var point = game.map.POINTS[entry.leg]
				var movement = entry.unit.get_node("Movement")
				var distance = entry.unit.position.distance_to(point)
				if distance <= 4.5 and movement._has_destination:
					entry.unit.issue_manual_order(null)
					movement.stop()
				elif distance > 7 and not movement._has_destination:
					entry.unit.issue_manual_order(
						moving.new(point + Vector3(0, 0, (index - 1) * 2))
					)
			if _stage_done(stage):
				break
			await _frames(30)
		print(
			"CONVOY stage ", stage, " at ", game.simulation_time, " trucks=", game.trucks().size()
		)
		if game.finished:
			break
	if not game.finished:
		for entry in game.convoy:
			print(
				"CONVOY unfinished leg=",
				entry.leg,
				" delivered=",
				entry.delivered,
				" clearance=",
				entry.clearance
			)
			if game._alive(entry):
				print(
					"CONVOY unfinished position=",
					entry.unit.position,
					" action=",
					entry.unit.action,
					" hp=",
					entry.unit.hp,
					" destination=",
					entry.unit.get_node("Movement").target_position,
					" travelling=",
					entry.unit.get_node("Movement")._has_destination
				)
	_check(game.finished and game.result == "Victory", "Conventional escort did not reach victory")
	print("CONVOY result ", game.result, " seconds=", game.simulation_time)


func _stage_done(stage):
	var count = 0
	for entry in game.convoy:
		if entry.delivered or (game._alive(entry) and entry.leg > stage):
			count += 1
	return count >= 2


func _legacy_progress():
	var legacy_path = path + ".legacy"
	for version in [1, 2]:
		var data = {"schema": version, "first_orders": true, "doctrine_badge": true}
		if version == 2:
			data.merge({"split_signal": true, "network_badge": true})
		var file = FileAccess.open(legacy_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var progress = Progress.new()
		_check(progress.record_supply_victory(legacy_path), "Legacy completion migration failed")
		_check(
			(
				progress.read_progress(legacy_path)
				and progress.supply_complete
				and progress.complete
				and progress.doctrine_badge
				and progress.split_complete == (version == 2)
				and progress.network_badge == (version == 2)
			),
			"Supply completion erased legacy badges"
		)
	DirAccess.remove_absolute(legacy_path)


func _frames(count):
	# Mission timers and movement advance on physics ticks, not render frames.
	for frame in count:
		await physics_frame
