extends "res://tests/headless/SaveRestoreEdges.gd"

var plan
var harvest
var factions
var catalog


func _run():
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	plan = load("res://source/match/SkirmishPlan.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	for faction in ["bastion", "helix"]:
		await _supply(faction)
	saves.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Economy supply: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _supply(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud._toggle_pause()
	var workers = _units(human, "Worker")
	var material = _deposit(workers[0], "resource_a")
	var electronics = _deposit(workers[0], "resource_b")
	for worker in workers:
		worker.issue_manual_order(harvest.new(material))
	workers[-1].issue_manual_order(null)
	human.resource_a = 100
	human.resource_b = 0
	var supply = plan.next_step(human)
	_check(supply.id == "supply_electronics", faction + ": missing electronics income ignored")
	_check(supply.units == [workers[-1]], "Supply advice did not prefer idle engineer")
	var actions = workers.map(func(worker): return worker.action)
	var funds = Vector2i(human.resource_a, human.resource_b)
	for index in 10:
		plan.next_step(human)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Advice spent resources")
	for index in workers.size():
		_check(workers[index].action == actions[index], "Advice replaced engineer order")
	await _review_supply(human, faction + "-supply")
	var displaced = workers[0]
	var waiting = harvest.new(null)
	waiting.restoring = true
	waiting._kind = 1
	waiting._field_origin = material.global_position_yless
	waiting._state = harvest.State.WAITING
	waiting._waiting_reason = harvest.Wait.DEPLETED
	displaced.issue_manual_order(waiting)
	_check(plan.next_step(human).id == "expand", "Quiet depletion did not request expansion")
	var threat = load(catalog.scene_path("Tank")).instantiate()
	game._setup_and_spawn_unit(
		threat, Transform3D(Basis(), displaced.position + Vector3(4, 0, 0)), enemy, false
	)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, threat), "Raid fixture is not observed")
	_check(plan.next_step(human).id == "defend_economy", faction + ": depletion masked raid")
	await _review_supply(human, faction + "-defend")
	threat.position = Vector3(108, 0, 85)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, threat), "Hidden threat still observed")
	_check(plan.next_step(human).id == "expand", "Hidden threat leaked into expansion advice")
	displaced.last_enemy_damage_time = game.simulation_time
	_check(
		plan.next_step(human).id == "defend_economy", "Recent damage lost priority over depletion"
	)
	displaced.last_enemy_damage_time = -1000
	displaced.issue_manual_order(harvest.new(material))
	workers[-1].issue_manual_order(harvest.new(electronics))
	_check(
		plan.next_step(human).id != "supply_electronics",
		"Returning/approaching gatherer treated as missing"
	)
	workers[-1].issue_manual_order(null)
	var clock = game.simulation_time
	var capture = Snapshot.new()
	var snapshot = capture.capture(game)
	_check(snapshot != null, "Supply snapshot failed: " + capture.error)
	if snapshot != null:
		var file = FileStore.new()
		var archive = "user://supply-%d.json" % OS.get_process_id()
		_check(file.write_file(archive, snapshot), "Supply archive write failed")
		var loaded = await Restore.new().restore(self, file.read_file(archive))
		DirAccess.remove_absolute(archive)
		_check(loaded.ok, "Supply archive restore failed")
		if loaded.ok:
			game = loaded.game
			human = game._get_human_player()
			for player in get_nodes_in_group("players"):
				player.set_process(false)
			await _frames(10)
			_check(paused and game.simulation_time == clock, "Supply archive advanced time")
			_check(plan.next_step(human).id == "supply_electronics", "Supply archive lost guidance")
	workers = _units(human, "Worker")
	var selected = plan.next_step(human).units
	if selected.size() == 1 and selected[0].type == "Worker":
		var worker = selected[0]
		worker.issue_manual_order(harvest.new(_deposit(worker, "resource_b")))
		var factory = _units(human, "VehicleFactory")[0]
		factory.production_queue.fit_chips = true
		var needed = factions.cost(human, "Tank").resource_b + 4
		game.hud._toggle_pause()
		for frame in 6000:
			if human.resource_b >= needed:
				break
			await physics_frame
		_check(human.resource_b >= needed, "Suggested engineer never funded fitted armor")
		game.hud._toggle_pause()
		print(
			"SUPPLY DELIVERY ",
			faction,
			" E=",
			human.resource_b,
			" seconds=",
			game.simulation_time - clock
		)
		var funds_before = Vector2i(human.resource_a, human.resource_b)
		var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
		_check(job != null, "Recovered income could not pay for fitted armor")
		if job != null:
			_check(human.resource_b == funds_before.y - needed, "Recovered production cost changed")
			var count = _units(human, "Tank").size()
			game.hud._toggle_pause()
			await _frames(1560)
			_check(
				_units(human, "Tank").size() == count + 1, "Paid armor did not finish production"
			)
			_check(_units(human, "Tank")[-1].program.installed, "Paid armor lost fitted chip")
			game.hud._toggle_pause()
	await _contracts(human, faction)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _contracts(human, faction):
	var workers = _units(human, "Worker")
	var materials = _deposit(workers[0], "resource_a")
	var electronics = _deposit(workers[0], "resource_b")
	for worker in workers:
		worker.issue_manual_order(harvest.new(electronics))
	human.resource_a = 0
	human.resource_b = 100
	_check(plan.next_step(human).id == "supply_materials", "Missing materials stream ignored")
	workers[0].issue_manual_order(harvest.new(materials))
	_check(
		not str(plan.next_step(human).id).begins_with("supply_"),
		"Working streams repeatedly interrupted"
	)
	for worker in workers:
		worker.issue_manual_order(harvest.new(materials))
	var moving = load("res://source/match/units/actions/Moving.gd")
	workers[0].issue_manual_order(moving.new(Vector3(26, 0, 26)))
	var orders = load("res://source/match/orders/ManualOrders.gd")
	workers[1].manual_orders.submit(orders.point_order("move", Vector3(26, 0, 26)), true)
	human.resource_a = 100
	human.resource_b = 0
	var suggested = plan.next_step(human)
	_check(suggested.id == "supply_electronics", "Eligible gatherer was not available")
	_check(
		workers[0] not in suggested.units and workers[1] not in suggested.units,
		"Supply selected manual or queued engineer"
	)
	for worker in workers:
		worker.issue_manual_order(harvest.new(materials))
	var foundation = load(catalog.scene_path("PowerPlant")).instantiate()
	game._setup_and_spawn_unit(foundation, Transform3D(Basis(), Vector3(38, 0, 22)), human, true)
	workers[0].issue_manual_order(
		load("res://source/match/units/actions/Constructing.gd").new(foundation)
	)
	_check(workers[0] not in plan.next_step(human).units, "Supply selected active builder")
	workers[0].issue_manual_order(harvest.new(materials))
	foundation.queue_free()
	var factory = _units(human, "VehicleFactory")[0]
	factory.production_queue.fit_chips = false
	human.resource_a = 100
	var price = factions.cost(human, "Tank")
	human.resource_b = price.resource_b
	_check(
		plan.next_step(human).id != "supply_electronics",
		"Affordable armor received shortage advice"
	)
	factory.production_queue.fit_chips = true
	_check(
		plan.next_step(human).id == "supply_electronics",
		"Fitted chip cost omitted from supply advice"
	)
	human.resource_b += 4
	_check(
		plan.next_step(human).id != "supply_electronics",
		"Affordable fitted armor received shortage advice"
	)
	var aircraft = load(catalog.scene_path("AircraftFactory")).instantiate()
	game._setup_and_spawn_unit(aircraft, Transform3D(Basis(), Vector3(32, 0, 12)), human, false)
	var power = load(catalog.scene_path("PowerPlant")).instantiate()
	game._setup_and_spawn_unit(power, Transform3D(Basis(), Vector3(36, 0, 12)), human, false)
	human.resource_b = factions.cost(human, "Helicopter").resource_b - 1
	_check(
		plan.next_step(human).id == "supply_electronics",
		"Air production cost omitted from supply advice"
	)
	human.resource_b += 1
	_check(
		plan.next_step(human).id != "supply_electronics",
		"Affordable aircraft received shortage advice"
	)
	print("SUPPLY CONTRACTS ", faction)


func _deposit(worker, property):
	var choices = get_nodes_in_group("resource_units").filter(
		func(d): return property in d and d.get(property) > 0
	)
	choices.sort_custom(
		func(a, b):
			return (
				worker.position.distance_squared_to(a.position)
				< worker.position.distance_squared_to(b.position)
			)
	)
	return choices[0]


func _review_supply(_player, _label):
	pass
