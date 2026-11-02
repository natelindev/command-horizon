extends "res://tests/headless/SaveRestoreEdges.gd"

var opponent
var observer
var contact
var factory
var factions
var catalog
var composition


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	composition = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
		opponent.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		opponent.resource_a = 500
		opponent.resource_b = 300
		factory = _units(opponent, "VehicleFactory")[0]
		# Isolate threat priorities from the advanced base's existing power deficit.
		_actor("PowerPlant", opponent, Vector3(104, 0, 82))
		observer = _actor("Worker", opponent, Vector3(80, 0, 10))
		contact = _actor("Helicopter", human, Vector3(83, 2, 10))
		await _frames(30)
		game.battlefield.invalidate()
		_check(
			game.battlefield.is_observed(opponent, contact), "Composition fixture air threat hidden"
		)
		game.simulation_time = 60
		_check(
			opponent._next_building(opponent._units()) == "AntiAirTurret",
			"AI did not prioritize scouted air defense"
		)
		opponent._production_index = 0
		opponent._train(_training_units([factory]), "")
		_check(_queued(factory) == "AntiAirVehicle", "AI ignored visible air threat when training")
		factory.production_queue.cancel_all()
		var hq = _units(opponent, "CommandCenter")[0]
		opponent._production_index = 0
		opponent._train(_training_units([hq]), "")
		_check(hq.production_queue.size() == 1, "Worker sequence fixture did not reserve a job")
		_check(opponent._production_index == 0, "Worker production advanced vehicle roster")
		hq.production_queue.cancel_all()
		await _visibility_and_queues()
		await _faction_roles()
		await _budget_and_technology()
		await _counter_building()
		await _counter_completion()
		_test_allied_contacts(game._get_human_player())
		print("COMPOSITION ", opponent.faction)
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Skirmish composition: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _actor(role, player, point):
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _test_allied_contacts(human):
	var economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	# The preceding combat check may have destroyed its aircraft.
	contact = _actor("Helicopter", human, Vector3(83, 2, 10))
	var teams = [human.team, opponent.team]
	human.team = 0
	opponent.team = 0
	game.battlefield.invalidate()
	_check(economy.contacts(game, opponent).is_empty(), "Allied units became enemy contacts")
	_check(composition.observed(game, opponent).air == 0, "Allied aircraft requested a counter")
	human.team = teams[0]
	opponent.team = teams[1]
	game.battlefield.invalidate()
	var contacts = economy.contacts(game, opponent)
	_check(contact in contacts, "Enemy contact lost after team change")
	opponent.set_meta("decision_contacts", contacts)
	_check(economy.contacts(game, opponent) == contacts, "Decision lost its shared observations")
	opponent.remove_meta("decision_contacts")
	var tactics = load("res://source/match/players/skirmish-ai/SkirmishTactics.gd")
	var first = _actor("Infantry", human, Vector3(81, 0, 14))
	var second = _actor("Infantry", human, Vector3(84, 0, 14))
	var isolated = _actor("Tank", human, Vector3(95, 0, 14))
	game.battlefield.invalidate()
	var thrower = _actor("Infantry", opponent, Vector3(79, 0, 14))
	var pending = game.grenade_system.pending.size()
	tactics._use_grenades(game, opponent, [thrower], [first, second, isolated, contact])
	_check(game.grenade_system.pending.size() == pending, "AI threw frag at open-ground cluster")
	_check(thrower.abilities.get_ability("frag_grenade").is_ready(), "AI wasted grenade cooldown")
	thrower.queue_free()
	first.queue_free()
	second.queue_free()
	isolated.queue_free()


func _training_units(producers):
	return opponent._units().filter(
		func(unit): return unit.get_node_or_null("ProductionQueue") == null or unit in producers
	)


func _queued(producer):
	var jobs = producer.production_queue.get_elements()
	return "" if jobs.is_empty() else catalog.type_from_path(jobs[0].unit_prototype.resource_path)


