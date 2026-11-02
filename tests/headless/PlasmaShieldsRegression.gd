extends "res://tests/headless/TechnologyRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _fixture(faction)
		await _shields(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Innate faction shields, resonators and archives: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _shields(faction):
	var tank = _units(human, "Tank")[0]
	var research = human.technology
	if faction != "helix":
		_check(tank.shields_max == 0.0, faction + " received innate Helix shields")
		human.coordination_unlocked = true
		_check(not research.enqueue("plasma_shields", lab), faction + " purchased Helix resonators")
		return
	var initial = tech_catalog.PLASMA_SHIELDS.Tank
	_check(is_equal_approx(tank.shields, initial), "Innate shield was not equipped fully")
	_check(tank.hp_max < initial, "Helix shields are not the majority of its durability")
	_check(not research.enqueue("plasma_shields", lab), "Resonators bypassed Coordination")
	var attacker = _units(
		get_nodes_in_group("players").filter(func(p): return p != human)[0], "Tank"
	)[0]
	var hull = tank.hp
	tank.receive_damage(attacker, 12.0)
	_check(
		tank.hp == hull and is_equal_approx(tank.shields, initial - 12.0),
		"Innate shield did not absorb damage"
	)
	tank.shields = 0.0
	tank.last_shield_damage_time = game.simulation_time
	game.simulation_time += 4.9
	tank._physics_process(.5)
	_check(tank.shields == 0.0, "Innate shield recharged before five seconds")
	game.simulation_time += .11
	tank._physics_process(.5)
	_check(is_equal_approx(tank.shields, 4.0), "Innate shield recharge differs from 8 HP/s")
	human.coordination_unlocked = true
	var funds = Vector2i(human.resource_a, human.resource_b)
	_check(research.enqueue("plasma_shields", lab), "Resonator research refused")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(40, 25),
		"Resonator price differs"
	)
	var left = research.left
	await _frames(10)
	_check(research.left == left and tank.shields == 4.0, "Paused research or shields advanced")
	_check(research.cancel(), "Resonator cancellation refused")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Resonator refund differs")
	_check(research.enqueue("plasma_shields", lab), "Resonator retry refused")
	_complete()
	_check(is_equal_approx(tank.shields_max, initial * 1.3), "Resonators did not add 30% capacity")
	_check(
		tank.shield_component.recharge_delay == 3.0,
		"Resonators did not reduce delay to three seconds"
	)
	tank.shields = 0.0
	tank.last_shield_damage_time = game.simulation_time
	game.simulation_time += 2.9
	tank._physics_process(.5)
	_check(tank.shields == 0.0, "Resonator delay was skipped")
	game.simulation_time += .11
	tank._physics_process(.5)
	_check(is_equal_approx(tank.shields, 4.0), "Resonator recharge rate changed unexpectedly")
	var builder = Snapshot.new()
	var saved = builder.capture(game)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(saved != null and schema.validate(saved), "Shield archive failed: " + schema.error)
	if saved == null:
		return
	var id = builder._reference(tank)
	var invalid = saved.duplicate(true)
	for unit in invalid.units:
		if unit.id == id:
			unit.plasma_shield.charge = tank.shields_max + 1.0
	_check(not schema.validate(invalid), "Oversized shield accepted in archive")
	var restore = Restore.new()
	var loaded = await restore.restore(self, saved)
	_check(loaded.ok, "Shield restore failed: " + loaded.get("error", ""))
	if loaded.ok:
		game = loaded.game
		tank = restore.entities[id]
		_check(
			is_equal_approx(tank.shields, 4.0) and is_equal_approx(tank.shields_max, initial * 1.3),
			"Restore changed shield capacity or charge"
		)
