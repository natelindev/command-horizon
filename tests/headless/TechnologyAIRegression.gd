extends "res://tests/headless/TechnologyRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	for faction in ["bastion", "helix"]:
		await _fixture("helix" if faction == "bastion" else "bastion")
		await _ai(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Technology AI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _ai(faction):
	var ai = enemy
	ai.coordination_unlocked = true
	ai.resource_a = 1000
	ai.resource_b = 1000
	for unit in ai._units():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	ai._research(ai._units(), "")
	_check(ai.technology.active == "", "AI researched while lacking a field army")
	while _units(ai, "Infantry").size() < 6:
		var unit = _spawn_tech("Infantry", ai, Vector3(80, 0, 70))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	ai.resource_a = 30
	ai.resource_b = 20
	ai._research(ai._units(), "AircraftFactory")
	_check(ai.technology.active == "", "Research consumed reserved building funds")
	ai.resource_a = 1000
	ai.resource_b = 1000
	var previous = ai.resource_a
	ai._research(ai._units(), "")
	_check(ai.technology.active == "weapons_1", "Ready AI did not buy Weapon systems I")
	_check(ai.resource_a == previous - 30 and ai.resource_b == 980, "AI research payment differs")
	ai._research(ai._units(), "")
	_check(ai.resource_a == previous - 30, "AI bought concurrent technology")
	paused = false
	for frame in 2400:
		await physics_frame
		if ai.technology.active == "":
			break
	paused = true
	_check("weapons_1" in ai.technology.completed, "Paid AI technology never completed")
	_check(ai.technology.damage_factor("Tank") == 1.1, "AI did not receive its paid damage bonus")
	ai._research(ai._units(), "")
	_check(ai.technology.active == "armor_1", "AI did not progress to armor research")
	ai.technology.cancel()
	for unit in _units(ai, "Infantry"):
		unit.hp = unit.hp_max * .1
	ai._research(ai._units(), "")
	_check(ai.technology.active == "", "Research displaced rebuilding a wounded army")
	for unit in _units(ai, "Infantry"):
		unit.hp = unit.hp_max
	ai.technology.completed = tech_catalog.ITEMS.keys().filter(
		func(id): return id != "dual_purpose_aa"
	)
	previous = ai.resource_a
	var electronics = ai.resource_b
	ai._research(ai._units(), "")
	_check(ai.technology.active == "dual_purpose_aa", "AI never researches Dual-purpose AA")
	_check(
		ai.resource_a == previous - 40 and ai.resource_b == electronics - 30,
		"AI Dual-purpose AA payment differs"
	)
	ai.technology.cancel()
	print("TECHNOLOGY AI VERIFIED ", faction)