func _visibility_and_queues():
	var sight = observer.sight_range
	observer.sight_range = 0
	game.battlefield.invalidate()
	_check(
		not game.battlefield.is_observed(opponent, contact), "Hidden composition fixture visible"
	)
	_check(
		opponent._next_building(opponent._units()) == "",
		"Hidden aircraft changed building priority"
	)
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	_check(_queued(factory) == "Tank", "Hidden aircraft changed vehicle choice")
	factory.production_queue.cancel_all()
	observer.sight_range = sight
	game.battlefield.invalidate()
	var second = _actor("VehicleFactory", opponent, Vector3(95, 0, 40))
	await _frames(60)
	var funds = Vector2(opponent.resource_a, opponent.resource_b)
	# One observed aircraft calls for one mobile anti-air vehicle. A second idle
	# factory must count the just-paid counter rather than duplicate it.
	opponent._production_index = 1
	opponent._train(_training_units([factory, second]), "")
	var roles = [_queued(factory), _queued(second)]
	_check(
		roles.count("AntiAirVehicle") == 1 and roles.count("") == 0,
		"Two factories duplicated an already-funded counter"
	)
	var paid = Vector2.ZERO
	for producer in [factory, second]:
		for job in producer.production_queue.get_elements():
			paid += Vector2(job.paid_cost.resource_a, job.paid_cost.resource_b)
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds - paid,
		"Counter queues paid incorrect costs"
	)
	_check(
		composition.inventory(opponent._units()).get("AntiAirVehicle", 0) == 1,
		"Inventory omitted queued counter"
	)
	opponent._train(_training_units([factory, second]), "")
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds - paid,
		"Busy counter queues spent twice"
	)
	for producer in [factory, second]:
		producer.production_queue.cancel_all()
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds,
		"Counter queue refund changed resources"
	)
	second.queue_free()
	await _frames(90)
	# Armed loitering munitions need counters; Helix's unarmed EW scout does not.
	await _replace_contact("Drone")
	if contact.player.faction == "helix":
		_check(opponent._next_building(opponent._units()) == "", "Unarmed EW scout requested AA")
		opponent._production_index = 0
		opponent._train(_training_units([factory]), "")
		_check(_queued(factory) == "Tank", "Unarmed EW scout requested mobile AA")
		factory.production_queue.cancel_all()
		await _replace_contact("Helicopter")
	_check(
		opponent._next_building(opponent._units()) == "AntiAirTurret",
		"Armed drone did not trigger emergency AA"
	)
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	_check(_queued(factory) == "AntiAirVehicle", "Armed drone did not trigger mobile AA production")
	factory.production_queue.cancel_all()
	print("PASS: hidden/armed-drone contacts, two-factory queued quotas, paid costs and refunds")


func _replace_contact(role):
	contact.queue_free()
	await _frames(5)
	contact = _actor(role, game._get_human_player(), Vector3(83, 0, 10))
	await _frames(20)
	game.battlefield.invalidate()
	_check(
		game.battlefield.is_observed(opponent, contact), "Replacement composition contact hidden"
	)


func _faction_roles():
	await _replace_contact("Tank")
	opponent.coordination_unlocked = true
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	# Helix fields an anti-armor Lancer. Bastion reserves its stationary siege
	# gun for structures and keeps the mobile tank line against armor.
	var expected = "CombatRobot" if opponent.faction == "helix" else "Tank"
	_check(_queued(factory) == expected, "Scouted armor did not select faction-appropriate counter")
	factory.production_queue.cancel_all()
	await _replace_contact("Infantry")
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	expected = "Tank" if opponent.faction == "helix" else "CombatRobot"
	_check(_queued(factory) == expected, "Anti-infantry choice ignored faction weapon profile")
	factory.production_queue.cancel_all()
	var added = []
	while _units(opponent, "Infantry").size() < 6:
		added.append(_actor("Infantry", opponent, Vector3(96, 0, 72 + added.size())))
	# Fill the hero/specialist goals before checking the remaining rifle-screen goal.
	for role in ["Hero", "AssaultInfantry", "SniperInfantry", "SniperInfantry", "RocketInfantry"]:
		added.append(_actor(role, opponent, Vector3(96 + added.size(), 0, 82)))
	await _frames(10)
	var barracks = _units(opponent, "Barracks")[0]
	opponent._train(_training_units([barracks]), "")
	_check(
		barracks.production_queue.size() == (1 if opponent.faction == "helix" else 0),
		"Helix did not add a rifle screen against infantry"
	)
	_check(opponent._production_index == 1, "Infantry counter changed vehicle sequence")
	barracks.production_queue.cancel_all()
	for unit in added:
		unit.queue_free()
	await _frames(5)
	await _replace_contact("Worker")
	var tank = _actor("Tank", opponent, Vector3(96, 0, 74))
	for repair in _units(opponent, "RepairRobot"):
		repair.queue_free()
	await _frames(10)
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	_check(_queued(factory) == "RepairRobot", "Growing armor force omitted repair support")
	factory.production_queue.cancel_all()
	tank.queue_free()
	await _frames(5)
	print("PASS: faction armor/infantry counters, rifle screen and repair support")


