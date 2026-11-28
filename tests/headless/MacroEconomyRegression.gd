extends "res://tests/headless/ResourceFieldRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	seed(1441)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		var settings = _settings(faction, "bastion", false)
		settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
		game = await _start(settings)
		human = game._get_human_player()
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		workers = get_nodes_in_group("units").filter(
			func(unit): return unit.player == human and unit.type == "Worker"
		)
		for deposit in get_nodes_in_group("resource_units"):
			deposit.queue_free()
		for unit in get_nodes_in_group("units"):
			if unit not in workers:
				unit.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(5)
		var worker = workers[0]
		if "--enable-native-kernels" in OS.get_cmdline_user_args():
			_check(
				(
					worker._native_state != null
					and worker.get_node("Movement")._native_runtime != null
				),
				"Native harvester regression did not bind the native runtime"
			)
		_check(
			worker.resources_max == (8 if faction == "bastion" else 4), faction + " cargo capacity"
		)
		var profile = worker.harvesting_profile
		_check(
			is_equal_approx(
				profile.travel_multiplier, {"bastion": .9, "helix": 1.15, "frontier": 1.0}[faction]
			),
			"Harvester travel profile"
		)
		_check(
			is_equal_approx(profile.collection_interval(2, 1.0), .8 if faction == "helix" else 1.0),
			"Electronics efficiency"
		)
		if faction == "bastion":
			await _mule_and_refinery(worker)
		elif faction == "helix":
			await _phase_delivery(worker)
		else:
			await _scrapper_defense(worker)
		game.queue_free()
		await _frames(5)
	for error in _errors:
		push_error(error)
	print("Macro economy: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _mule_and_refinery(worker):
	_check(worker.hp_max == 120, "Mule Hauler must have 120 hull HP")
	_check(
		factions.cost(human, "ForwardRefinery", true) == {"resource_a": 35, "resource_b": 0},
		"Forward refinery must cost 35 Raw and 0 Refined for deadlock-free bootstrapping"
	)
	worker.hp = 80.0
	worker.last_enemy_damage_time = game.simulation_time
	worker._physics_process(1.0)
	_check(worker.hp == 80.0, "Mule repaired during combat lockout")
	worker.last_enemy_damage_time = game.simulation_time - 6.0
	worker._physics_process(2.0)
	_check(is_equal_approx(worker.hp, 83.0), "Mule passive repair must be 1.5 HP/s")
	var hq = _unit(human, "CommandCenter")
	var refinery = load("res://source/match/units/ForwardRefinery.tscn").instantiate()
	var point = hq.global_position + Vector3(10, 0, 8)
	game._setup_and_spawn_unit(refinery, Transform3D(Basis(), point), human, false)
	await _frames(90)
	_check(refinery.hp_max == 400 and refinery.is_constructed(), "Forward refinery scene defaults")
	_check(harvest.is_applicable(worker, refinery), "Completed refinery rejects friendly hauler")
	_reset_worker(worker, point + Vector3(0, 0, 4))
	_check(
		harvest._find_cc_closest_to_unit(worker) == refinery,
		"Nearest forward drop-off was not chosen"
	)
	var before = human.resource_a
	for trip in 5:
		worker.resource_a = 8
		worker.issue_manual_order(harvest.new(refinery))
		await _until(func(): return worker.resource_a == 0)
		worker.issue_manual_order(null)
	_check(
		human.resource_a == before + 46, "Five Mule loads must preserve the full 15% smelting bonus"
	)
	_check(
		is_zero_approx(refinery.smelting_remainder), "Fractional smelting failed to settle exactly"
	)
	refinery._construction_progress = 0.5
	_check(not harvest.is_applicable(worker, refinery), "Unfinished refinery accepts deliveries")
	refinery._construction_progress = 1.0
	await _saturation(worker, point + Vector3(-5, 0, 0))
	await _industrial_overhaul(hq, point + Vector3(-5, 0, 0))
	await _resource_load_balance(point + Vector3(-5, 0, 0))


func _resource_load_balance(point):
	await _clear()
	var nearby = _deposit("A", point, 8)
	var backlog = _deposit("A", point + Vector3(7, 0, 0), 80)
	nearby.harvest_origin = point
	backlog.harvest_origin = point
	await _frames(5)
	for index in 4:
		_reset_worker(workers[index], point + Vector3(0, 0, 2 + index))
		workers[index].issue_manual_order(harvest.new(nearby))
	_check(
		workers.slice(0, 3).all(func(worker): return worker.action.get_resource_unit() == backlog),
		"Field assignment ignored the longer-lived pile's work backlog"
	)
	_check(
		workers[3].action.get_resource_unit() == nearby,
		"Backlog balancing overbooked the three-slot node"
	)
	await _clear()


func _saturation(worker, point):
	var deposit = _deposit("A", point, 200)
	while workers.size() < 4:
		var additional = load(Catalog.scene_path("Worker")).instantiate()
		game._setup_and_spawn_unit(additional, Transform3D(Basis(), point), human, false)
		workers.append(additional)
	await _frames(90)
	for index in workers.size():
		_reset_worker(workers[index], point + Vector3(0, 0, 1.2 + index * 1.4))
		workers[index].issue_manual_order(harvest.new(deposit))
	_check(
		is_equal_approx(workers[0].action.gathering_efficiency(deposit), 1.0),
		"First harvester efficiency"
	)
	_check(
		is_equal_approx(workers[1].action.gathering_efficiency(deposit), 1.0),
		"Second harvester efficiency"
	)
	_check(
		is_equal_approx(workers[2].action.gathering_efficiency(deposit), .6),
		"Third harvester must gather at 60%"
	)
	_check(workers[3].action._waiting_reason == harvest.Wait.SLOT, "Fourth harvester must wait")
	var saturation = deposit.saturation_info(human)
	_check(
		saturation.workers == 4 and saturation.optimal == 2,
		"Field saturation counter must include waiting workers"
	)
	worker.issue_manual_order(null)
	await _frames(40)
	_check(
		workers[3].action.holds_harvest_slot(deposit),
		"Waiting harvester did not acquire released slot"
	)
	print("MACRO Bastion scenarios complete")


func _phase_delivery(worker):
	var hq = _unit(human, "CommandCenter")
	await _flux_resonance(hq)
	_reset_worker(worker, hq.global_position + Vector3(16, 0, 4))
	worker.resource_b = 4
	var origin = worker.global_position
	var before = human.resource_b
	worker.issue_manual_order(harvest.new(hq))
	_check(
		worker.action._state == harvest.State.PHASE_RETURN,
		"Full Flux Skimmer did not channel phase return"
	)
	await _frames(25)
	_check(
		(
			worker.resource_b == 4
			and worker.global_position_yless.distance_to(origin * Vector3(1, 0, 1)) < .1
		),
		"Phase delivery moved or unloaded before channel completion"
	)
	paused = true
	var left = worker.action._phase_left
	await _frames(20)
	_check(
		worker.action._phase_left == left and human.resource_b == before,
		"Paused phase channel advanced"
	)
	paused = false
	await _until(func(): return worker.resource_b == 0, 100)
	_check(human.resource_b == before + 4, "Phase delivery failed to credit cargo exactly once")
	_check(
		worker.global_position.distance_to(hq.global_position) < hq.radius + 5.0,
		"Phase delivery failed to land at HQ"
	)
	_check(
		worker.action._waiting_reason == harvest.Wait.DELIVERED,
		"Explicit phase delivery did not finish in delivered state"
	)
	# Cancelled channels never deliver from a detached action.
	worker.resource_b = 0
	worker.resource_a = 4
	worker.global_position = origin
	worker.issue_manual_order(harvest.new(hq))
	await _frames(15)
	worker.issue_manual_order(null)
	await _frames(80)
	_check(
		(
			worker.resource_a == 4
			and worker.global_position_yless.distance_to(origin * Vector3(1, 0, 1)) < .1
		),
		"Cancelled phase channel still teleported or consumed cargo"
	)
	worker.resource_a = 0
	worker.resource_b = 4
	worker.issue_manual_order(harvest.new(hq))
	hq.queue_free()
	await _frames(5)
	_check(
		worker.resource_b == 4 and worker.action._waiting_reason == harvest.Wait.HQ,
		"Destroyed phase destination lost cargo"
	)
	print("MACRO Helix scenarios complete")


func _scrapper_defense(worker):
	_check(
		worker.has_node("HarvesterDefense") and worker.attack_damage > 0,
		"Scrapper lacks defensive autocannon"
	)
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	var point = Vector3(20, 0, 20)
	var deposit = _deposit("A", point, 100)
	_reset_worker(worker, point + Vector3(0, 0, 1.25))
	worker.issue_manual_order(harvest.new(deposit))
	var soldier = load(Catalog.scene_path("Infantry")).instantiate()
	game._setup_and_spawn_unit(
		soldier, Transform3D(Basis(), point + Vector3(4, 0, 1)), enemy, false
	)
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	var before = soldier.hp
	var assignment = worker.action
	await _frames(180)
	_check(
		not is_instance_valid(soldier) or soldier.hp < before,
		"Scrapper autocannon failed to defend while harvesting"
	)
	_check(
		worker.action == assignment and worker.action.has_method("harvest_status"),
		"Defensive fire replaced harvest assignment"
	)
	_check(
		worker.resource_a > 0 or human.resource_a > 0, "Scrapper defensive fire stalled collection"
	)
	print("MACRO Frontier scenarios complete")


func _industrial_overhaul(hq, point):
	var beacon = _deposit("A", point + Vector3(2, 0, 0), 100)
	var same_field = _deposit("B", point + Vector3(12, 0, 0), 100)
	var other_field = _deposit("A", point + Vector3(3, 0, 0), 100)
	beacon.harvest_origin = point
	same_field.harvest_origin = point
	other_field.harvest_origin = point + Vector3(0, 0, 20)
	await _frames(5)
	_check(
		hq.abilities.trigger("industrial_overhaul", beacon.global_position),
		"Industrial Overhaul failed on an observed field"
	)
	_check(
		is_equal_approx(human.harvesting_factor(beacon), 1.3),
		"Industrial Overhaul failed to boost the selected resource"
	)
	_check(
		is_equal_approx(human.harvesting_factor(same_field), 1.3),
		"Industrial Overhaul missed a distant node in the same field"
	)
	_check(
		is_equal_approx(human.harvesting_factor(other_field), 1.0),
		"Industrial Overhaul leaked into an adjacent field"
	)
	beacon.queue_free()
	await _frames(5)
	_check(
		is_equal_approx(human.harvesting_factor(same_field), 1.3),
		"Industrial Overhaul ended when its original deposit was exhausted"
	)
	_check(
		not hq.abilities.trigger("industrial_overhaul", same_field.global_position),
		"Industrial Overhaul ignored its 60-second cooldown"
	)
	human._physics_process(30.0)
	_check(
		is_equal_approx(human.harvesting_factor(same_field), 1.0),
		"Industrial Overhaul did not expire after 30 seconds"
	)


func _flux_resonance(hq):
	var factory = load(Catalog.scene_path("VehicleFactory")).instantiate()
	game._setup_and_spawn_unit(factory, Transform3D(Basis(), Vector3(28, 0, 32)), human, false)
	await _frames(5)
	var base = human.production_factor(factory)
	hq.energy = 50.0
	var logistics = human.logistics
	var deposit = _deposit("A", Vector3(35, 0, 32), 10)
	_check(
		not hq.abilities.trigger("flux_resonance", Vector3.INF, deposit),
		"Flux Resonance accepted a resource instead of a production facility"
	)
	_check(is_equal_approx(hq.energy, 50.0), "Invalid Flux target consumed Nexus Energy")
	deposit.queue_free()
	_check(
		hq.abilities.trigger("flux_resonance", Vector3.INF, factory),
		"Flux Resonance failed on a friendly production facility"
	)
	_check(
		is_equal_approx(hq.energy, 25.0) and human.logistics == logistics,
		"Flux Resonance must consume 25 Nexus Energy without spending Logistics"
	)
	_check(
		is_equal_approx(human.production_factor(factory), base * 1.5),
		"Flux Resonance did not accelerate the targeted facility by 50%"
	)
	var job = factory.production_queue.produce(load(factions.scene_path("helix", "Tank")))
	_check(job != null, "Flux production fixture did not queue a unit")
	if job != null:
		var remaining = job.time_left
		factory.production_queue._process(1.0)
		_check(
			is_equal_approx(remaining - job.time_left, base * 1.5),
			"Production queue ignored Flux Resonance's work rate"
		)
		factory.production_queue.cancel_all()
	hq.energy = 24.0
	hq.abilities.get_ability("flux_resonance").cooldown_left = 0.0
	_check(
		not hq.abilities.trigger("flux_resonance", Vector3.INF, factory),
		"Insufficient Nexus Energy still cast Flux Resonance"
	)
	_check(is_equal_approx(hq.energy, 24.0), "Rejected Flux Resonance consumed Nexus Energy")
	hq._physics_process(2.0)
	_check(is_equal_approx(hq.energy, 25.0), "Nexus Energy did not regenerate at 0.5 per second")
	hq.energy = 99.5
	hq._physics_process(20.0)
	_check(is_equal_approx(hq.energy, 100.0), "Nexus Energy exceeded its capacity")
	human._physics_process(25.0)
	_check(
		is_equal_approx(human.production_factor(factory), base), "Flux Resonance failed to expire"
	)
	await _flux_research(hq)
	factory.queue_free()
	await _frames(5)


func _flux_research(hq):
	var lab = load(Catalog.scene_path("CommandLab")).instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(34, 0, 32)), human, false)
	var generator = load(Catalog.scene_path("PowerPlant")).instantiate()
	game._setup_and_spawn_unit(generator, Transform3D(Basis(), Vector3(34, 0, 24)), human, false)
	await _frames(5)
	human.coordination_unlocked = true
	human.resource_a = 100
	human.resource_b = 100
	var base = human.production_factor(lab)
	hq.energy = 50.0
	hq.abilities.get_ability("flux_resonance").cooldown_left = 0.0
	_check(
		hq.abilities.trigger("flux_resonance", Vector3.INF, lab),
		"Flux Resonance rejected a friendly research lab"
	)
	_check(human.technology.start("plasma_shields", lab), "Flux research fixture could not be paid")
	var before = human.technology.left
	human.technology._physics_process(1.0)
	_check(
		is_equal_approx(before - human.technology.left, base * 1.5),
		"Research ignored Flux Resonance's 50% work-rate boost"
	)
	human.technology.cancel()
	lab.queue_free()
	generator.queue_free()
	await _frames(5)
