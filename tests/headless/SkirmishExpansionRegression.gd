extends "res://tests/headless/SaveRestoreEdges.gd"

var harvest
var attack_move
var moving
var catalog
var economy


func _run():
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for map_name in ["DesertFrontier", "AlpineRelay"]:
			await _expansion(faction, map_name)
		await _threat_contract(faction)
		await _split_fields(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish expansion: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _expansion(faction, map_name):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/%s.tscn" % map_name,
		true
	)
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan_owned(human):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	game.simulation_time = 200
	opponent._last_wave = 200
	var hq = _units(opponent, "CommandCenter")[0]
	var workers = _units(opponent, "Worker")
	for deposit in get_nodes_in_group("resource_units"):
		if "resource_b" in deposit and deposit.position.distance_to(hq.position) <= 30:
			deposit.queue_free()
	await _frames(3)
	var field = _nearest_deposit(hq, "resource_b")
	_check(
		field.position.distance_to(hq.position) > 30,
		"Expansion fixture did not exhaust home electronics"
	)
	for index in workers.size():
		workers[index].issue_manual_order(
			null if index == 2 else harvest.new(_nearest_deposit(hq, "resource_a"))
		)
	opponent._harvest(opponent._units())
	_check(workers[2].action == null, faction + ": unguarded engineer entered expansion")
	opponent._command_army(opponent._units())
	var guards = opponent._units().filter(
		func(unit):
			return (
				is_instance_of(unit.action, attack_move)
				and unit.action.destination.distance_to(field.position) < 10
			)
	)
	_check(not guards.is_empty(), faction + ": expansion received no guard")
	print("EXPANSION INITIAL ", faction, " ", map_name, " guards=", guards.size())
	opponent.resource_b = 0
	game.hud._toggle_pause()
	await _frames(150)
	game.hud._toggle_pause()
	var clock = game.simulation_time
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Expansion archive capture failed")
	if data == null:
		quit(1)
		return
	var worker_id = capture._reference(workers[2])
	var guard_ids = guards.map(func(unit): return capture._reference(unit))
	var goals = guards.map(
		func(unit):
			return unit.action.destination if is_instance_of(unit.action, attack_move) else null
	)
	var points = guards.map(func(unit): return unit.position)
	var archive = "user://ai-expansion-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, data), "Expansion archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Expansion archive restore failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	var worker = restore.entities[worker_id]
	opponent = worker.player
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan_owned(human):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	guards = guard_ids.map(func(id): return restore.entities[id])
	await _frames(15)
	_check(paused and game.simulation_time == clock, "Expansion archive advanced time")
	_check(worker.action == null, "Expansion archive released waiting engineer")
	for index in guards.size():
		_check(guards[index].position == points[index], "Paused expansion guard moved")
		if goals[index] != null:
			_check(
				(
					is_instance_of(guards[index].action, attack_move)
					and guards[index].action.destination == goals[index]
				),
				"Expansion archive changed guard goal"
			)
	hq = _units(opponent, "CommandCenter")[0]
	field = _nearest_deposit(hq, "resource_b")
	game.hud._toggle_pause()
	var stock_before = field.resource_b
	var entered = false
	var enter_time = 0.0
	for frame in 7200:
		if frame % 90 == 0:
			opponent._harvest(opponent._units())
			opponent._command_army(opponent._units())
		if not entered and is_instance_of(worker.action, harvest):
			entered = true
			enter_time = game.simulation_time
			_check(
				economy.guarded(opponent._units(), field.global_position_yless),
				"Engineer left before any guard arrived"
			)
			_check(
				worker.action._field_origin == field.global_position_yless,
				"Engineer chose wrong expansion"
			)
		if opponent.resource_b >= 4:
			break
		await physics_frame
	_check(entered, "Expansion engineer never received field assignment")
	_check(opponent.resource_b >= 4, "Protected expansion never delivered electronics")
	var carried = 0
	for gatherer in _units(opponent, "Worker"):
		carried += gatherer.resource_b
	_check(
		stock_before - field.resource_b == opponent.resource_b + carried,
		"Expansion income did not conserve finite stock and carried cargo"
	)
	game.hud._toggle_pause()
	_check(
		economy.guarded(opponent._units(), field.global_position_yless),
		"Guard abandoned field during delivery"
	)
	print(
		"EXPANSION RETURN ",
		faction,
		" ",
		map_name,
		" enter=",
		enter_time - 200,
		" income=",
		opponent.resource_b,
		" seconds=",
		game.simulation_time - 200
	)
	for index in 3:
		var reserve = load(catalog.scene_path("Tank")).instantiate()
		game._setup_and_spawn_unit(
			reserve,
			Transform3D(Basis(), hq.position + Vector3(-6 - index * 2, 0, 3)),
			opponent,
			false
		)
	guards = _guard_step(opponent)
	var waves = opponent.attacks_launched
	opponent._last_wave = game.simulation_time - 70
	opponent._command_army(opponent._units())
	_check(opponent.attacks_launched == waves + 1, "Field guard consumed entire offensive wave")
	for guard in guards:
		_check(
			(
				not is_instance_of(guard.action, attack_move)
				or guard.action.destination.distance_to(field.position) < 10
			),
			"Offensive wave stole an expansion guard"
		)
	await _review_expansion(opponent, field, faction + "-" + map_name)

	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func plan_owned(player):
	return player.get_children().filter(
		func(unit): return unit.is_in_group("units") and not unit.is_queued_for_deletion()
	)


