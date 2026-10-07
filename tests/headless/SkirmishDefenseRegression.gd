extends "res://tests/headless/SaveRestoreEdges.gd"

var defenders = []
var worker
var raider
var opponent
var attack_move
var counter


func _run():
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
		opponent.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		worker = _actor("Worker", opponent, Vector3(82, 0, 10))
		worker.process_mode = Node.PROCESS_MODE_DISABLED
		raider = _actor("Tank", human, Vector3(85, 0, 10))
		raider.process_mode = Node.PROCESS_MODE_DISABLED
		defenders = [
			_actor("Tank", opponent, Vector3(68, 0, 10)),
			_actor("Tank", opponent, Vector3(68, 0, 13))
		]
		await _frames(20)
		game.battlefield.invalidate()
		_check(game.battlefield.is_observed(opponent, raider), "Defense fixture raid is hidden")
		opponent._last_wave = game.simulation_time
		await _hidden_and_stable_orders()
		var waves = opponent.attacks_launched
		opponent._command_army(defenders + [worker])
		await _frames(60)
		for unit in defenders:
			_check(is_instance_of(unit.action, attack_move), "AI ignored inter-wave economy raid")
		_check(opponent.attacks_launched == waves, "Defense consumed scheduled attack wave")
		var hp = raider.hp
		var response_started = game.simulation_time
		while (
			is_instance_valid(raider)
			and raider.hp >= hp
			and game.simulation_time - response_started < 10.0
		):
			await physics_frame
		_check(not is_instance_valid(raider) or raider.hp < hp, "AI response never damaged raider")
		print(
			"DEFENSE ",
			opponent.faction,
			" waves=",
			opponent.attacks_launched - waves,
			" response_seconds=",
			game.simulation_time - response_started
		)
		await _review("ground-response")
		await _air_response()
		game.queue_free()
		await _frames(5)
		await _multiple_fronts(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish defense: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _hidden_and_stable_orders():
	var sight = worker.sight_range
	worker.sight_range = 0
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(opponent, raider), "Hidden raid fixture remains visible"
	)
	var actions = defenders.map(func(unit): return unit.action)
	opponent._command_army(defenders + [worker])
	for index in defenders.size():
		_check(defenders[index].action == actions[index], "AI reacted to hidden raid")
	worker.sight_range = sight
	game.battlefield.invalidate()
	var funds = Vector2(opponent.resource_a, opponent.resource_b)
	opponent._command_army(defenders + [worker])
	actions = defenders.map(func(unit): return unit.action)
	opponent._command_army(defenders + [worker])
	for index in defenders.size():
		_check(defenders[index].action == actions[index], "AI restarted unchanged defense order")
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds,
		"Defense command spent resources"
	)
	# Losing observation may release the task, but cannot target the unseen new position.
	worker.sight_range = 0
	raider.position += Vector3(0, 0, 1)
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(opponent, raider), "Lost-contact fixture remains visible"
	)
	opponent._command_army(defenders + [worker])
	for index in defenders.size():
		if is_instance_of(defenders[index].action, attack_move):
			_check(
				defenders[index].action.destination == Vector3(85, 0, 10),
				"Lost contact changed destination"
			)
	_check(
		opponent._army_groups.all(func(group): return group.kind != "defense"),
		"Hidden raid retained a coordinated response"
	)
	worker.sight_range = sight
	raider.position = Vector3(85, 0, 10)
	game.battlefield.invalidate()
	print("PASS: hidden/lost contacts, stable orders and no defense spending")


