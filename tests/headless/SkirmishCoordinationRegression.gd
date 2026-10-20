extends "res://tests/headless/SaveRestoreEdges.gd"

var catalog
var opponent
var human
var actors = []
var raider
var coordination


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		for difficulty in 3:
			await _fixture(faction, difficulty)
			opponent._command_army(actors)
			_check(
				opponent._army_groups.size() <= difficulty + 1, "Saved task roster exceeds budget"
			)
			var points = []
			for unit in actors:
				if unit.type == "Worker" or unit.action == null:
					continue
				var point = null
				if "destination" in unit.action:
					point = unit.action.destination
				elif unit.type == "Drone" and "_target_position" in unit.action:
					point = unit.action._target_position
				if point != null and points.all(func(p): return p.distance_to(point) > 12):
					points.append(point)
			print("COORDINATION ", faction, " difficulty=", difficulty, " goals=", points)
			_check(points.size() <= difficulty + 1, "Combined army tasks exceed difficulty budget")
			var orders = actors.map(func(unit): return unit.action)
			game.simulation_time += 1
			opponent._command_army(actors)
			_check(
				orders == actors.map(func(unit): return unit.action),
				"Unchanged objectives churned orders"
			)
			await _archive()
			_budget_contract()
			paused = false
			game.queue_free()
			await _frames(5)
		await _fixture(faction, 1)
		await _preemption_and_recovery()
		await _engaged_response()
		game.queue_free()
		await _frames(5)
		await _fixture(faction, 0)
		await _rotation_and_guard(faction)
		paused = false
		game.queue_free()
		await _frames(5)
		await _fixture(faction, 2)
		await _live_roles(faction)
		game.queue_free()
		await _frames(5)
	saves.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Global coordination: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction, difficulty):
	await _skirmish(
		"helix" if faction == "bastion" else "bastion", "res://source/match/maps/AlpineRelay.tscn"
	)
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	opponent.difficulty = difficulty
	game.settings.players[1].difficulty = difficulty
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		# Only the actors below participate in the AI scenario. Frozen starting
		# engineers otherwise form an impassable row across the cargo return route.
		# Keep structures and human units for the service and archive assertions.
		if unit.player == opponent and unit.movement_speed > 0:
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	actors = [_units(opponent, "CommandCenter")[0], _actor("Worker", opponent, Vector3(90, 0, 80))]
	for i in 2:
		actors.append(_actor("Tank", opponent, Vector3(85, 0, 78 + i * 3)))
	for i in 4:
		actors.append(_actor("Tank", opponent, Vector3(100 + i, 0, 90)))
	for i in 2:
		actors.append(_actor("Infantry", opponent, Vector3(95, 0, 62 + i * 3)))
	actors.append(_actor("Drone", opponent, Vector3(100, 2, 70)))
	raider = _actor("Tank", human, Vector3(93, 0, 80))
	await _frames(30)
	game.simulation_time = 240
	opponent._last_wave = 0
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, raider), "Coordination raid fixture is hidden")


func _actor(role, player, point):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _budget_contract():
	var assigned = []
	_check(opponent._army_groups.size() <= opponent.difficulty + 1, "Task roster exceeds budget")
	for group in opponent._army_groups:
		for unit in group.members:
			_check(unit not in assigned, "A unit belongs to two strategic groups")
			assigned.append(unit)
			_check(unit.player == opponent, "Task roster owns another player's unit")
			_check(
				(
					unit.action == null
					or not unit.action.get_script().resource_path.ends_with(
						"RecoveringAtService.gd"
					)
				),
				"Recovery unit remained assigned"
			)


