extends "res://tests/headless/SaveRestoreEdges.gd"

var tech_catalog
var factions
var human
var lab


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		await _research(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Faction-exclusive technology runtime and archives: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn")
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)
	lab = _units(human, "CommandLab")[0]
	human.resource_a = 1000
	human.resource_b = 1000
	paused = true


func _research(faction):
	var research = human.technology
	var branch = tech_catalog.FACTION_TECHNOLOGIES[faction][0]
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var enemy_lab = _units(enemy, "CommandLab")[0]
	_check(not research.enqueue(branch, enemy_lab), "Enemy lab accepted research")
	_check(not research.enqueue(branch, lab), "Faction branch bypassed Coordination")
	for retired in ["weapons_1", "armor_1", "service", "doctrine", "dual_purpose_aa"]:
		_check(
			not research.enqueue(retired, lab),
			"Retired mirrored branch remained purchasable: " + retired
		)
	_check(human.start_coordination(lab), "Coordination purchase refused")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var left = human.coordination_left
	await _frames(30)
	_check(human.coordination_left == left, "Tactical pause advanced Coordination")
	paused = false
	human._physics_process(10.0)
	paused = true
	_check(
		is_equal_approx(human.coordination_left, left - 10.0),
		"Coordination clock ignored production factor"
	)
	_check(human.cancel_coordination(), "Coordination cancellation failed")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(20, 20),
		"Coordination refund differs"
	)
	_check(not human.cancel_coordination(), "Coordination refunded twice")
	_check(human.start_coordination(lab), "Coordination retry refused")
	paused = false
	human._physics_process(30.0)
	paused = true
	_check(human.coordination_unlocked, "Coordination clock never unlocked prerequisites")
	funds = Vector2i(human.resource_a, human.resource_b)
	human.resource_a = 0
	_check(not research.enqueue(branch, lab), "Faction research started without payment")
	human.resource_a = funds.x
	_check(research.enqueue(branch, lab), "Legal faction branch refused: " + branch)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - tech_catalog.cost(branch),
		"Faction research charged the wrong price"
	)
	left = research.left
	await _frames(30)
	_check(research.left == left, "Tactical pause advanced faction research")
	_check(
		research.cancel() and not research.cancel(),
		"Faction research cancellation allowed double refund"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Faction research refund differs")
	_check(research.enqueue(branch, lab), "Faction research retry refused")
	await _brownout_and_archive(branch)
	_check(branch in human.technology.completed, "Restored faction branch did not complete")
	_effect(faction)
	var pair = tech_catalog.EXCLUSIVE_PAIRS[factions.IDS.find(faction)]
	_check(human.technology.enqueue(pair[0], lab), "Doctrine reservation refused")
	_check(not human.technology.enqueue(pair[1], lab), "Active rival doctrine was not excluded")
	_complete()
	_check(
		not human.technology.enqueue(pair[1], lab),
		"Completed rival doctrine was not permanently excluded"
	)
	_invalid_archives(branch, pair)
	print(
		"TECHNOLOGY VERIFIED ",
		faction,
		" paid clocks, 25% brownout, lab-loss, archive, doctrine exclusion, real effect"
	)


func _brownout_and_archive(branch):
	var research = human.technology
	var supplies = human.live_units().filter(
		func(unit): return unit.type in ["CommandCenter", "PowerPlant"]
	)
	for supply in supplies:
		supply._construction_progress = .99
	_check(human.production_factor(lab) == .25, "Brownout factor differs from 25%")
	var before = research.left
	paused = false
	research._physics_process(4.0)
	paused = true
	_check(
		is_equal_approx(before - research.left, 1.0),
		"Brownout research clock did not advance at 25%"
	)
	for supply in supplies:
		supply._construction_progress = 1.0
	lab.queue_free()
	await _frames(3)
	before = research.left
	paused = false
	research._physics_process(10.0)
	paused = true
	_check(
		research.left == before and "paused" in research.status(),
		"Lab loss advanced or lost research"
	)
	var saved = Snapshot.new().capture(game)
	var restored = await Restore.new().restore(self, saved)
	_check(restored.ok, "Faction research archive restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return
	game = restored.game
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(
		paused and human.technology.active == branch and human.technology.left == before,
		"Archive changed active research or remaining time"
	)
	lab = load(factions.scene_path(human.faction, "CommandLab")).instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(25, 0, 23)), human, false)
	_complete()


func _complete():
	var research = human.technology
	paused = false
	research._physics_process(research.left + 1.0)
	paused = true
	_check(research.active == "", "Paid faction research did not complete")


func _effect(faction):
	var tank = _units(human, "Tank")[0]
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var rules = load("res://source/match/combat/CombatRules.gd")
	if faction == "bastion":
		var shooter = _units(enemy, "Infantry")[0]
		var upgraded = rules.damage(shooter, tank)
		human.technology.completed.erase("reactive_armor")
		var ordinary = rules.damage(shooter, tank)
		human.technology.completed.append("reactive_armor")
		_check(
			is_equal_approx(upgraded, ordinary * .75),
			"Reactive armor did not deflect real small-arms damage"
		)
	elif faction == "helix":
		_check(tank.shields_max > tank.hp_max, "Helix lost its innate majority shield envelope")
		tank.shields = 0
		var shield = tank.shield_component
		shield.last_damage_time = -INF
		var before = tank.shields
		shield.tick(.5, game.simulation_time, 1.0)
		_check(tank.shields > before, "Harmonic resonators did not restore real shield charge")
	else:
		var salvage = tank.get_node_or_null("BattlefieldSalvage")
		_check(
			salvage != null and "scrap_cannibalization" in human.technology.completed,
			"Frontier salvage trait or researched upgrade missing"
		)


func _invalid_archives(branch, pair):
	var saved = Snapshot.new().capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(
		saved != null and schema.validate(saved),
		"Completed faction technology snapshot is invalid: " + schema.error
	)
	if saved == null:
		return
	for change in ["unknown", "duplicate", "excluded", "paid", "time", "concurrent"]:
		var bad = saved.duplicate(true)
		var state = tech_catalog.empty_state()
		match change:
			"unknown":
				state.completed = ["free_damage"]
			"duplicate":
				state.completed = [branch, branch]
			"excluded":
				state.completed = pair.duplicate()
			"paid", "time", "concurrent":
				state.active = branch
				state.left = tech_catalog.ITEMS[branch].seconds + 1.0 if change == "time" else 20.0
				var cost = tech_catalog.cost(branch)
				state.paid = {
					"resource_a": cost.x + (1 if change == "paid" else 0), "resource_b": cost.y
				}
				if change == "concurrent":
					bad.players[0].coordination_left = 10.0
		bad.players[0].technology = state
		_check(not schema.validate(bad), "Malformed faction technology was accepted: " + change)
