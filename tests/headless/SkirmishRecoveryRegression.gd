extends "res://tests/headless/SaveRestoreEdges.gd"

var catalog
var wounded = []
var healthy = []
var facilities = []
var opponent
var recovery
var moving


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	recovery = load("res://source/match/players/skirmish-ai/SkirmishRecovery.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		var waves = opponent.attacks_launched
		opponent._command_army(opponent._units())
		for unit in wounded:
			_check(
				_recovering(unit), faction + ": wounded " + unit.type + " missed service recovery"
			)
		_check(
			opponent.attacks_launched == waves + 1, "Recovery stopped the healthy offensive reserve"
		)
		print("RECOVERY DECISION ", faction)
		await _live_recovery(faction)
		await _contracts(faction)
		paused = false
		game.queue_free()
		await _frames(5)
		game = null
		await _relay_contract(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/DesertFrontier.tscn",
		true
	)
	opponent = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	facilities = [
		_spawn("RepairDepot", Vector3(58, 0, 48)),
		_spawn("Barracks", Vector3(68, 0, 48)),
		_spawn("AircraftFactory", Vector3(78, 0, 48))
	]
	wounded = []
	var roles = ["Tank", "Infantry", "RepairRobot", "Helicopter", "Drone"]
	for index in roles.size():
		var unit = _spawn(roles[index], Vector3(42, 2 if index >= 3 else 0, 42 + index * 3))
		unit.hp = unit.hp_max * 0.25
		wounded.append(unit)
	healthy = []
	for index in 3:
		healthy.append(_spawn("Tank", Vector3(40 + index * 2, 0, 76)))
	game.simulation_time = 240
	opponent._last_wave = 170
	game.battlefield.invalidate()


func _spawn(role, point):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), opponent, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _recovering(unit):
	return (
		unit.action != null
		and unit.action.get_script().resource_path.ends_with("RecoveringAtService.gd")
	)