func _archive():
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Coordinated battle could not be captured: " + snapshot.error)
	if data == null:
		return
	var refs = actors.map(snapshot._reference)
	var raid_ref = snapshot._reference(raider) if is_instance_valid(raider) else ""
	var expected = data.players[1].ai.duplicate(true)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	var broken = data.duplicate(true)
	broken.players[1].ai.cursor = 4
	_check(not schema.validate(broken), "Invalid coordination cursor accepted")
	broken = data.duplicate(true)
	broken.players[1].ai.groups[0].members.append(broken.players[1].ai.groups[0].members[0])
	_check(not schema.validate(broken), "Duplicate strategic member accepted")
	broken = data.duplicate(true)
	broken.players[1].ai.groups[0].age = data.simulation_time + 1
	_check(not schema.validate(broken), "Future task age accepted")
	broken = data.duplicate(true)
	broken.players[1].ai.groups[0].members[0] = snapshot._reference(_units(human, "Worker")[0])
	_check(not schema.validate(broken), "Enemy task member accepted")
	broken = data.duplicate(true)
	broken.players[1].ai.erase("groups")
	broken.players[1].ai.erase("cursor")
	_check(not schema.validate(broken), "AI record without task groups accepted")
	var file = FileStore.new()
	var destination = "user://coordination-%d.json" % OS.get_process_id()
	_check(file.write_file(destination, data), "Task roster disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(destination))
	_check(loaded.ok, "Task roster restore failed: " + loaded.get("error", ""))
	DirAccess.remove_absolute(destination)
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	opponent = restore.entities["player-1"]
	actors = refs.map(func(id): return restore.entities[id])
	raider = restore.entities.get(raid_ref)
	var again = Snapshot.new().capture(game)
	_check(again.players[1].ai == expected, "Paused restore changed task members, age or cursor")
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false


func _rotation_and_guard(faction):
	raider.queue_free()
	await _frames(5)
	game.battlefield.invalidate()
	game.simulation_time = 500
	opponent._last_wave = 0
	opponent._army_cursor = 0
	opponent._army_groups = []
	opponent._command_army(actors)
	_check(
		opponent._army_groups.size() == 1 and opponent._army_groups[0].kind == "assault",
		"Story assault failed to claim its sole group"
	)
	var started = opponent._army_groups[0].started
	game.simulation_time += 89
	opponent._command_army(actors)
	_check(
		opponent._army_groups[0].kind == "assault" and opponent._army_groups[0].started == started,
		"Ordinary task lost its commitment window"
	)
	game.simulation_time += 2
	opponent._command_army(actors)
	_check(
		opponent._army_groups[0].kind == "capture", "Expired assault starved a waiting capture task"
	)
	_budget_contract()
	# A remote field uses one coordinated patrol for nearby material/electronics approaches.
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit):
			return "resource_a" in unit and unit.position.distance_to(Vector3(98, 0, 46)) < 1
	)
	var deposit = deposits[0]
	var worker = actors.filter(func(unit): return unit.type == "Worker")[0]
	worker.position = deposit.position + Vector3(0, 0, -3)
	worker.issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
	)
	worker.resource_a = 3
	var tanks = actors.filter(func(unit): return unit.type == "Tank")
	tanks[0].position = Vector3(95, 0, 50)
	tanks[1].position = Vector3(101, 0, 50)
	opponent._army_cursor = 1
	opponent._army_groups = []
	game.battlefield.invalidate()
	opponent._command_army(actors)
	_check(
		opponent._army_groups.size() == 1 and opponent._army_groups[0].kind == "guard",
		"Remote workers did not receive a patrol"
	)
	_check(
		coordination.allows_expansion(opponent, deposit.position), "Active patrol denied expansion"
	)
	game.simulation_time += 91
	opponent._army_cursor = 0
	opponent._command_army(actors)
	_check(
		opponent._army_groups[0].kind == "guard" and opponent._army_groups[0].retiring,
		"Guard left before remote cargo returned"
	)
	_check(
		worker.resource_a == 3 and worker.action._kind == 0,
		"Patrol retirement lost cargo or failed to send it home"
	)
	_check(
		not coordination.allows_expansion(opponent, deposit.position),
		"Retiring patrol admitted new remote work"
	)
	await _archive()
	worker = actors.filter(func(unit): return unit.type == "Worker")[0]
	_check(
		opponent._army_groups[0].workers.has(worker), "Returning engineer reference lost in archive"
	)
	var funds = opponent.resource_a
	var waves = opponent.attacks_launched
	worker.process_mode = Node.PROCESS_MODE_INHERIT
	for group in opponent._army_groups:
		for unit in group.members:
			unit.process_mode = Node.PROCESS_MODE_INHERIT
	for frame in 3600:
		if frame % 90 == 0:
			opponent._command_army(actors)
		if worker.resource_a == 0 and opponent.attacks_launched > waves:
			break
		await physics_frame
	_check(
		worker.resource_a == 0 and opponent.resource_a == funds + 3,
		"Retiring patrol did not deliver exact existing cargo"
	)
	_check(
		opponent.attacks_launched > waves,
		"Returned engineers did not release the group for an overdue assault"
	)
	_budget_contract()
	print("COORDINATED GUARD RETURN ", faction, " at ", game.simulation_time)


