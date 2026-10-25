extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var combat_rules
var harvest
var human
var enemy


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture()
	_check(await _roster() == true, "roster suite did not finish")
	await _cleanup()
	await _fixture()
	_check(await _maneuver() == true, "maneuver suite did not finish")
	await _cleanup()
	await _fixture()
	_check(await _salvage_visibility() == true, "salvage visibility suite did not finish")
	await _cleanup()
	await _fixture()
	_check(await _salvage() == true, "salvage suite did not finish")
	await _cleanup()
	for message in errors:
		push_error(message)
	print("Frontier gameplay: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture():
	await _skirmish("frontier", "res://source/match/maps/PlainAndSimple.tscn")
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	human.resource_a = 1000
	human.resource_b = 1000
	for worker in _units(human, "Worker"):
		worker.issue_manual_order(null)


func _cleanup():
	paused = false
	game.queue_free()
	await _frames(5)


func _roster():
	var tank = _units(human, "Tank")[0]
	var base = root.get_node("Constants").Match.Units.DEFAULT_PROPERTIES
	_check(
		tank.hp_max == roundi(base[factions.Bastion.scene_path("Tank")].hp_max * .85),
		"Frontier health modifier missing"
	)
	for role in factions.Frontier.MODELS:
		_check(
			ResourceLoader.exists(factions.icon("frontier", role)), role + ": missing Frontier icon"
		)
		_check(
			factions.title("frontier", role) == factions.Frontier.NAMES[role],
			role + ": wrong roster title"
		)
	_check(
		tank.has_meta("model_faction") and tank.get_meta("model_faction") == "frontier",
		"Spawn retained Bastion geometry"
	)
	var factory = _units(human, "VehicleFactory")[0]
	var before = Vector2i(human.resource_a, human.resource_b)
	var job = factory.production_queue.produce(load(factions.Bastion.scene_path("Tank")))
	_check(job != null, "Frontier paid production rejected")
	if job != null:
		_check(
			(
				job.paid_cost == {"resource_a": 20, "resource_b": 4}
				and job.time_total == factions.duration(human, "Tank")
			),
			"Factory price/time incorrect"
		)
		_check(
			Vector2i(human.resource_a, human.resource_b) == before - Vector2i(20, 4),
			"Factory used wrong real debit"
		)
	var heavy = _spawn_frontier("AdvancedTank", human, Vector3(20, 0, 15))
	await _frames(2)
	_check(
		(
			combat_rules.preparation_for(heavy) == 0
			and combat_rules.profile_for(heavy) == "Heavy cannon"
		),
		"Frontier cannon inherited precision charge"
	)
	print("PASS: Frontier roster, models and paid factory production")

	return true


func _maneuver():
	var tank = _units(human, "Tank")[0]
	tank.global_position = Vector3(22, 0, 22)
	_check(human.signatures.activate([tank]) == 0, "Maneuver bypasses Coordination")
	human.coordination_unlocked = true
	var movement = tank.get_node("Movement")
	var speed = tank.movement_speed
	tank.manual_orders.submit(
		{"kind": "move", "point": tank.global_position_yless + Vector3(8, 0, 0)}
	)
	var order = tank.action
	_check(human.signatures.activate([tank, tank]) == 1, "Maneuver accepted duplicate participants")
	_check(
		tank.action == order and tank.signature.kind == "maneuver",
		"Maneuver replaced manual order or used wrong ability"
	)
	_check(is_equal_approx(tank.movement_speed, speed * 1.35), "Maneuver speed getter not applied")
	var origin = tank.global_position
	await _frames(60)
	_check(tank.global_position.distance_to(origin) > .8, "Maneuver stopped actual movement")
	_check(human.signatures.activate([tank]) == 0, "Maneuver bypassed cooldown")
	paused = true
	var before = tank.signature.capture()
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Maneuver archive capture failed: " + builder.error)
	if data == null:
		return
	var id = builder._reference(tank)
	var restore = Restore.new()
	_check(restore.prepare(data), "Maneuver archive validation failed: " + restore.error)
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Maneuver reload failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	tank = restore.entities[id]
	await _frames(10)
	_check(
		tank.signature.capture() == before and is_equal_approx(tank.movement_speed, speed * 1.35),
		"Paused reload changed/stacked maneuver"
	)
	human.technology.completed.append("doctrine")
	_check(
		is_equal_approx(tank.movement_speed, speed * 1.5),
		"Frontier doctrine did not improve active mobility"
	)
	game.hud._toggle_pause()
	await _frames(360)
	_check(
		tank.signature.kind == "" and is_equal_approx(tank.movement_speed, speed),
		"Maneuver did not expire without permanent speed stacking"
	)
	_check(
		tank.signature.cooldown > 0 and human.signatures.activate([tank]) == 0,
		"Expired burst discarded recharge"
	)
	print(
		"PASS: Frontier maneuver manual authority, real travel, exact archive, doctrine and expiration"
	)

	return true


func _salvage_visibility():
	var hq = _units(human, "CommandCenter")[0]
	var observed = _spawn_frontier("Tank", enemy, hq.global_position_yless + Vector3(5, 0, 2))
	var hidden = _spawn_frontier("Tank", enemy, Vector3(45, 0, 45))
	await _frames(3)
	observed.hp = 0
	hidden.hp = 0
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Wreck visibility capture failed: " + builder.error)
	if data == null:
		return false
	var wrecks = get_nodes_in_group("salvage_wrecks")
	_check(wrecks.size() == 2, "Wreck visibility fixture needs two wrecks")
	if wrecks.size() != 2:
		return false
	var observed_id = builder._reference(wrecks[0])
	var hidden_id = builder._reference(wrecks[1])
	_check(wrecks[0].visible and not wrecks[1].visible, "Wreck visibility fixture is invalid")
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Wreck visibility restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return false
	game = loaded.game
	var ownership = load("res://source/match/hud/Ownership.gd")
	_check(paused, "Wreck visibility verification must happen before resuming")
	_check(
		(
			restore.entities[observed_id].visible
			and ownership.known_now(restore.entities[observed_id], game)
		),
		"Observed wreck or its minimap marker disappeared during paused restore"
	)
	_check(
		(
			not restore.entities[hidden_id].visible
			and not ownership.known_now(restore.entities[hidden_id], game)
		),
		"Paused restore exposed a hidden wreck or its minimap marker"
	)
	return true


func _salvage():
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(90)
	var worker = _units(human, "Worker")[0]
	var hq = _units(human, "CommandCenter")[0]
	var point = hq.global_position_yless + Vector3(5, 0, 2)
	var victim = _spawn_frontier("Tank", enemy, point)
	await _frames(3)
	var expected = load("res://source/match/economy/SalvageRules.gd").amount(
		victim.player.faction, victim.type
	)
	var funds = human.resource_a
	victim.hp = 0
	# Capture before the deferred spawn to prove that a death cannot lose its wreck.
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Pending wreck capture failed: " + builder.error)
	if data == null:
		return
	var wrecks = get_nodes_in_group("salvage_wrecks")
	_check(wrecks.size() == 1, "Death did not produce exactly one finite wreck")
	if wrecks.is_empty():
		return
	var wreck = wrecks[0]
	_check(
		wreck.resource_a == expected and human.resource_a == funds,
		"Destruction awarded funds or wrong salvage value"
	)
	_check(
		not harvest.is_applicable(_units(enemy, "Worker")[0], wreck),
		"Other faction can harvest Frontier salvage"
	)
	_check(wreck.can_harvest(worker), "Observed salvage is unavailable to a Frontier engineer")
	var bad = data.duplicate(true)
	bad.resources[0].amount = 999
	_check(not Restore.new().prepare(bad), "Inflated wreck amount accepted")
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Pending wreck archive failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	worker = _units(human, "Worker")[0]
	wreck = get_nodes_in_group("salvage_wrecks")[0]
	_check(
		(
			get_nodes_in_group("salvage_wrecks").size() == 1
			and wreck.resource_a == expected
			and wreck.salvage_left == 180
		),
		"Wreck duplicated or advanced on load"
	)
	worker.global_position = wreck.global_position + Vector3(0, 0, .85)
	worker.issue_manual_order(harvest.new(wreck))
	game.hud._toggle_pause()
	await _frames(105)
	_check(worker.resource_a > 0 or human.resource_a > funds, "Wreck produced no actual cargo")
	paused = true
	builder = Snapshot.new()
	data = builder.capture(game)
	_check(data != null, "Active salvage could not be captured: " + builder.error)
	if data == null:
		return
	var saved_amount = data.resources.reduce(func(total, entry): return total + entry.amount, 0)
	var saved_cargo = worker.resource_a
	var delivered = human.resource_a - funds
	_check(
		saved_amount + saved_cargo + delivered == expected,
		"Salvage conservation failed before reload"
	)
	loaded = await restore.restore(self, data)
	_check(loaded.ok, "Active salvage restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	game.hud._toggle_pause()
	await _frames(1000)
	_check(
		human.resource_a == funds + expected, "Finite salvage failed to deposit its exact materials"
	)
	_check(get_nodes_in_group("salvage_wrecks").is_empty(), "Depleted wreck remained collectible")
	print(
		(
			"PASS: finite observed salvage, deferred-death archive, "
			+ "on-site dismantling reload and exact deposit"
		)
	)

	return true


func _spawn_frontier(role, owner, point):
	var unit = load(factions.Bastion.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), owner, false)
	return unit