func _air_response():
	if is_instance_valid(raider):
		raider.queue_free()
	for index in defenders.size():
		defenders[index].issue_manual_order(null)
		defenders[index].position = Vector3(68, 0, 10 + index * 3)
	var scout = _actor("Drone", game._get_human_player(), Vector3(85, 2, 10))
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(20)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, scout), "Unarmed scout fixture is hidden")
	var held = defenders.map(func(unit): return unit.action)
	opponent._command_army(defenders + [worker])
	for index in defenders.size():
		_check(defenders[index].action == held[index], "Unarmed scout recalled economy defenders")
	scout.queue_free()
	await _frames(5)
	raider = _actor("Helicopter", game._get_human_player(), Vector3(85, 2, 10))
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	counter = _actor("CombatRobot", opponent, Vector3(68, 0, 16))
	await _frames(20)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, raider), "Air raid fixture is hidden")
	var actions = defenders.map(func(unit): return unit.action)
	opponent._command_army(defenders + [worker, counter])
	_check(is_instance_of(counter.action, attack_move), "AI did not send an air-capable defender")
	for index in defenders.size():
		_check(defenders[index].action == actions[index], "Ground-only tank chased air raid")
	if opponent.faction == "helix":
		_check(
			counter.pending_weapon_mode == "interception", "Lancer did not prepare anti-air mode"
		)
	await _frames(30)
	await _archive_response()
	var hp = raider.hp
	await _frames(420)
	await _review("air-response")
	await _frames(420)
	_check(not is_instance_valid(raider) or raider.hp < hp, "Restored air defense never fired")
	print("PASS: suitable air counter, partial switch archive and actual interception")