func _preemption_and_recovery():
	opponent._command_army(actors)
	var assault = opponent._army_groups.filter(func(group): return group.kind == "assault")[0]
	var wounded = assault.members.filter(func(unit): return unit.type == "Tank")[0]
	var depot = _actor("RepairDepot", opponent, Vector3(112, 0, 63))
	actors.append(depot)
	await _frames(90)
	wounded.hp = wounded.hp_max * 0.25
	opponent._command_army(actors)
	var recovery_order = wounded.action
	_check(
		(
			recovery_order != null
			and recovery_order.get_script().resource_path.ends_with("RecoveringAtService.gd")
		),
		"Task roster stole critical service recovery"
	)
	_check(
		opponent._army_groups.all(func(group): return wounded not in group.members),
		"Recovering soldier retained a group slot"
	)
	var second_worker = _actor("Worker", opponent, Vector3(40, 0, 20))
	actors.append(second_worker)
	for i in 2:
		actors.append(_actor("Tank", opponent, Vector3(34, 0, 18 + i * 3)))
	var second_raider = _actor("Tank", human, Vector3(43, 0, 20))
	await _frames(30)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(opponent, second_raider), "Second raid fixture is hidden")
	var waves = opponent.attacks_launched
	opponent._command_army(actors)
	_check(
		(
			opponent._army_groups.size() == 2
			and opponent._army_groups.all(func(group): return group.kind == "defense")
		),
		"Urgent second raid did not preempt the ordinary task"
	)
	_check(opponent.attacks_launched == waves, "Preemption launched an extra offensive group")
	_check(wounded.action == recovery_order, "Urgent defense stole established recovery")
	_budget_contract()
	raider.position = Vector3(8, 0, 92)
	second_raider.position = Vector3(10, 0, 92)
	game.battlefield.invalidate()
	_check(
		(
			not game.battlefield.is_observed(opponent, raider)
			and not game.battlefield.is_observed(opponent, second_raider)
		),
		"Hidden raid positions remain observed"
	)
	opponent._command_army(actors)
	_check(
		opponent._army_groups.all(func(group): return group.kind != "defense"),
		"Unseen raids consumed coordinated groups"
	)
	for group in opponent._army_groups:
		_check(
			(
				group.point.distance_to(raider.position) > 10
				and group.point.distance_to(second_raider.position) > 10
			),
			"Task followed a hidden raider"
		)
	wounded.hp = wounded.hp_max * 0.8
	opponent._command_army(actors)
	_check(wounded.action != recovery_order, "Healthy soldier never became available again")
	_budget_contract()
	second_raider.queue_free()
	print("COORDINATION PREEMPTION AND RECOVERY ", opponent.faction)


