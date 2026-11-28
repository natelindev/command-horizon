# gdlint: disable=duplicated-load
extends "res://tests/headless/ResourceFieldRegression.gd"

## End-to-end headless regression for v2 Risk-the-Batch Refining:
## - 0-Refined bootstrap costs and unified Raw skirmish fields
## - Bastion Industrial Smelter batches, Field-Fed, Overpressure, Abort, Surge & Spill
## - Helix Phase Condenser spacing, T1-T4 discharge, Brownout Grace, Lattice & EMP Spill
## - Frontier Crack-Rig deploy/pack, Hot-Zone, Fuel Inject, Tech-Wreck stripping & Fence
## - Deterministic MatchSnapshot v23 save/restore round-trip


func _run():
	Engine.physics_ticks_per_second = 60
	seed(2701)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false

	await _test_bastion_smelting()
	await _test_helix_condensing()
	await _test_frontier_crack_rig_and_wrecks()
	await _test_snapshot_roundtrip()

	for error in _errors:
		push_error(error)
	print("Refining economy: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _setup_skirmish(faction: String, enemy_faction: String = "bastion"):
	var settings = _settings(faction, enemy_faction, false)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(5)
	return game


func _test_bastion_smelting():
	await _setup_skirmish("bastion", "frontier")
	# Unified Raw skirmish fields: zero ResourceB piles remain.
	var electronics_piles = get_nodes_in_group("resource_units").filter(
		func(d): return "resource_b" in d
	)
	_check(electronics_piles.is_empty(), "Skirmish map still contains legacy ResourceB piles")
	_check(
		factions.cost(human, "ForwardRefinery", true) == {"resource_a": 35, "resource_b": 0},
		"Bastion Industrial Smelter must cost 35 Raw / 0 Refined"
	)
	var hq = _unit(human, "CommandCenter")
	var power_plant = load("res://source/match/units/PowerPlant.tscn").instantiate()
	var smelter = load("res://source/match/units/ForwardRefinery.tscn").instantiate()
	var factory = load("res://source/match/units/VehicleFactory.tscn").instantiate()
	var origin = hq.global_position + Vector3(8.0, 0.0, 0.0)
	game._setup_and_spawn_unit(
		power_plant,
		Transform3D(Basis(), hq.global_position + Vector3(-6.0, 0.0, 0.0)),
		human,
		false
	)
	game._setup_and_spawn_unit(smelter, Transform3D(Basis(), origin), human, false)
	game._setup_and_spawn_unit(
		factory, Transform3D(Basis(), origin + Vector3(5.0, 0.0, 0.0)), human, false
	)
	await _frames(5)

	var ref = smelter.get_node("Refining")
	_check(ref != null and ref.mode == "bastion", "Smelter missing bastion RefiningComponent")
	ref.auto_cycle = false
	ref.active = false
	ref.elapsed = 0.0
	human.resource_a = 200
	human.resource_b = 0
	# Super-heavy locked until pressurized_furnaces.
	_check(not ref.set_batch_tier("super_heavy"), "Super-heavy batch unlocked before research")
	_check(ref.set_batch_tier("standard"), "Standard batch failed to start")
	_check(ref.active and human.resource_a == 170, "Standard batch did not lock 30 Raw upfront")

	# Field-Fed + Overpressure power draw & speed.
	var power_before = human.power_totals()
	_check(ref.toggle_overpressure(), "Overpressure toggle failed")
	_check(human.power_totals().y == power_before.y + 4, "Overpressure must draw +4 extra Power")
	smelter.refine_materials(8)
	_check(ref.is_field_fed(), "Delivering to Smelter must trigger Field-Fed bonus")

	# Complete standard batch and verify payout + Slag Recirculation surge.
	human.technology.completed.append("slag_recirculation")
	ref._physics_process(20.0)
	_check(human.resource_b == 12, "Standard batch did not award 12 Refined Cores")
	_check(
		is_equal_approx(game.refining_manager.production_factor(factory), 1.25),
		"Slag Heat Recirculation did not surge adjacent factory by +25%"
	)
	_check(ref.overpressure_cooldown > 0.0, "Overpressure did not enter cooldown after batch")

	# Pressurized Blast Furnaces: 80% abort refund + Super-Heavy batch.
	human.technology.completed.append("pressurized_furnaces")
	human.resource_a = 150
	ref.auto_cycle = false
	ref.active = false
	_check(ref.set_batch_tier("super_heavy"), "Super-heavy batch failed after Pressurized Furnaces")
	_check(human.resource_a == 50, "Super-heavy batch did not lock 100 Raw")
	_check(ref.abort_batch(), "Emergency Slag Dump abort failed")
	_check(human.resource_a == 130, "Pressurized abort must refund 80% Raw (80)")

	# Mid-batch destruction rupture + 45% Refined Core canister spill + enemy heist pickup!
	human.resource_a = 150
	_check(ref.set_batch_tier("heavy"), "Heavy batch failed to start")
	ref.elapsed = 15.0  # 50% cooked -> 15 accrued Refined -> floor(15 * 0.45) = 6 Refined spill
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	var raider = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(
		raider, Transform3D(Basis(), origin + Vector3(0.0, 0.0, 2.0)), enemy, false
	)
	await _frames(3)
	var enemy_before_b = enemy.resource_b
	var raider_before_hp = raider.hp
	smelter.hp = 0.0
	await _frames(3)
	_check(
		not is_instance_valid(raider) or raider.hp < raider_before_hp,
		"Smelter mid-batch rupture did not damage nearby unit"
	)
	_check(
		not game.refining_manager.canisters.is_empty(),
		"Destroyed cooking Smelter did not spill Refined Core canisters"
	)
	if not game.refining_manager.canisters.is_empty():
		var canister = game.refining_manager.canisters[0].node
		var thief = load("res://source/match/units/Tank.tscn").instantiate()
		game._setup_and_spawn_unit(thief, Transform3D(Basis(), canister.position), enemy, false)
		await _frames(3)
		_check(
			game.refining_manager.collect(canister, thief, 0.6),
			"Enemy ground unit failed to claim spilled Refined Core canister"
		)
		_check(
			enemy.resource_b > enemy_before_b,
			"Claiming spilled canister did not credit enemy Refined Cores"
		)
	game.queue_free()
	await _frames(5)
	print("REFINING Bastion scenarios complete")


func _test_helix_condensing():
	await _setup_skirmish("helix", "bastion")
	_check(
		factions.cost(human, "PhaseCondenser", true) == {"resource_a": 35, "resource_b": 0},
		"Helix Phase Condenser must cost 35 Raw / 0 Refined"
	)
	var hq = _unit(human, "CommandCenter")
	var power_plant = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(
		power_plant,
		Transform3D(Basis(), hq.global_position + Vector3(-6.0, 0.0, 0.0)),
		human,
		false
	)
	var c1 = load("res://source/match/units/PhaseCondenser.tscn").instantiate()
	var p1 = hq.global_position + Vector3(8.0, 0.0, 0.0)
	game._setup_and_spawn_unit(c1, Transform3D(Basis(), p1), human, false)
	await _frames(5)

	# 8 m minimum spacing validation.
	_check(
		not game.refining_manager.condenser_spacing_ok(human, p1 + Vector3(5.0, 0.0, 0.0)),
		"Phase Condenser spacing allowed placement inside 8 m"
	)
	_check(
		game.refining_manager.condenser_spacing_ok(human, p1 + Vector3(10.0, 0.0, 0.0)),
		"Phase Condenser spacing rejected valid 10 m site"
	)

	var ref1 = c1.get_node("Refining")
	human.resource_a = 300
	human.resource_b = 0
	ref1.set_target_tier(2)
	# Tick 30s at 2 Raw/s -> Tier 2 auto-discharge (32 Refined).
	for _step in 30:
		ref1._physics_process(1.0)
	_check(human.resource_b == 32, "Phase Condenser T2 discharge must award 32 Refined")

	# Brownout bleed-off vs Fail-Safe Capacitor 6s grace buffer.
	human.technology.completed.append("failsafe_capacitors")
	ref1.set_target_tier(3)
	for _step in 20:
		ref1._physics_process(1.0)
	power_plant.hp = 0.0
	await _frames(2)
	# Force brownout by adding a high-demand lab.
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(
		lab, Transform3D(Basis(), hq.global_position + Vector3(0.0, 0.0, -8.0)), human, false
	)
	await _frames(2)
	_check(human.is_brownout(), "Helix test fixture failed to enter brownout")
	var before_brownout = ref1.charge_seconds
	ref1._physics_process(4.0)
	_check(
		ref1.grace_active and is_equal_approx(ref1.charge_seconds, before_brownout),
		"Fail-Safe Capacitors did not preserve charge during 6s brownout grace window"
	)

	# Restore power, link a 2nd condenser with harmonic_lattice -> Tier 4!
	var gen2 = load("res://source/match/units/PowerPlant.tscn").instantiate()
	game._setup_and_spawn_unit(
		gen2, Transform3D(Basis(), hq.global_position + Vector3(-6.0, 0.0, -6.0)), human, false
	)
	var c2 = load("res://source/match/units/PhaseCondenser.tscn").instantiate()
	game._setup_and_spawn_unit(c2, Transform3D(Basis(), p1 + Vector3(10.0, 0.0, 0.0)), human, false)
	await _frames(5)
	human.technology.completed.append("harmonic_lattice")
	_check(
		ref1.helix_max_tier() == 4, "Harmonic Lattice did not unlock Tier 4 on linked Condensers"
	)
	var ref2 = c2.get_node("Refining")
	ref2.charge_seconds = 35.0
	var canisters_before = game.refining_manager.canisters.size()
	c1.hp = 0.0
	await _frames(3)
	_check(
		game.refining_manager.canisters.size() > canisters_before,
		"Destroyed charged Phase Condenser did not spill Phase Cores"
	)
	_check(
		ref2.charge_seconds < 35.0,
		"Destroying lattice partner did not shock surviving Condenser down a tier"
	)
	game.queue_free()
	await _frames(5)
	print("REFINING Helix scenarios complete")


func _test_frontier_crack_rig_and_wrecks():
	await _setup_skirmish("frontier", "bastion")
	_check(
		factions.cost(human, "CrackRig", false) == {"resource_a": 28, "resource_b": 0},
		"Frontier Crack-Rig must cost 28 Raw / 0 Refined"
	)
	var hq = _unit(human, "CommandCenter")
	var rig = load("res://source/match/units/CrackRig.tscn").instantiate()
	var deposit = _deposit("A", hq.global_position + Vector3(10.0, 0.0, 0.0), 300)
	game._setup_and_spawn_unit(
		rig, Transform3D(Basis(), deposit.global_position + Vector3(2.0, 0.0, 0.0)), human, false
	)
	await _frames(5)
	var ref = rig.get_node("Refining")
	human.resource_a = 100
	human.resource_b = 0
	_check(ref.deploy(), "Crack-Rig failed to begin deployment")
	_check(ref.is_immobilized(), "Deploying Crack-Rig must be immobilized")
	ref._physics_process(2.0)
	_check(ref.deploy_state == "deployed" and ref.active, "Deployed Crack-Rig did not start batch")
	_check(ref.is_hot_zone(), "Crack-Rig beside Raw field must detect Hot Zone (+40% speed)")
	# 16s / 1.4 = 11.43s -> 12s completes batch.
	ref._physics_process(12.0)
	_check(human.resource_b == 12, "Hot-Zone Crack-Rig did not complete batch in 12s")

	# Exhaust scrubbers quick-pack (0.5s).
	human.technology.completed.append("exhaust_scrubbers")
	_check(ref.pack_up(), "Crack-Rig pack-up failed")
	_check(is_equal_approx(ref.transition_left, 0.5), "Exhaust Scrubbers must cut pack-up to 0.5s")
	ref._physics_process(0.6)
	_check(ref.deploy_state == "mobile", "Crack-Rig did not return to mobile state")

	# Hot Tech Wreck stripping: destroyed Bastion AdvancedTank (40 M / 18 R) -> 7 Refined!
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	var colossus = load(factions.scene_path("bastion", "AdvancedTank")).instantiate()
	var wreck_pos = hq.global_position + Vector3(0.0, 0.0, 8.0)
	game._setup_and_spawn_unit(colossus, Transform3D(Basis(), wreck_pos), enemy, false)
	await _frames(3)
	colossus.hp = 0.0
	await _frames(5)
	var wrecks = get_nodes_in_group("salvage_wrecks")
	_check(not wrecks.is_empty(), "Destroyed AdvancedTank did not leave a Hot Tech Wreck")
	if not wrecks.is_empty():
		var wreck = wrecks[0]
		_check(
			wreck.refined_b == 7, "Bastion Siege Colossus wreck must carry 7 Refined Cores (40%)"
		)
		var worker = _unit(human, "Worker")
		_reset_worker(worker, wreck.global_position + Vector3(0.5, 0.0, 0.0))
		var b_before = human.resource_b
		_check(wreck.dismantle(worker), "Frontier Scrapper failed to dismantle Hot Tech Wreck")
		_check(
			human.resource_b == b_before + 7,
			"Dismantling Hot Tech Wreck did not credit instant Refined Cores"
		)

	# Black Market Fence fallback at Scrap Yard.
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(
		lab, Transform3D(Basis(), hq.global_position + Vector3(-8.0, 0.0, 0.0)), human, false
	)
	await _frames(3)
	human.resource_a = 80
	var b_pre_fence = human.resource_b
	_check(human.fence_exchange(), "Frontier Black Market Fence failed")
	_check(
		human.resource_a == 40 and human.resource_b == b_pre_fence + 10,
		"Fence exchange must convert 40 Raw -> 10 Refined"
	)
	_check(not human.fence_exchange(), "Fence ignored 25s cooldown")
	game.queue_free()
	await _frames(5)
	print("REFINING Frontier scenarios complete")


func _test_snapshot_roundtrip():
	await _setup_skirmish("bastion", "helix")
	var hq = _unit(human, "CommandCenter")
	var smelter = load("res://source/match/units/ForwardRefinery.tscn").instantiate()
	game._setup_and_spawn_unit(
		smelter, Transform3D(Basis(), hq.global_position + Vector3(8.0, 0.0, 0.0)), human, false
	)
	await _frames(5)
	human.resource_a = 150
	var ref = smelter.get_node("Refining")
	ref.set_batch_tier("heavy")
	game.refining_manager.spawn_canisters(
		hq.global_position + Vector3(4.0, 0.0, 4.0), 10, human, false
	)
	await _frames(3)
	paused = true
	ref.elapsed = 12.5
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var saved = snapshot.capture(game)
	paused = false
	_check(
		saved != null and snapshot.error.is_empty(), "Snapshot capture failed: " + snapshot.error
	)
	if saved != null:
		_check(saved.snapshot_version == 23, "Snapshot version must be 23")
		var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
		_check(
			schema.validate(saved), "Snapshot schema rejected v23 refining save: " + schema.error
		)
		game.queue_free()
		await _frames(5)
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var loaded = await restore.restore(self, saved)
		_check(loaded.ok, "MatchRestore failed: " + str(loaded.get("error", "")))
		if loaded.ok:
			game = loaded.game
			var restored_smelters = get_nodes_in_group("units").filter(
				func(u): return u.type == "ForwardRefinery"
			)
			_check(restored_smelters.size() == 1, "Restored match missing Smelter")
			if restored_smelters.size() == 1:
				var r_ref = restored_smelters[0].get_node("Refining")
				_check(
					(
						r_ref.active
						and r_ref.batch_tier == "heavy"
						and is_equal_approx(r_ref.elapsed, 12.5)
					),
					"Restored Smelter lost active batch progress"
				)
			_check(
				game.refining_manager.canisters.size() == 1,
				"Restored match lost spilled Refined Core canister"
			)
			game.queue_free()
			await _frames(5)
	else:
		game.queue_free()
		await _frames(5)
	print("REFINING Snapshot round-trip complete")