func _budget_and_technology():
	# Mobile anti-air has no prerequisite; exercise the walker counter instead
	# (Helix answers armor with Lancers, Bastion answers infantry with walkers).
	await _replace_contact("Tank" if opponent.faction == "helix" else "Infantry")
	var prerequisite = _units(opponent, factions.requirement(opponent, "CombatRobot"))[0]
	prerequisite._construction_progress = 0.5
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	_check(_queued(factory) == "Tank", "Counter production bypassed its faction prerequisite")
	factory.production_queue.cancel_all()
	prerequisite._construction_progress = 1.0
	var cost = factions.cost(opponent, "CombatRobot")
	var reserve = factions.cost(opponent, "AntiAirTurret", true)
	opponent.resource_a = cost.resource_a + reserve.resource_a
	opponent.resource_b = cost.resource_b + reserve.resource_b - 1
	opponent._train(_training_units([factory]), "AntiAirTurret")
	_check(factory.production_queue.size() == 0, "Counter consumed reserved building funds")
	opponent.resource_b += 1
	opponent._train(_training_units([factory]), "AntiAirTurret")
	_check(_queued(factory) == "CombatRobot", "Affordable counter failed with exact reserve")
	_check(
		(
			Vector2(opponent.resource_a, opponent.resource_b)
			== Vector2(reserve.resource_a, reserve.resource_b)
		),
		"Counter failed to preserve exact construction reserve"
	)
	factory.production_queue.cancel_all()
	# An unarmed contact isolates routine armor from the armed-drone AA counter.
	await _replace_contact("Worker")
	cost = factions.cost(opponent, "Tank")
	opponent.resource_a = cost.resource_a + reserve.resource_a
	opponent.resource_b = cost.resource_b + reserve.resource_b - 1
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "AntiAirTurret")
	_check(factory.production_queue.size() == 0, "Armor consumed reserved building electronics")
	opponent.resource_b += 1
	opponent._train(_training_units([factory]), "AntiAirTurret")
	_check(_queued(factory) == "Tank", "Exact armor budget failed")
	_check(
		(
			Vector2(opponent.resource_a, opponent.resource_b)
			== Vector2(reserve.resource_a, reserve.resource_b)
		),
		"Armor cost escaped reserve accounting"
	)
	factory.production_queue.cancel_all()
	opponent.resource_a = 500
	opponent.resource_b = 300
	print("PASS: prerequisites, exact counter/build reserve and armor accounting")


