extends "res://tests/headless/FactionAsymmetryRegression.gd"


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture("helix" if faction == "bastion" else "bastion")
		enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		enemy.faction = faction
		enemy.coordination_unlocked = true
		var strategy = load("res://source/match/players/skirmish-ai/%sStrategy.gd" % faction.capitalize())
		var profile = enemy.profile()
		for id in profile.research:
			_check(load("res://source/match/research/TechnologyCatalog.gd").available(id, faction), "Strategy researches a foreign or mirrored branch")
		if faction == "bastion":
			await _bastion(strategy)
		elif faction == "helix":
			await _helix(strategy)
		else:
			await _frontier(strategy)
		game.queue_free()
		await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Faction strategic AI archetypes: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _bastion(strategy):
	var headquarters = _units(enemy, "CommandCenter")[0]
	var forward = _dedicated("ForwardRefinery", Vector3(26, 0, 30), enemy)
	var siege = _dedicated("AdvancedTank", Vector3(32, 0, 32), enemy)
	var target = _dedicated("Tank", Vector3(38, 0, 32), human)
	await _frames(2)
	var outpost = strategy.outpost([headquarters, forward])
	_check(outpost.get("role") == "AntiGroundTurret" and outpost.get("origin") == forward.global_position, "Bastion did not fortify its forward economic outpost")
	siege.get_node("Movement")._has_destination = true
	var claimed = strategy.command(game, enemy, [siege], [target])
	_check(siege in claimed and not siege.get_node("Movement")._has_destination, "Bastion did not stop its siege line for deployment")
	_check(enemy.profile().first_wave > load("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd").of(enemy.difficulty).first_wave, "Bastion retained mirrored raid timing")


func _helix(strategy):
	var skimmer = _dedicated("Tank", Vector3(32, 0, 32), enemy)
	var threat = _dedicated("Tank", Vector3(37, 0, 32), human)
	await _frames(2)
	skimmer.global_position = Vector3(32, 0, 32)
	threat.global_position = Vector3(37, 0, 32)
	skimmer.shields = skimmer.shields_max * 0.2
	var claimed = strategy.command(game, enemy, [skimmer], [threat])
	_check(skimmer in claimed and skimmer.get_meta("shield_withdrawing", false), "Helix did not disengage when its shields collapsed")
	_check(skimmer.action._target_position.x < skimmer.global_position.x, "Helix shield retreat approached its pursuer")
	skimmer.shields = skimmer.shields_max * 0.8
	claimed = strategy.command(game, enemy, [skimmer], [])
	_check(skimmer in claimed, "Helix re-engaged before shield recharge completed")
	skimmer.shields = skimmer.shields_max * 0.95
	claimed = strategy.command(game, enemy, [skimmer], [])
	_check(skimmer not in claimed and not skimmer.has_meta("shield_withdrawing"), "Recharged Helix unit never returned to battle")


func _frontier(strategy):
	var rig = _dedicated("AdvancedTank", Vector3(32, 0, 32), enemy)
	var soldier = _dedicated("RocketInfantry", Vector3(32, 0, 34), enemy)
	await _frames(2)
	soldier.global_position = rig.global_position + Vector3.RIGHT
	strategy.command(game, enemy, [rig, soldier], [])
	_check(soldier.has_meta("garrison_host") or (soldier.action != null and soldier.action.get_script().resource_path.ends_with("Garrisoning.gd")), "Frontier AI left its mobile firing ports empty")
	var standard = load("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd").of(enemy.difficulty)
	_check(enemy.profile().first_wave < standard.first_wave and enemy.profile().task_groups > standard.task_groups, "Frontier did not gain earlier multi-prong pressure")
	_check(factions.batch_size("frontier", "Tank") == 2, "Frontier AI reinforcements lost Outrider pair production")