func _live_roles(faction):
	var robot = _actor("RepairRobot", opponent, Vector3(102, 0, 87))
	actors.append(robot)
	var wounded = actors.filter(func(unit): return unit.type == "Tank")[-1]
	wounded.hp = wounded.hp_max * 0.6
	var hp = wounded.hp
	var human_hp = 0.0
	for unit in get_nodes_in_group("units"):
		if unit.player == human:
			human_hp += unit.hp
	opponent._command_army(actors)
	var assault = opponent._army_groups.filter(func(group): return group.kind == "assault")[0]
	var attacker = assault.members[0]
	var origin = attacker.position
	var captures = opponent._army_groups.filter(func(group): return group.kind == "capture")
	_check(captures.size() == 1, "Veteran did not coordinate a third live task")
	for unit in actors:
		if unit.movement_speed > 0 and unit.type != "Worker":
			unit.process_mode = Node.PROCESS_MODE_INHERIT
	var archived = false
	var damaged_raider = false
	var travelled = 0.0
	var serviced = false
	for frame in 3600:
		if frame % 90 == 0:
			opponent._command_army(actors)
			_budget_contract()
		if not is_instance_valid(raider) or raider.hp < raider.hp_max:
			damaged_raider = true
		travelled = maxf(travelled, attacker.position.distance_to(origin))
		serviced = serviced or wounded.hp > hp + 0.1
		if not archived and frame >= 600:
			var attacker_index = actors.find(attacker)
			var wounded_index = actors.find(wounded)
			await _archive()
			attacker = actors[attacker_index]
			wounded = actors[wounded_index]
			await _review_task_state(faction + "-advance")
			for unit in actors:
				if unit.movement_speed > 0 and unit.type != "Worker":
					unit.process_mode = Node.PROCESS_MODE_INHERIT
			archived = true
		await physics_frame
	var remaining_hp = 0.0
	for unit in get_nodes_in_group("units"):
		if unit.player == human:
			remaining_hp += unit.hp
	_check(damaged_raider, "Coordinated defense did not inflict real damage")
	_check(travelled > 30, "Coordinated assault failed actual departure")
	_check(
		game.map.relays.any(func(relay): return relay.captured_by == opponent),
		"Coordinated infantry never completed a real capture"
	)
	_check(serviced, "Attached support never serviced the staged wounded tank")
	_check(remaining_hp < human_hp, "Live coordinated groups never dealt damage")
	await _review_task_state(faction + "-capture")
	print(
		"COORDINATION LIVE ",
		faction,
		" assault_travel=",
		travelled,
		" support_healed=",
		serviced,
		" relays=",
		game.map.relays.filter(func(relay): return relay.captured_by == opponent).size(),
		" human_damage=",
		human_hp - remaining_hp
	)


func _review_task_state(_label):
	pass


func _engaged_response():
	var protected = _actor("Worker", opponent, Vector3(86, 0, 30))
	var counter = _actor("Tank", opponent, Vector3(76, 0, 24))
	var local_target = _actor("Worker", human, Vector3(80, 0, 24))
	var threat = _actor("Tank", human, Vector3(88, 0, 30))
	await _frames(60)
	counter.issue_manual_order(
		load("res://source/match/units/actions/AttackMoving.gd").new(Vector3(15, 0, 30))
	)
	counter.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(100)
	_check(
		is_instance_valid(local_target) and local_target.hp < local_target.hp_max,
		"Engaged fixture never fired at the local target"
	)
	_check(
		(
			counter.action != null
			and "_shot" in counter.action
			and is_instance_valid(counter.action._shot)
		),
		"Engaged fixture has no active local engagement"
	)
	game.battlefield.invalidate()
	opponent._command_army([actors[0], protected, counter])
	_check(
		(
			counter.action != null
			and "destination" in counter.action
			and counter.action.destination.distance_to(threat.position) < 1
		),
		"Active local fire retained the old strategic destination after reassignment"
	)
	print(
		"COORDINATION ENGAGED ORDER ",
		opponent.faction,
		" goal=",
		(
			counter.action.destination
			if counter.action != null and "destination" in counter.action
			else null
		)
	)