func _nearest_deposit(unit, property):
	var choices = get_nodes_in_group("resource_units").filter(
		func(d): return not d.is_queued_for_deletion() and property in d and d.get(property) > 0
	)
	choices.sort_custom(
		func(a, b):
			return (
				unit.position.distance_squared_to(a.position)
				< unit.position.distance_squared_to(b.position)
			)
	)
	return choices[0]


func _review_expansion(_player, _field, _label):
	pass


func _threat_contract(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/DesertFrontier.tscn",
		true
	)
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan_owned(human):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	var units = opponent._units()
	var workers = _units(opponent, "Worker")
	var worker = workers[2]
	var hq = _units(opponent, "CommandCenter")[0]
	var deposit = _nearest_deposit(hq, "resource_b")
	worker.issue_manual_order(null)
	worker.position = deposit.position + Vector3(0, 0, 3)
	worker.resource_b = 3
	worker.issue_manual_order(harvest.new(deposit))
	var orders = load("res://source/match/orders/ManualOrders.gd")
	worker.manual_orders.submit(orders.target_order("gather", deposit), true)
	var threat = load(catalog.scene_path("Tank")).instantiate()
	game._setup_and_spawn_unit(
		threat, Transform3D(Basis(), worker.position + Vector3(-5, 0, 0)), human, false
	)
	threat.process_mode = Node.PROCESS_MODE_DISABLED
	var sights = units.map(func(unit): return unit.sight_range)
	for unit in units:
		unit.sight_range = 0
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(opponent, threat), "Hidden raid fixture is observed")
	var action = worker.action
	opponent._harvest(units)
	_check(worker.action == action, "Hidden raid changed engineer orders")
	for index in units.size():
		units[index].sight_range = sights[index]
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, threat), "Revealed raid not observed")
	var observed = economy.contacts(game, opponent)
	_check(
		economy.danger(worker.global_position_yless, worker, observed),
		"Legal ground threat ignored"
	)
	_check(
		not economy.danger(hq.global_position_yless, worker, observed),
		"Raid fixture threatens safe HQ"
	)
	var selected = economy.deposit(game, worker, hq, 2, observed)
	_check(selected != deposit, "Known occupied deposit selected")
	var defense = opponent._defend_economy(units, observed)
	_check(not defense.units.is_empty(), "Economic defense ignored observed raid")
	opponent._harvest(units)
	_check(is_instance_of(worker.action, moving), "Exposed gatherer did not withdraw")
	_check(worker.resource_b == 3, "Withdrawal discarded carried electronics")
	_check(worker.manual_orders.pending.is_empty(), "Withdrawal retained a stale mining handoff")
	var field_guards = _guard_step(opponent, units)
	_check(
		field_guards.all(func(unit): return unit not in defense.units),
		"Expansion stole active defenders"
	)
	opponent.resource_b = 0
	worker = await _restore_retreat(worker)
	if worker == null:
		return
	opponent = worker.player
	human = game._get_human_player()
	hq = _units(opponent, "CommandCenter")[0]
	var clock = game.simulation_time
	game.hud._toggle_pause()
	for frame in 1800:
		if frame % 90 == 0:
			opponent._harvest(opponent._units())
		if opponent.resource_b >= 3:
			break
		await physics_frame
	_check(
		opponent.resource_b == 3 and worker.resource_b == 0,
		"Retreated cargo was not delivered before reassignment"
	)
	game.hud._toggle_pause()
	print(
		"EXPANSION RETREAT ",
		faction,
		" cargo=",
		opponent.resource_b,
		" seconds=",
		game.simulation_time - clock
	)
	var scout = load(catalog.scene_path("Drone")).instantiate()
	game._setup_and_spawn_unit(
		scout, Transform3D(Basis(), worker.position + Vector3(2, 2, 0)), human, false
	)
	var aa = load(catalog.scene_path("AntiAirTurret")).instantiate()
	game._setup_and_spawn_unit(
		aa, Transform3D(Basis(), worker.position + Vector3(-2, 0, 0)), human, false
	)
	_check(
		not economy.danger(worker.global_position_yless, worker, [scout, aa]),
		"Unarmed/air-only contact threatened ground engineer"
	)
	var remote = Vector3(76, 0, 90)
	for unit in economy.guards(opponent._units()):
		unit.hp = unit.hp_max * 0.25
		unit.position = remote
	_check(
		not economy.guarded(opponent._units(), remote),
		"Critically damaged force admitted expansion"
	)
	worker.issue_manual_order(harvest.new(hq))
	_check(
		economy.expansion(game, [worker, hq], []) == null,
		"Explicit cargo delivery created a spurious field at origin"
	)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _restore_retreat(worker):
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Retreat archive capture failed")
	if data == null:
		quit(1)
		return null
	var worker_id = capture._reference(worker)
	var point = worker.position
	var goal = worker.action._target_position if is_instance_of(worker.action, moving) else null
	var clock = game.simulation_time
	var file = FileStore.new()
	var path = "user://ai-retreat-%d.json" % OS.get_process_id()
	_check(file.write_file(path, data), "Retreat archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Retreat archive restore failed")
	if not loaded.ok:
		quit(1)
		return null
	game = loaded.game
	worker = restore.entities[worker_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in plan_owned(game._get_human_player()):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(15)
	_check(
		paused and game.simulation_time == clock and worker.position == point,
		"Paused retreat archive moved engineer"
	)
	_check(worker.resource_b == 3, "Retreat archive lost cargo")
	if goal != null:
		_check(
			is_instance_of(worker.action, moving) and worker.action._target_position == goal,
			"Retreat archive lost withdrawal order"
		)
	return worker


func _split_fields(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/DesertFrontier.tscn",
		true
	)
	var player = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in plan_owned(game._get_human_player()):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	var hq = _units(player, "CommandCenter")[0]
	for deposit in get_nodes_in_group("resource_units"):
		if deposit.position.distance_to(hq.position) <= 30:
			deposit.queue_free()
	await _frames(3)
	var materials = _nearest_deposit(hq, "resource_a")
	var electronics = _nearest_deposit(hq, "resource_b")
	for worker in _units(player, "Worker"):
		worker.issue_manual_order(null)
	player.resource_a = 200
	player.resource_b = 0
	var guards = _guard_step(player)
	var points = economy.expansion_points(game, player._units(), [])
	_check(
		points.size() == 2 and guards.size() == 2,
		"Two remote resource approaches did not share exactly two guards"
	)
	for field in [materials, electronics]:
		var covered = false
		for unit in guards:
			if (
				is_instance_of(unit.action, attack_move)
				and unit.action.destination.distance_to(field.position) < 10
			):
				covered = true
		_check(covered, "A remote resource approach had no dedicated guard")
	player._harvest(player._units())
	_check(
		_units(player, "Worker").all(func(worker): return worker.action == null),
		"Split-field gatherers left before guards arrived"
	)
	var before = Vector2i(materials.resource_a, electronics.resource_b)
	game.hud._toggle_pause()
	for frame in 7200:
		if frame % 90 == 0:
			_guard_step(player)
			player._harvest(player._units())
		if player.resource_a >= 204 and player.resource_b >= 4:
			break
		await physics_frame
	game.hud._toggle_pause()
	_check(
		player.resource_a >= 204 and player.resource_b >= 4,
		"Protected split approaches failed to return both resources"
	)
	var cargo = Vector2i.ZERO
	for worker in _units(player, "Worker"):
		cargo += Vector2i(worker.resource_a, worker.resource_b)
	_check(
		(
			before - Vector2i(materials.resource_a, electronics.resource_b)
			== Vector2i(player.resource_a - 200, player.resource_b) + cargo
		),
		"Split-field income did not conserve finite resources"
	)
	print("EXPANSION SPLIT ", faction, " M=", player.resource_a - 200, " E=", player.resource_b)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _guard_step(player, units = null):
	player._command_army(player._units() if units == null else units)
	var result = []
	for group in player._army_groups:
		if group.kind == "guard":
			result.append_array(group.members)
	return result
