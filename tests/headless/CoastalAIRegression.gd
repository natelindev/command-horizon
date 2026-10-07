extends "res://tests/headless/FrontierAIRegression.gd"


func _settings(faction, opponent, advanced = true):
	var settings = super(faction, opponent, advanced)
	settings.map_path = "res://source/match/maps/CoastalFoundry.tscn"
	return settings


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	for opponent in factions.IDS:
		await _test_ai(opponent)
	print("Coastal opponent economy/combat: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _test_ai(opponent):
	var game = await _start(_settings("bastion", opponent, false))
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	human.process_mode = Node.PROCESS_MODE_DISABLED
	var hq = _unit(human, "CommandCenter")
	hq.hp = 100000
	await _frames(21600)
	_check(enemy.structures_built >= 3, "Coastal AI did not build its economy")
	_check(enemy.attacks_launched > 0, "Coastal AI never launched an attack")
	_check(game.units_produced > 3, "Coastal AI did not produce reinforcements")
	_check(hq.hp < 100000, "Coastal AI attacks failed to reach and damage the enemy HQ")
	print(
		"Coastal AI ",
		opponent,
		" structures=",
		enemy.structures_built,
		" attacks=",
		enemy.attacks_launched,
		" produced=",
		game.units_produced,
		" HQ damage=",
		100000 - hq.hp
	)
	game.queue_free()
	paused = false
	await _frames(6)
