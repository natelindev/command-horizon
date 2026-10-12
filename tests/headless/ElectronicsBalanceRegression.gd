extends "res://tests/headless/SkirmishBudgetRegression.gd"

const MAP_NAMES = ["DesertFrontier", "AlpineRelay", "IndustrialCrossroads", "CoastalFoundry"]
const SPECIALISTS = ["RepairRobot", "CombatRobot", "AdvancedTank", "Helicopter"]
# One support/armor/air group should fit this electronics budget for each faction.
const MIXED_BUDGET = {"bastion": 50, "helix": 62, "frontier": 38}


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in [] if "--production-only" in OS.get_cmdline_user_args() else MAP_NAMES:
		await _skirmish("helix", "res://source/match/maps/%s.tscn" % map_name, false)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		await _supply(map_name)
		paused = false
		game.queue_free()
		await _frames(5)
	for faction in factions.IDS:
		await _skirmish(faction)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		await _mixed_production(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Electronics balance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _supply(map_name):
	var fields = get_nodes_in_group("resource_units")
	var stock = Vector2i.ZERO
	for field in fields:
		if "resource_a" in field:
			stock.x += field.resource_a
		else:
			stock.y += field.resource_b
	_check(stock == Vector2i(3000, 1920), map_name + ": insufficient mixed-army reserves")
	var sides = get_nodes_in_group("players")
	var assigned = []
	var before = []
	for side in sides:
		var worker = _units(side, "Worker")[0]
		var deposits = fields.filter(func(field): return "resource_b" in field)
		deposits.sort_custom(
			func(a, b):
				return (
					a.position.distance_to(worker.position)
					< b.position.distance_to(worker.position)
				)
		)
		_check(deposits[0].resource_b == 360, map_name + ": unequal home electronics")
		assigned.append(deposits[0])
		before.append(side.resource_b)
		worker.issue_manual_order(harvest.new(deposits[0]))
	for frame in 3600:
		if sides[0].resource_b >= before[0] + 8 and sides[1].resource_b >= before[1] + 8:
			break
		await physics_frame
	paused = true
	for index in sides.size():
		var side = sides[index]
		var worker = _units(side, "Worker")[0]
		var delivered = side.resource_b - before[index]
		_check(delivered >= 8, map_name + ": home electronics cannot sustain repeat deliveries")
		_check(
			360 - assigned[index].resource_b == delivered + worker.resource_b,
			map_name + ": gathering lost or created electronics"
		)
	print("SUPPLY ", map_name, " stock=", stock, " repeat deliveries from both starts")


func _mixed_production(faction):
	var human = game._get_human_player()
	human.coordination_unlocked = true
	var factory = _units(human, "VehicleFactory")[0]
	var air = _spawn("AircraftFactory", human, Vector3(32, 0, 12))
	await _frames(2)
	human.resource_a = 1000
	human.resource_b = MIXED_BUDGET[faction]
	var funds = Vector2i(human.resource_a, human.resource_b)
	for role in SPECIALISTS:
		var producer = air if role == "Helicopter" else factory
		var job = producer.production_queue.produce(load(catalog.scene_path(role)))
		_check(job != null, faction + ": mixed budget cannot queue " + role)
	_check(human.resource_b == 0, faction + ": specialist payment does not match mixed budget")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, faction + ": paid mixed queue cannot be saved: " + builder.error)
	if snapshot == null:
		return
	var reader = Restore.new()
	var restored = await reader.restore(self, snapshot)
	_check(restored.ok, faction + ": mixed queue cannot be restored: " + restored.get("error", ""))
	if not restored.ok:
		return
	game = restored.game
	human = game._get_human_player()
	for role in ["VehicleFactory", "AircraftFactory"]:
		_units(human, role)[0].production_queue.cancel_all()
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		faction + ": restored queue refunded a different price"
	)
	# Old queues retain the actual payment even after a balance update.
	factory = _units(human, "VehicleFactory")[0]
	var job = factory.production_queue.produce(load(catalog.scene_path("AdvancedTank")))
	_check(job != null, faction + ": cannot queue legacy-price fixture")
	if job == null:
		return
	job.paid_cost.resource_b += 6
	human.resource_b -= 6
	builder = Snapshot.new()
	snapshot = builder.capture(game)
	_check(snapshot != null, faction + ": old paid price rejected")
	if snapshot == null:
		return
	reader = Restore.new()
	restored = await reader.restore(self, snapshot)
	_check(restored.ok, faction + ": old paid queue failed load")
	if not restored.ok:
		return
	game = restored.game
	human = game._get_human_player()
	_units(human, "VehicleFactory")[0].production_queue.cancel_all()
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		faction + ": legacy-price refund did not preserve actual payment"
	)
	# Complete real queue jobs as well as exercising their payment contracts.
	for role in SPECIALISTS:
		var producer_role = "AircraftFactory" if role == "Helicopter" else "VehicleFactory"
		var producer = _units(human, producer_role)[0]
		var count_before = _units(human, role).size()
		job = producer.production_queue.produce(load(catalog.scene_path(role)))
		_check(job != null, faction + ": restored factory cannot produce " + role)
		producer.production_queue._process(1000.0)
		# Clear each completed unit from the physical production exit.
		for index in _units(human, role).size():
			_units(human, role)[index].position = Vector3(
				10 + index * 3, 0, 45 + SPECIALISTS.find(role) * 3
			)
		await _frames(2)
		_check(
			_units(human, role).size() == count_before + 1, faction + ": failed to finish " + role
		)
	print("MIXED PRODUCTION ", faction, " electronics=", MIXED_BUDGET[faction], " saved/refunded")