func _counter_building():
	await _replace_contact("Helicopter")
	var price = factions.cost(opponent, "AntiAirTurret", true)
	opponent.resource_a = price.resource_a
	opponent.resource_b = price.resource_b - 1
	opponent._build(opponent._units(), "AntiAirTurret")
	_check(_units(opponent, "AntiAirTurret").is_empty(), "AI built unaffordable counter defense")
	opponent.resource_b += 1
	opponent._build(opponent._units(), opponent._next_building(opponent._units()))
	var buildings = _units(opponent, "AntiAirTurret")
	_check(
		buildings.size() == 1 and not buildings[0].is_constructed(),
		"AA priority did not create a paid foundation"
	)
	_check(
		opponent.resource_a == 0 and opponent.resource_b == 0, "AA foundation used incorrect price"
	)
	for worker in _units(opponent, "Worker"):
		if worker != observer:
			# Nanite engineers return to harvesting after beacon placement. Keep
			# this construction-only fixture's wallet free of incidental income.
			worker.manual_orders.submit({"kind": "move", "point": worker.global_position}, true)
			worker.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2400)
	_check(
		buildings.size() == 1 and buildings[0].is_constructed(),
		"AI builder did not complete emergency AA"
	)
	_check(
		opponent.resource_a == 0 and opponent.resource_b == 0,
		"Emergency AA created income or charged twice"
	)
	for worker in _units(opponent, "Worker"):
		worker.process_mode = Node.PROCESS_MODE_DISABLED
	opponent.resource_a = 500
	opponent.resource_b = 300
	print("PASS: unaffordable AA rejection, paid foundation and actual engineer construction")


func _counter_completion():
	await _replace_contact("Helicopter")
	opponent._production_index = 0
	opponent._train(_training_units([factory]), "")
	_check(_queued(factory) == "AntiAirVehicle", "Completion fixture queued wrong counter")
	factory.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(300)
	var jobs = factory.production_queue.get_elements()
	_check(
		jobs.size() == 1 and jobs[0].time_left > 0 and jobs[0].time_left < jobs[0].time_total,
		"Counter job did not advance normally"
	)
	if jobs.is_empty():
		return
	game.hud._toggle_pause()
	var remaining = jobs[0].time_left
	var funds = Vector2(opponent.resource_a, opponent.resource_b)
	var sequence = opponent._production_index
	var clock = game.simulation_time
	await _frames(30)
	_check(jobs[0].time_left == remaining, "Counter production advanced while paused")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Counter queue snapshot failed")
	if snapshot == null:
		return
	var ids = [
		builder._reference(factory), builder._reference(observer), builder._reference(contact)
	]
	var store = FileStore.new()
	var archive_path = "user://ai-composition-%d.json" % OS.get_process_id()
	_check(store.write_file(archive_path, snapshot), "Counter queue archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(archive_path))
	DirAccess.remove_absolute(archive_path)
	_check(loaded.ok, "Counter queue restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	factory = restore.entities[ids[0]]
	observer = restore.entities[ids[1]]
	contact = restore.entities[ids[2]]
	opponent = factory.player
	opponent.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = (
			Node.PROCESS_MODE_INHERIT if unit == factory else Node.PROCESS_MODE_DISABLED
		)
	_check(paused and game.simulation_time == clock, "Counter restore lost paused time")
	_check(
		(
			Vector2(opponent.resource_a, opponent.resource_b) == funds
			and opponent._production_index == sequence
		),
		"Counter restore changed funds or vehicle sequence"
	)
	_check(
		factory.production_queue.get_elements()[0].time_left == remaining,
		"Counter restore changed remaining work"
	)
	_check(
		composition.inventory(opponent._units()).get("AntiAirVehicle", 0) == 1,
		"Restored queue lost planned counter count"
	)
	game.hud._toggle_pause()
	await _frames(1500)
	_check(
		factory.production_queue.size() == 0 and _units(opponent, "AntiAirVehicle").size() == 1,
		"Paid restored counter did not complete exactly once"
	)
	_check(
		Vector2(opponent.resource_a, opponent.resource_b) == funds,
		"Counter completion charged twice"
	)
	var robots = _units(opponent, "AntiAirVehicle")
	if not robots.is_empty():
		await _review_counter(robots[0])
		var hp = contact.hp
		opponent._command_army([robots[0], observer])
		await _frames(2700)
		_check(
			not is_instance_valid(contact) or contact.hp < hp,
			"Newly paid counter failed to intercept observed aircraft"
		)
	print("PASS: paid counter progress, paused archive, retained sequence and exactly one spawn")


func _review_counter(_unit):
	pass
