extends "res://tests/headless/SaveRestoreEdges.gd"

var tech_catalog
var factions
var rules
var human
var lab
var tank
var enemy
var base_health
var legacy


func _initialize():
	# Three complete faction research sequences exceed the older two-faction watchdog.
	create_timer(1000).timeout.connect(
		func():
			push_error("Technology regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		if not "technology" in human or human.technology == null:
			_check(false, faction + ": classic RTS technology research is missing")
		else:
			await _research(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Classic RTS technology: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn")
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.repair_service.set_physics_process(false)
	lab = _units(human, "CommandLab")[0]
	tank = _units(human, "Tank")[0]
	base_health = tank.hp_max
	enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	human.resource_a = 1000
	human.resource_b = 1000
	game.hud._toggle_pause()
	legacy = Snapshot.new().capture(game)


func _research(faction):
	var research = human.technology
	var enemy_lab = _units(enemy, "CommandLab")[0]
	var funds = Vector2i(human.resource_a, human.resource_b)
	_check(not research.start("weapons_1", enemy_lab), "Enemy lab accepted friendly research")
	_check(not research.start("weapons_2", lab), "Tier II bypassed its prerequisites")
	human.resource_a = 0
	_check(not research.start("weapons_1", lab), "Research started without payment")
	human.resource_a = funds.x
	var target = _units(enemy, "Tank")[0]
	var base_damage = rules.damage(tank, target)
	_check(research.start("weapons_1", lab), "Weapon systems I refused")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - tech_catalog.ITEMS.weapons_1.cost,
		"Research price differs"
	)
	_check(
		not research.start("armor_1", lab) and not human.start_coordination(lab),
		"Shared research slot accepted concurrent work"
	)
	var left = research.left
	await _frames(60)
	_check(research.left == left, "Tactical pause advanced research")
	_check(research.cancel() and not research.cancel(), "Research cancellation is not single-use")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		"Research cancellation refund differs"
	)
	_check(research.start("weapons_1", lab), "Weapon research retry refused")
	await _complete()
	_check(
		is_equal_approx(rules.damage(tank, target), base_damage * 1.1),
		"Weapon upgrade did not change real damage"
	)
	var before_hp = target.hp
	target.receive_weapon_hit(tank)
	_check(
		is_equal_approx(before_hp - target.hp, base_damage * 1.1),
		"Upgraded weapon hit used stale damage"
	)
	_check(not research.start("weapons_1", lab), "Completed technology could be bought twice")
	tank.hp = base_health * .4
	var worker = _units(human, "Worker")[0]
	var worker_hp = worker.hp_max
	_check(research.start("armor_1", lab), "Combat armor I refused")
	var factory = _units(human, "VehicleFactory")[0]
	factory.production_queue.fit_chips = false
	var queued = factory.production_queue.produce(load("res://source/match/units/Tank.tscn"))
	_check(queued != null, "Future upgraded tank could not be paid")
	await _complete()
	_check(
		is_equal_approx(tank.hp_max, base_health * 1.1),
		"Existing tank maximum health was not upgraded"
	)
	_check(
		is_equal_approx(tank.hp / tank.hp_max, .4),
		"Armor research changed the existing health percentage"
	)
	_check(worker.hp_max == worker_hp, "Combat armor changed a noncombat engineer")
	var produced = _units(human, "Tank")[-1]
	_check(
		is_equal_approx(produced.hp_max, base_health * 1.1),
		"Newly produced tank lost the army upgrade"
	)
	_check(
		is_equal_approx(rules.damage(produced, target), base_damage * 1.1),
		"Newly produced tank lost weapon research"
	)
	_check(human.start_coordination(lab), "Coordination refused its ordinary research slot")
	_check(not research.start("service", lab), "Technology bypassed active Coordination")
	game.hud._toggle_pause()
	for frame in 2400:
		await physics_frame
		if human.coordination_unlocked:
			break
	game.hud._toggle_pause()
	_check(human.coordination_unlocked, "Paid Coordination never completed")
	_check(research.start("weapons_2", lab), "Unlocked Weapon systems II refused")
	await _complete()
	_check(
		is_equal_approx(rules.damage(tank, target), base_damage * 1.2),
		"Weapon levels compounded instead of totaling 20%"
	)
	if not await _power_and_archive():
		return
	research = human.technology
	_check(is_equal_approx(tank.hp_max, base_health * 1.2), "Restored armor II did not complete")
	await _service()
	await _doctrine(faction)
	await _invalid_and_legacy()
	print(
		"TECHNOLOGY VERIFIED ",
		faction,
		" weapon, armor, service, doctrine, production, costs and archives"
	)


func _complete():
	_check(paused, "Research completion fixture was not paused")
	game.hud._toggle_pause()
	for frame in 4200:
		await physics_frame
		if human.technology.active == "":
			break
	game.hud._toggle_pause()
	_check(human.technology.active == "", "Paid research never completed")


func _power_and_archive():
	var research = human.technology
	_check(research.start("armor_2", lab), "Unlocked Combat armor II refused")
	var supplies = plan_units().filter(
		func(unit): return unit.type in ["CommandCenter", "PowerPlant"]
	)
	for unit in supplies:
		unit._construction_progress = .99
	_check(human.production_factor() == .35, "Low-power fixture still has full supply")
	var before = research.left
	game.hud._toggle_pause()
	await _frames(60)
	game.hud._toggle_pause()
	_check(absf(before - research.left - .35) < .04, "Low-power research did not run at 35% speed")
	for unit in supplies:
		unit._construction_progress = 1
	lab.queue_free()
	await _frames(3)
	before = research.left
	game.hud._toggle_pause()
	await _frames(120)
	game.hud._toggle_pause()
	_check(research.left == before, "Research advanced without a lab")
	_check("paused" in research.status(), "Lost lab is not explained")
	var builder = Snapshot.new()
	var saved = builder.capture(game)
	var tank_id = builder._reference(tank)
	var health = tank.hp
	var file = "user://technology-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, saved), "Technology disk save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Technology disk restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return false
	game = loaded.game
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	tank = restore.entities[tank_id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.repair_service.set_physics_process(false)
	_check(paused and human.technology.left == before, "Restored research lost its remaining time")
	_check(
		is_equal_approx(tank.hp, health) and is_equal_approx(tank.hp_max, base_health * 1.1),
		"Restored upgrade stacked or healed the tank"
	)
	lab = _spawn_tech("CommandLab", human, Vector3(25, 0, 23))
	await _complete()
	return true


func _service():
	var depot = _units(human, "RepairDepot")[0]
	for robot in _units(human, "RepairRobot"):
		robot.queue_free()
	await _frames(3)
	tank.position = depot.position + Vector3(3.5, 0, 0)
	tank.issue_manual_order(null)
	tank.get_node("Movement").velocity = Vector3.ZERO
	tank.last_enemy_damage_time = -INF
	tank.hp = tank.hp_max * .3
	var health = tank.hp
	paused = false
	game.repair_service.service(1.0)
	paused = true
	var ordinary = tank.hp - health
	_check(ordinary > 0, "Service fixture did not heal")
	_check(human.technology.start("service", lab), "Field service research refused")
	await _complete()
	tank.hp = tank.hp_max * .3
	health = tank.hp
	paused = false
	game.repair_service.service(1.0)
	paused = true
	_check(
		is_equal_approx(tank.hp - health, ordinary * 1.25),
		"Field service did not change actual healing"
	)


func _doctrine(faction):
	var unit = (
		tank if faction == "bastion" else _spawn_tech("CombatRobot", human, Vector3(30, 0, 40))
	)
	unit.issue_manual_order(null)
	unit.get_node("Movement").velocity = Vector3.ZERO
	# Hold weapons during the timed research comparison; signatures keep ticking.
	for friendly in plan_units():
		if friendly.action != null:
			friendly.action.process_mode = Node.PROCESS_MODE_DISABLED
	var target = _spawn_tech("Tank", enemy, unit.position + Vector3(3, 0, 0))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	_check(
		human.signatures.activate([unit], unit.position) == 1,
		"Coordination did not unlock the faction ability"
	)
	if faction == "bastion":
		game.hud._toggle_pause()
		await _frames(180)
		game.hud._toggle_pause()
		_check(
			is_equal_approx(unit.signature.damage_factor(), .85),
			"Ordinary Anchor reduction differs"
		)
	elif faction == "frontier":
		_check(
			is_equal_approx(unit.signature.speed_factor(), 1.35), "Ordinary Maneuver speed differs"
		)
	else:
		_check(
			is_equal_approx(unit.signature.preparation_time(.75), .6),
			"Ordinary Precision preparation differs"
		)
	_check(human.technology.start("doctrine", lab), "Faction doctrine research refused")
	await _complete()
	if faction == "bastion":
		_check(
			is_equal_approx(unit.signature.damage_factor(), .75),
			"Fortified Anchor did not strengthen the active ability"
		)
		var hp_before = unit.hp
		unit.receive_weapon_hit(target)
		_check(unit.hp < hp_before, "Fortified Anchor incorrectly makes its unit invulnerable")
	elif faction == "frontier":
		_check(human.signatures.activate([unit]) == 1, "Researched Maneuver could not reactivate")
		_check(
			is_equal_approx(unit.signature.speed_factor(), 1.5),
			"Rapid redeployment did not strengthen actual mobility"
		)
	else:
		game.battlefield.invalidate()
		_check(
			human.signatures.activate([unit], unit.position) == 1,
			"Upgraded Precision could not activate"
		)
		_check(
			is_equal_approx(unit.signature.preparation_time(.75), .375),
			"Accelerated Precision did not strengthen the ability"
		)
		_check(
			unit.signature.preparation_time(.75) == .75,
			"Precision bonus was reused for a second shot"
		)


func _invalid_and_legacy():
	var saved = Snapshot.new().capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(saved), "Completed technology snapshot is invalid: " + schema.error)
	for change in ["unknown", "duplicate", "prerequisite", "paid", "time", "concurrent"]:
		var bad = saved.duplicate(true)
		var state = tech_catalog.empty_state()
		match change:
			"unknown":
				state.completed = ["free_damage"]
			"duplicate":
				state.completed = ["weapons_1", "weapons_1"]
			"prerequisite":
				state.completed = ["armor_2"]
			"paid", "time", "concurrent":
				state.active = "weapons_1"
				state.left = 36 if change == "time" else 20
				state.paid = {"resource_a": 300 if change == "paid" else 30, "resource_b": 20}
				if change == "concurrent":
					bad.players[0].coordination_left = 10
		bad.players[0].technology = state
		_check(not schema.validate(bad), "Malformed technology accepted: " + change)
	if human.faction == "frontier":
		return true  # Frontier did not exist in legacy versions; old factions cover migration.
	legacy.snapshot_version = 6
	legacy.erase("rounds")
	for legacy_unit in legacy.units:
		legacy_unit.projectiles = []
		legacy_unit.erase("air")
	for stance_unit in legacy.units:
		stance_unit.erase("stance")
	legacy.erase("neutral_buildings")
	for ambient in legacy.get("ambient", []):
		ambient.erase("combat")
	legacy.erase("battle_record")
	for resource in legacy.resources:
		resource.erase("wreck")
	for side in legacy.players:
		side.erase("technology")
	var loaded = await Restore.new().restore(self, legacy)
	_check(loaded.ok, "Pre-technology archive no longer loads")
	if not loaded.ok:
		return false
	game = loaded.game
	human = game._get_human_player()
	_check(
		human.technology.completed.is_empty() and human.technology.active == "",
		"Legacy archive invented research"
	)
	_check(_units(human, "Tank")[0].hp_max == base_health, "Legacy archive received free armor")


func plan_units():
	return human.get_children().filter(
		func(unit): return unit.is_in_group("units") and not unit.is_queued_for_deletion()
	)


func _spawn_tech(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