func _live_recovery(faction):
	if not wounded.all(func(unit): return _recovering(unit)):
		return
	for index in wounded.size():
		var expected = (
			"Barracks"
			if wounded[index].type == "Infantry"
			else ("AircraftFactory" if index >= 3 else "RepairDepot")
		)
		_check(wounded[index].action._target.type == expected, "Wrong recovery facility class")
	for unit in wounded + facilities:
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	var stock = Vector2i(opponent.resource_a, opponent.resource_b)
	var start = game.simulation_time
	game.hud._toggle_pause()
	await _frames(180)
	game.hud._toggle_pause()
	_check(
		wounded.any(func(unit): return unit.get_node("Movement")._has_destination),
		"Recovery archive fixture has no actual travel"
	)
	await _restore_recovery()
	if game == null:
		return
	game.hud._toggle_pause()
	var held = false
	var completed = []
	for frame in 5400:
		if frame % 90 == 0:
			var healing = wounded.filter(
				func(unit): return _recovering(unit) and unit.hp > unit.hp_max * 0.35
			)
			if not held and not healing.is_empty():
				game.hud._toggle_pause()
				await _restore_recovery()
				healing = wounded.filter(
					func(unit): return _recovering(unit) and unit.hp > unit.hp_max * 0.35
				)
				await _review_recovery(faction + "-service")
				var orders = healing.map(func(unit): return unit.action)
				var raider = load(catalog.scene_path("Infantry")).instantiate()
				var hq = _units(opponent, "CommandCenter")[0]
				game._setup_and_spawn_unit(
					raider,
					Transform3D(Basis(), hq.position + Vector3(-4, 0, 0)),
					game._get_human_player(),
					false
				)
				raider.process_mode = Node.PROCESS_MODE_DISABLED
				game.battlefield.invalidate()
				_check(
					game.battlefield.is_observed(opponent, raider),
					"Recovery defense fixture hidden"
				)
				opponent._last_wave = game.simulation_time - 70
				opponent._command_army(opponent._units())
				for index in healing.size():
					_check(
						healing[index].action == orders[index],
						"Defense or scheduled wave stole a recovering unit"
					)
				raider.queue_free()
				held = true
				game.hud._toggle_pause()
			else:
				opponent._command_army(opponent._units())
		for unit in wounded:
			if unit not in completed and not _recovering(unit):
				_check(
					unit.hp >= unit.hp_max * 0.8,
					"Recovery released a unit below the return threshold"
				)
				completed.append(unit)
				unit.process_mode = Node.PROCESS_MODE_DISABLED
		if completed.size() == wounded.size():
			break
		await physics_frame
	game.hud._toggle_pause()
	_check(held, "No actual intermediate recovery was tested against a new wave")
	_check(
		completed.size() == wounded.size(), "Not all five roles completed actual service recovery"
	)
	for unit in wounded:
		print(
			"RECOVERY LIVE ",
			faction,
			" ",
			unit.type,
			" hp=",
			unit.hp / unit.hp_max,
			" at=",
			unit.position,
			" action=",
			unit.action
		)
	_check(
		Vector2i(opponent.resource_a, opponent.resource_b) == stock,
		"Service retreat changed resource stock"
	)
	await _review_recovery(faction + "-ready")
	opponent._last_wave = game.simulation_time - 70
	opponent._command_army(opponent._units())
	for unit in wounded:
		if unit.type == "Drone":
			# Kamikaze drones escort the wave with a move order rather than attack-moving.
			_check(
				(
					unit.action != null
					and unit.action.get_script().resource_path.ends_with("Moving.gd")
				),
				"Recovered drone did not rejoin the next wave"
			)
		elif unit.attack_range != null:
			_check(
				(
					unit.action != null
					and unit.action.get_script().resource_path.ends_with("AttackMoving.gd")
				),
				"Recovered combat unit did not rejoin the next wave"
			)
		elif unit.type == "RepairRobot":
			_check(
				(
					unit.action != null
					and unit.action.get_script().resource_path.ends_with("Repairing.gd")
				),
				"Recovered support did not resume its duty"
			)
		elif unit.type == "Drone":
			_check(
				(
					unit.action != null
					and unit.action.get_script().resource_path.ends_with("Moving.gd")
				),
				"Recovered scout did not resume reconnaissance"
			)
	print("RECOVERY COMPLETE ", faction, " seconds=", game.simulation_time - start)


func _restore_recovery():
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Recovery archive capture failed")
	if data == null:
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	var subject = data.units.filter(func(saved): return saved.id == capture._reference(wounded[0]))[0]
	var retry = subject.action.state._retry_left
	subject.action.state._retry_left = 11.0
	_check(not schema.validate(data), "Archive accepted an unbounded recovery retry")
	subject.action.state._retry_left = retry
	var target = subject.action.references._target
	subject.action.references._target = capture._reference(
		_units(game._get_human_player(), "RepairDepot")[0]
	)
	_check(not schema.validate(data), "Archive accepted an enemy recovery service")
	subject.action.references._target = capture._reference(_units(opponent, "Barracks")[0])
	_check(not schema.validate(data), "Archive accepted the wrong recovery service class")
	subject.action.references._target = target
	_check(schema.validate(data), "Valid recovery archive failed schema validation")

	var ids = wounded.map(func(unit): return capture._reference(unit))
	var points = wounded.map(func(unit): return unit.position)
	var health = wounded.map(func(unit): return unit.hp)
	var target_ids = wounded.map(func(unit): return capture._reference(unit.action._target))
	var clock = game.simulation_time
	var path = "user://ai-recovery-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(path, data), "Recovery archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Recovery archive load failed")
	if not loaded.ok:
		return
	game = loaded.game
	wounded = ids.map(func(id): return restore.entities[id])
	opponent = wounded[0].player
	facilities = target_ids.map(func(id): return restore.entities[id])
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if unit in wounded or unit in facilities
			else Node.PROCESS_MODE_DISABLED
		)
	await _frames(20)
	_check(paused and game.simulation_time == clock, "Paused recovery archive advanced")
	for index in wounded.size():
		_check(
			_recovering(wounded[index]) and wounded[index].action._target == facilities[index],
			"Recovery archive lost matching service"
		)
		_check(
			wounded[index].position == points[index] and wounded[index].hp == health[index],
			"Paused archive moved or healed recovery unit"
		)


