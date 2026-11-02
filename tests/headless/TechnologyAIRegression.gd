extends "res://tests/headless/TechnologyRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _ai_fixture(faction)
		await _ai(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Exclusive technology AI, all three factions: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _ai_fixture(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/CoastalFoundry.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	for player in game.get_cached_group("players"):
		player.set_process(false)
	await _frames(3)
	for unit in game.get_units():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)
	paused = true


func _ai(faction):
	var ai = game.get_cached_group("players")[1]
	ai.coordination_unlocked = true
	ai.resource_a = 1000
	ai.resource_b = 1000
	for unit in ai._units():
		if unit.movement_speed > 0 and unit.attack_range != null:
			unit.hp = unit.hp_max * .1
	ai._research(ai._units(), "")
	_check(ai.technology.active == "", faction + ": researched while lacking healthy guards")
	for unit in ai._units():
		unit.hp = unit.hp_max
	while _units(ai, "Infantry").size() < 6:
		var unit = load(factions.scene_path(faction, "Infantry")).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(80, 0, 70)), ai, false)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var first = ai.profile().research[0]
	var first_price = tech_catalog.cost(first)
	ai.resource_a = first_price.x
	ai.resource_b = first_price.y
	ai._research(ai._units(), "VehicleFactory")
	_check(ai.technology.active == "", faction + ": consumed reserved building funds")
	ai.resource_a = 1000
	ai.resource_b = 1000
	var previous = ai.resource_a
	ai._research(ai._units(), "")
	_check(ai.technology.active == first, faction + ": did not buy its exclusive opening branch")
	_check(
		ai.resource_a == previous - first_price.x and ai.resource_b == 1000 - first_price.y,
		faction + ": research payment differs"
	)
	ai._research(ai._units(), "")
	_check(ai.resource_a == previous - first_price.x, faction + ": bought concurrent technology")
	paused = false
	ai.technology._physics_process((ai.technology.left + 1.0) / ai.research_factor())
	paused = true
	_check(first in ai.technology.completed, faction + ": paid technology never completed")
	_check(
		tech_catalog.available(first, faction), faction + ": bought foreign or mirrored research"
	)
	ai._research(ai._units(), "")
	_check(
		ai.technology.active == ai.profile().research[1],
		faction + ": failed to progress through exclusive tree"
	)
	ai.technology.cancel()
	for unit in ai._units():
		if unit.movement_speed > 0 and unit.attack_range != null:
			unit.hp = unit.hp_max * .1
	ai._research(ai._units(), "")
	_check(ai.technology.active == "", faction + ": research displaced rebuilding wounded guards")
	for unit in ai._units():
		unit.hp = unit.hp_max
	var final = ai.profile().research.back()
	ai.technology.completed = ai.profile().research.filter(func(id): return id != final)
	previous = ai.resource_a
	var electronics = ai.resource_b
	var price = tech_catalog.cost(final)
	ai._research(ai._units(), "")
	_check(ai.technology.active == final, faction + ": omitted its final specialized technology")
	_check(
		ai.resource_a == previous - price.x and ai.resource_b == electronics - price.y,
		faction + ": specialized payment differs"
	)
	ai.technology.cancel()
	for completed in ai.profile().research:
		_check(
			tech_catalog.available(completed, faction),
			faction + ": AI profile includes foreign research"
		)
	print(
		"TECHNOLOGY AI VERIFIED ",
		faction,
		" reserves, healthy guards, payment, completion, exclusive progression"
	)