func _archive_response():
	game.hud._toggle_pause()
	var clock = game.simulation_time
	var point = counter.position
	var switch_left = counter.weapon_switch_left
	var wave_age = clock - opponent._last_wave
	await _frames(30)
	_check(
		counter.position == point and counter.weapon_switch_left == switch_left,
		"Paused AI defense advanced"
	)
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "AI defense snapshot failed")
	if snapshot == null:
		return
	var actors = defenders + [worker, raider, counter]
	var ids = actors.map(func(unit): return builder._reference(unit))
	var store = FileStore.new()
	var archive_path = "user://ai-defense-%d.json" % OS.get_process_id()
	_check(store.write_file(archive_path, snapshot), "AI defense archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(archive_path))
	DirAccess.remove_absolute(archive_path)
	_check(loaded.ok, "AI defense restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	defenders = [restore.entities[ids[0]], restore.entities[ids[1]]]
	worker = restore.entities[ids[2]]
	raider = restore.entities[ids[3]]
	counter = restore.entities[ids[4]]
	opponent = counter.player
	opponent.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit != counter:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(paused and game.simulation_time == clock, "AI defense restore lost paused clock")
	_check(
		counter.position == point and counter.weapon_switch_left == switch_left,
		"AI defense restore changed response"
	)
	_check(
		is_equal_approx(clock - opponent._last_wave, wave_age),
		"AI defense restore reset attack timer"
	)
	_check(
		is_instance_of(counter.action, attack_move), "AI defense restore lost interception order"
	)
	var action = counter.action
	opponent._command_army(defenders + [worker, counter])
	_check(counter.action == action, "AI replaced restored matching response")
	game.hud._toggle_pause()
	print("PASS: paused response disk archive and unchanged wave timing")


func _multiple_fronts(faction):
	await _skirmish(faction, "res://source/match/maps/AlpineRelay.tscn")
	var human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	opponent.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var actors = []
	var contacts = []
	for index in 3:
		var point = Vector3(30 + index * 30, 0, 16)
		var engineer = _actor("Worker", opponent, point)
		var attacker = _actor("Tank", human, point + Vector3(3, 0, 0))
		contacts.append(attacker)
		actors.append(engineer)
		for offset in 2:
			actors.append(_actor("Tank", opponent, point - Vector3(6, 0, offset * 3)))
		attacker.process_mode = Node.PROCESS_MODE_DISABLED
	for unit in actors:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	game.battlefield.invalidate()
	var planner = load("res://source/match/players/skirmish-ai/SkirmishDefense.gd")
	for difficulty in 3:
		opponent.difficulty = difficulty
		var plan = planner.plan(game, opponent, actors, contacts)
		_check(
			plan.assignments.size() == 2 * (difficulty + 1),
			"AI defense group count ignores difficulty"
		)
		var unique = []
		for assignment in plan.assignments:
			_check(assignment.unit not in unique, "AI assigned defender to two raids")
			unique.append(assignment.unit)
	# A raid the current army cannot counter must not consume its coordination slot.
	var unsupported = _actor("Helicopter", human, actors[0].global_position_yless + Vector3.UP * 2)
	var previous_damage = actors[0].last_enemy_damage_time
	actors[0].last_enemy_damage_time = game.simulation_time
	unsupported.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	game.battlefield.invalidate()
	opponent.difficulty = 0
	var answerable = planner.plan(game, opponent, actors, contacts + [unsupported])
	_check(
		not answerable.threats.is_empty() and answerable.threats[0] == unsupported,
		"Unsupported air raid is not the highest-priority threat"
	)
	_check(answerable.assignments.size() == 2, "Unanswerable air raid suppressed ground defense")
	for assignment in answerable.assignments:
		_check(
			assignment.target != unsupported, "Ground-only defense assigned unsupported air target"
		)
	actors[0].last_enemy_damage_time = previous_damage
	unsupported.queue_free()
	await _frames(5)
	opponent.difficulty = 1
	# Non-defending soldiers can still launch a scheduled offensive wave.
	var reserves = []
	for index in 4:
		var tank = _actor("Tank", opponent, Vector3(12, 0, 70 + index * 2))
		tank.process_mode = Node.PROCESS_MODE_DISABLED
		reserves.append(tank)
	await _frames(20)
	game.simulation_time = 240
	opponent._last_wave = 0
	var waves = opponent.attacks_launched
	opponent._command_army(actors + reserves)
	_check(
		opponent.attacks_launched == waves, "Two defensive fronts exceeded Normal's global budget"
	)
	_check(
		(
			opponent._army_groups.size() == 2
			and opponent._army_groups.all(func(group): return group.kind == "defense")
		),
		"Normal did not reserve both groups for supported raids"
	)
	for unit in reserves:
		_check(
			not is_instance_of(unit.action, attack_move),
			"Unassigned reserve retained an extra assault"
		)
	# With only one threatened asset in the command roster, the second group can attack.
	opponent._command_army(actors.slice(0, 3) + reserves)
	_check(
		opponent.attacks_launched == waves + 1, "One raid prevented the available offensive group"
	)
	var enemy_start = game.map.find_child("SpawnPoints").get_child(0).position
	for unit in reserves:
		_check(is_instance_of(unit.action, attack_move), "Unassigned reserve missed attack wave")
		if is_instance_of(unit.action, attack_move):
			_check(
				unit.action.destination.distance_to(enemy_start) < 12,
				"Whole army diverted to local raid"
			)
			_check(
				contacts.all(
					# The observed enemy economy is near this staged raid. Distinguish
					# its objective from the raid point plus the wave's formation offset.
					func(contact): return unit.action.destination.distance_to(contact.position) > 4
				),
				"Offensive reserve joined a local defense group"
			)
	var previous_positions = contacts.map(func(unit): return unit.position)
	for index in contacts.size():
		contacts[index].position = Vector3(33, 0, 16 + index)
	var extra = _actor("Tank", human, Vector3(33, 0, 19))
	extra.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	game.battlefield.invalidate()
	var crowded = planner.plan(game, opponent, actors + reserves, contacts + [extra])
	_check(crowded.assignments.size() == 6, "Large raid took more than six responders")
	for index in contacts.size():
		contacts[index].position = previous_positions[index]
	extra.queue_free()
	await _frames(5)
	# Relay orders must not overwrite an infantry defense assignment.
	var infantry = []
	for index in 4:
		var point = Vector3(26, 0, 14 + index * 2) if index < 2 else Vector3(12, 0, 80 + index)
		var unit = _actor("Infantry", opponent, point)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		infantry.append(unit)
	await _frames(10)
	opponent._last_wave = game.simulation_time
	opponent._command_army([actors[0]] + infantry)
	for unit in infantry.slice(0, 2):
		_check(is_instance_of(unit.action, attack_move), "Infantry failed economy response")
		if is_instance_of(unit.action, attack_move):
			_check(
				unit.action.destination.distance_to(contacts[0].position) < 1,
				"Relay task stole defender"
			)
	for unit in infantry.slice(2):
		_check(is_instance_of(unit.action, attack_move), "Spare infantry did not capture relay")
		if is_instance_of(unit.action, attack_move):
			_check(
				game.map.relays.any(
					func(relay): return unit.action.destination.distance_to(relay.position) < 3
				),
				"Spare infantry lost relay objective"
			)
	print("PASS: one/two/three defense groups, separate attack wave and relay duties")
	game.queue_free()
	await _frames(5)


func _review(_label):
	pass
