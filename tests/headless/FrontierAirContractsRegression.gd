extends "res://tests/headless/FactionAsymmetryRegression.gd"

var contracts
var aircraft = []


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("frontier")
	for field in _units(human, "AircraftFactory"):
		field.queue_free()
	await _frames(3)
	contracts = load("res://source/match/economy/FrontierAirContracts.gd").get_for(human)
	await _purchase_and_limits()
	await _sorties_and_save()
	paused = false
	game.queue_free()
	await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for error in errors:
		push_error(error)
	print("Frontier aircraft contracts: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _purchase_and_limits():
	_check(
		not factions.available(human, "AircraftFactory", true),
		"Contracts restored the forbidden air factory"
	)
	_check(
		factions.air_contract_roles("bastion").is_empty(), "Other faction has Frontier contracts"
	)
	var labs = _units(human, "CommandLab")
	for lab in labs:
		lab._construction_progress = .5
	_check(contracts.hire("Fighter") == null, "Unfinished Scrap Yard hired aircraft")
	for lab in labs:
		lab._construction_progress = 1.0
	for role in contracts.ROLES:
		contracts.cooldown_left = 0.0
		var resources = Vector2i(human.resource_a, human.resource_b)
		var population = human.population(true)
		var cost = factions.cost(human, role)
		var unit = contracts.hire(role)
		_check(unit != null, "Aircraft contract refused: " + role)
		if unit == null:
			continue
		aircraft.append(unit)
		_check(human.population(true) == population + 1, "Aircraft contract bypassed population")
		_check(
			(
				Vector2i(human.resource_a, human.resource_b)
				== resources - Vector2i(cost.resource_a, cost.resource_b)
			),
			"Aircraft contract payment differs"
		)
		_check(contracts.hire(role) == null, "Aircraft contract bypassed its cooldown")
		_check(
			is_equal_approx(contracts.cooldown_left, 20.0),
			"Contract cooldown did not begin at 20 seconds"
		)
		await _ticks(3)
		_check(
			unit.has_node("MercenarySortie") and not unit.unlimited_stores,
			"Contract has unlimited ammunition"
		)
		var movement = unit.get_node("Movement")
		if role != "Helicopter":
			_check(
				movement.is_airborne() and movement.airfield == null,
				"Contracted jet needs an airfield"
			)
		var point = unit.global_position
		_check(
			(
				point.x >= 0
				and point.z >= 0
				and point.x <= game.map.size.x
				and point.z <= game.map.size.y
			),
			"Aircraft entered outside legal bounds"
		)
		_check(
			point.y > game.map.height_at(Vector2(point.x, point.z)) + .8,
			"Aircraft entered below terrain clearance"
		)
		unit.global_position = Vector3(24 + aircraft.size() * 6, 8, 30)
		unit.reset_physics_interpolation()
	contracts.cooldown_left = 0.0
	var resources = Vector2i(human.resource_a, human.resource_b)
	paused = true
	_check(contracts.hire("Fighter") == null, "Paused battle accepted aircraft contract")
	paused = false
	human.resource_a = 0
	_check(contracts.hire("Fighter") == null, "Unaffordable aircraft contract was accepted")
	human.resource_a = resources.x
	var reservations = []
	for _index in range(factions.Bastion.POPULATION_LIMIT - human.population(true)):
		var reserved = Node3D.new()
		var movement = Node.new()
		movement.name = "Movement"
		reserved.add_child(movement)
		human.add_child(reserved)
		reservations.append(reserved)
	_check(contracts.hire("Fighter") == null, "Aircraft contract bypassed population cap")
	_check(
		Vector2i(human.resource_a, human.resource_b) == resources,
		"Rejected contract consumed resources"
	)
	for reservation in reservations:
		reservation.queue_free()
	await _ticks(2)


func _sorties_and_save():
	if aircraft.size() != 3:
		return
	var helicopter = aircraft[0]
	var fighter = aircraft[1]
	var bomber = aircraft[2]
	helicopter.rockets = 0
	helicopter._physics_process(10.0)
	_check(helicopter.rockets == 0, "Mercenary helicopter reloaded without a service contract")
	helicopter.get_node("MercenarySortie")._physics_process(.1)
	_check(
		helicopter.get_node("MercenarySortie").departing and not helicopter.armed(),
		"Empty helicopter did not depart"
	)
	fighter.stores.missile = 2
	fighter.stores.cannon = 17
	fighter.get_node("MercenarySortie").fuel_left = 63.0
	bomber.get_node("MercenarySortie").fuel_left = 0.0
	bomber.get_node("MercenarySortie")._physics_process(.1)
	_check(
		bomber.get_node("MercenarySortie").departing and not bomber.weapons_free(),
		"Fuel-exhausted bomber did not depart"
	)
	contracts.cooldown_left = 12.5
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Aircraft contract capture failed: " + builder.error)
	if snapshot == null:
		paused = false
		return
	var ids = aircraft.map(func(unit): return builder._reference(unit))
	for corruption in [
		func(data): data.players[0].economy.air_contract_left = 20.1,
		func(data):
			data.units.filter(func(unit): return unit.id == ids[1])[0].benchmark.mercenary.fuel_left = 91.0,
		func(data):
			data.units.filter(func(unit): return unit.id == ids[1])[0].benchmark.mercenary.exit = Vector3(
				10000, 0, 0
			),
	]:
		var broken = snapshot.duplicate(true)
		corruption.call(broken)
		_check(not Restore.new().prepare(broken), "Corrupt mercenary contract was accepted")
	var restore = Restore.new()
	var result = await restore.restore(self, snapshot)
	_check(result.ok, "Mercenary restore failed: " + result.get("error", ""))
	if not result.ok:
		paused = false
		return
	game = result.game
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	contracts = human.get_node("AirContracts")
	aircraft = ids.map(func(id): return restore.entities[id])
	fighter = aircraft[1]
	_check(
		fighter.get_node("MercenarySortie").fuel_left == 63.0 and contracts.cooldown_left == 12.5,
		"Reload changed contract timers"
	)
	_check(
		fighter.stores.missile == 2 and fighter.stores.cannon == 17,
		"Reload replenished paid aircraft ammunition"
	)
	_check(
		(
			aircraft[0].get_node("MercenarySortie").departing
			and aircraft[2].get_node("MercenarySortie").departing
		),
		"Reload cancelled mercenary departures"
	)
	await _ticks(10)
	_check(
		fighter.get_node("MercenarySortie").fuel_left == 63.0 and contracts.cooldown_left == 12.5,
		"Pause advanced aircraft contracts"
	)
	paused = false
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for unit in aircraft:
		unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	for key in fighter.stores:
		fighter.stores[key] = 0
	fighter.get_node("MercenarySortie")._physics_process(.1)
	_check(fighter.get_node("MercenarySortie").departing, "Empty fighter did not depart")
	var population = human.population()
	for _index in 2400:
		if aircraft.all(func(unit): return not is_instance_valid(unit)):
			break
		await physics_frame
	_check(
		aircraft.all(func(unit): return not is_instance_valid(unit)),
		"Mercenary aircraft failed to leave through the exit corridor"
	)
	_check(human.population() == population - 3, "Departed contracts retained population")


func _ticks(count):
	for _index in count:
		await physics_frame