func _review_recovery(_label):
	pass


func _contracts(faction):
	var recover = load("res://source/match/units/actions/RecoveringAtService.gd")
	var economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	var unit = wounded[0]
	var depot = facilities[0]
	unit.issue_manual_order(moving.new(Vector3(42, 0, 48)))
	unit.hp = unit.hp_max * 0.3
	var existing = unit.action
	recovery.command(game, [unit, depot], [])
	_check(unit.action == existing, "Recovery starts at the exact thirty-percent boundary")
	unit.hp = unit.hp_max * 0.299
	recovery.command(game, [unit, depot], [])
	_check(_recovering(unit), "Recovery missed damage below its entry threshold")
	existing = unit.action
	unit.hp = unit.hp_max * 0.5
	recovery.command(game, [unit, depot], [])
	_check(unit.action == existing, "Recovery lost hysteresis above the entry threshold")
	unit.hp = unit.hp_max * 0.8
	recovery.command(game, [unit, depot], [])
	_check(not _recovering(unit), "Fully recovered unit was not released at eighty percent")
	existing = unit.action
	unit.hp = unit.hp_max * 0.25
	var foundation = _spawn("RepairDepot", unit.position + Vector3(5, 0, 0))
	foundation.mark_as_under_construction()
	recovery.command(game, [unit, foundation], [])
	_check(unit.action == existing, "Recovery selected an unfinished service foundation")
	recovery.command(game, [unit, facilities[1]], [])
	_check(unit.action == existing, "Armor retreated to infantry-only service")
	foundation.queue_free()
	await _frames(3)
	var saved_sights = []
	var units = opponent._units()
	for own in units:
		saved_sights.append(own.sight_range)
		own.sight_range = 0
	var threat = load(catalog.scene_path("Tank")).instantiate()
	game._setup_and_spawn_unit(
		threat,
		Transform3D(Basis(), depot.position + Vector3(3, 0, 0)),
		game._get_human_player(),
		false
	)
	threat.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(opponent, threat),
		"Hidden recovery threat fixture observed"
	)
	recovery.command(game, [unit, depot], economy.contacts(game, opponent))
	_check(
		_recovering(unit) and unit.action._target == depot, "Hidden danger changed recovery routing"
	)
	for index in units.size():
		units[index].sight_range = saved_sights[index]
	game.battlefield.invalidate()
	_check(
		game.battlefield.is_observed(opponent, threat), "Revealed recovery threat fixture hidden"
	)
	var alternate = _spawn("RepairDepot", Vector3(40, 0, 48))
	await _frames(10)
	recovery.command(game, [unit, depot, alternate], economy.contacts(game, opponent))
	_check(
		_recovering(unit) and unit.action._target == alternate,
		"Recovery retained an observed unsafe service"
	)
	alternate.queue_free()
	await _frames(3)
	recovery.command(game, [unit, depot], economy.contacts(game, opponent))
	_check(
		(
			_recovering(unit)
			and unit.action._blocked
			and not unit.get_node("Movement")._has_destination
		),
		"Service loss failed to hold wounded unit without unsafe travel"
	)
	threat.queue_free()
	await _frames(3)
	game.battlefield.invalidate()
	recovery.command(game, [unit, depot], economy.contacts(game, opponent))
	_check(
		_recovering(unit) and unit.action._target == depot,
		"Newly safe facility did not resume recovery"
	)
	# Direct replacement cancels the recovery action through the ordinary arbiter.
	var command = moving.new(Vector3(48, 0, 48))
	unit.issue_manual_order(command)
	await _frames(3)
	_check(unit.action == command, "Recovery overrode a direct replacement order")
	unit.issue_manual_order(recover.new(depot))
	unit.position = Vector3(42, 0, 48)
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	unit.get_node("Movement").set_physics_process(false)
	game.hud._toggle_pause()
	await _frames(330)
	game.hud._toggle_pause()
	_check(
		unit.action._blocked and unit.action._retry_left > 9,
		"Five-second stalled recovery failed to stop and defer retry"
	)
	var resumed = await _restore_blocked(unit, depot)
	if resumed.is_empty():
		return
	unit = resumed.unit
	depot = resumed.depot
	var stalled_action = unit.action
	recovery.command(game, [unit, depot], [])
	_check(unit.action == stalled_action, "Blocked recovery retried before its cooldown")
	unit.get_node("Movement").set_physics_process(true)
	game.hud._toggle_pause()
	await _frames(660)
	game.hud._toggle_pause()
	recovery.command(game, [unit, depot], [])
	_check(
		_recovering(unit) and unit.action != stalled_action and not unit.action._blocked,
		"Safe recovery could not retry after the bounded cooldown"
	)
	print("RECOVERY CONTRACT ", faction)


