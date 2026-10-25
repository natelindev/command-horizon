extends "res://tests/headless/TechnologyRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	for faction in ["bastion", "frontier", "helix"]:
		await _fixture(faction)
		await _shields(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Helix plasma shields: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shields(faction):
	var research = human.technology
	var panel = load("res://source/match/hud/ResearchPanel.gd").new()
	panel.player = human
	panel.lab = lab
	game.hud.add_child(panel)
	_check(
		panel._branches.has("plasma_shields") == (faction == "helix"),
		"Shield research visibility differs for " + faction
	)
	panel.queue_free()
	_check(tank.shields == 0 and tank.shields_max == 0, "Unresearched tank has shields")
	_check(not research.start("plasma_shields", lab), "Shield research bypassed Coordination")
	human.coordination_unlocked = true
	if faction != "helix":
		_check(not research.start("plasma_shields", lab), faction + " purchased Helix research")
		_check(not research.enqueue("plasma_shields", lab), faction + " queued Helix research")
		return
	var funds = Vector2i(human.resource_a, human.resource_b)
	_check(research.start("plasma_shields", lab), "Shield research refused")
	_check(research.left == 40.0, "Shield research duration differs")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(40, 25),
		"Shield research price differs"
	)
	var left = research.left
	await _frames(5)
	_check(research.left == left and tank.shields_max == 0, "Paused research advanced")
	_check(research.cancel(), "Shield research could not be cancelled")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Shield refund differs")
	_check(research.start("plasma_shields", lab), "Shield research retry refused")
	research._physics_process(1000.0)
	_check("plasma_shields" in research.completed, "Shield research did not complete")
	_check(tank.shields == 30 and tank.shields_max == 30, "Existing tank missed full shields")
	_check(not research.start("plasma_shields", lab), "Shield research completed twice")
	_check("30 shield HP" in research.summary("Tank"), "Unit details omit shields")
	var roles = tech_catalog.PLASMA_SHIELDS.duplicate()
	roles.merge({"Worker": 0.0, "RepairRobot": 0.0, "CommandLab": 0.0, "AntiAirTurret": 0.0})
	var spawned = []
	for role in roles:
		var unit = _spawn_tech(role, human, Vector3(30 + spawned.size() % 6 * 3, 0, 35))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		spawned.append(unit)
		var capacity = roles[role]
		_check(unit.shields_max == capacity and unit.shields == capacity, role + " shield capacity")
		if capacity > 0:
			unit.shields = 0.0
			unit.last_shield_damage_time = game.simulation_time - 5.0
			# Calls the concrete role's override, verifying it chains to Unit.
			unit._physics_process(.5)
			_check(is_equal_approx(unit.shields, 3.0), role + " did not recharge at 6 HP/s")
			unit.shields = capacity
	var attacker = _units(enemy, "Tank")[0]
	var hull = tank.hp
	var shield_events = [0]
	tank.shields_changed.connect(func(): shield_events[0] += 1)
	var impacts = game.combat_effects.shield_impacts_emitted
	tank.receive_damage(attacker, 12.0)
	_check(tank.hp == hull and tank.shields == 18, "Shield failed to absorb damage before hull")
	_check(shield_events[0] == 1, "Shield absorption omitted change signal")
	_check(game.combat_effects.shield_impacts_emitted == impacts + 1, "Missing shield impact")
	research.apply_unit(tank)
	_check(tank.shields == 18, "Reapplying research refilled shields")
	tank.receive_damage(attacker, 20.0)
	_check(tank.shields == 0 and tank.hp == hull - 2, "Shield overflow damage differs")
	game.simulation_time += 4.9
	tank._physics_process(.5)
	_check(tank.shields == 0, "Shield recharged before five seconds")
	tank.receive_damage(attacker, 1.0)
	game.simulation_time += .2
	tank._physics_process(.5)
	_check(tank.shields == 0, "Hull hit failed to reset depleted shield delay")
	game.simulation_time += 4.8
	tank._physics_process(.5)
	_check(is_equal_approx(tank.shields, 3.0), "Shield failed to recharge at five seconds")
	tank._physics_process(100.0)
	_check(tank.shields == 30.0, "Recharge exceeded capacity")
	tank.process_mode = Node.PROCESS_MODE_PAUSABLE
	tank.receive_damage(attacker, 7.0)
	var now = game.simulation_time
	await _frames(10)
	_check(tank.shields == 23.0 and game.simulation_time == now, "Paused shield state advanced")
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	for unit in spawned:
		unit.queue_free()
	await _frames(3)
	tank.get_node("Selection").select()
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	menus._refresh_health()
	_check(menus._shields.visible and menus._shields.value == 23.0, "HUD omitted shield charge")
	_check(menus._shields.max_value == 30.0, "HUD shield maximum differs")
	await _shield_archive()


func _shield_archive():
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Shield snapshot capture failed: " + builder.error)
	if snapshot == null:
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(snapshot), "Shield snapshot rejected: " + schema.error)
	var id = builder._reference(tank)
	var invalid = snapshot.duplicate(true)
	invalid.units[0] = null
	_check(not schema.validate(invalid), "Malformed unit accepted in shield archive")
	invalid = snapshot.duplicate(true)
	for saved in invalid.units:
		if saved.id == id:
			saved.plasma_shield.charge = 31.0
	_check(not schema.validate(invalid), "Oversized shield accepted in archive")
	invalid = snapshot.duplicate(true)
	invalid.players[1].technology.completed.append("plasma_shields")
	invalid.players[1].coordination_unlocked = true
	_check(not schema.validate(invalid), "Non-Helix shield technology accepted in archive")
	var restore = Restore.new()
	var loaded = await restore.restore(self, snapshot)
	_check(loaded.ok, "Shield restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	tank = restore.entities[id]
	_check(tank.shields == 23.0 and tank.shields_max == 30.0, "Restore changed shield charge")
	_check(
		is_equal_approx(game.simulation_time - tank.last_shield_damage_time, 0.0),
		"Restore changed shield recharge delay"
	)