func _restore_blocked(unit, depot):
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Blocked recovery capture failed")
	if data == null:
		return {}
	var id = capture._reference(unit)
	var service_id = capture._reference(depot)
	var retry = unit.action._retry_left
	var hp = unit.hp
	var point = unit.position
	var clock = game.simulation_time
	var file = FileStore.new()
	var path = "user://ai-recovery-blocked-%d.json" % OS.get_process_id()
	_check(file.write_file(path, data), "Blocked recovery archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Blocked recovery restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return {}
	game = loaded.game
	unit = restore.entities[id]
	depot = restore.entities[service_id]
	opponent = unit.player
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for actor in get_nodes_in_group("units"):
		actor.process_mode = Node.PROCESS_MODE_DISABLED
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(20)
	_check(
		paused and game.simulation_time == clock and unit.position == point and unit.hp == hp,
		"Blocked recovery archive advanced while paused"
	)
	_check(
		_recovering(unit) and unit.action._blocked and unit.action._retry_left == retry,
		"Blocked recovery archive lost its deferred retry"
	)
	return {"unit": unit, "depot": depot}


func _relay_contract(faction):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion",
		"res://source/match/maps/AlpineRelay.tscn",
		true
	)
	opponent = get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud._toggle_pause()
	var infantry = _units(opponent, "Infantry")[0]
	var worker = _units(opponent, "Worker")[0]
	worker.issue_manual_order(moving.new(worker.position + Vector3(2, 0, 0)))
	worker.hp = worker.hp_max * 0.25
	var worker_order = worker.action
	infantry.hp = infantry.hp_max * 0.25
	recovery.command(game, opponent._units(), [])
	_check(_recovering(infantry), "Alpine relay infantry missed service recovery")
	_check(worker.action == worker_order, "Military recovery replaced an engineer's task")
	var order = infantry.action
	infantry.hp = infantry.hp_max * 0.5
	game.simulation_time = 240
	opponent._last_wave = 240
	opponent._command_army(opponent._units())
	_check(infantry.action == order, "Relay capture interrupted half-healed infantry")
	var other = _units(opponent, "Infantry")[1]
	_check(
		(
			other.action != null
			and other.action.get_script().resource_path.ends_with("AttackMoving.gd")
		),
		"Recovery suppressed the healthy relay infantry"
	)
	infantry.hp = infantry.hp_max * 0.8
	opponent._command_army(opponent._units())
	_check(
		(
			not _recovering(infantry)
			and infantry.action.get_script().resource_path.ends_with("AttackMoving.gd")
		),
		"Recovered infantry could not resume relay duties"
	)
	print("RECOVERY RELAY ", faction)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null
