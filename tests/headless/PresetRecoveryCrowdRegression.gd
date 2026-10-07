extends "res://tests/headless/PresetRecoveryRegression.gd"


func _run():
	preset_library = load("res://source/match/programs/ProgramLibrary.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		await _frames(5)
		var service = _preset_actor("RepairDepot", Vector3(32, 0, 25))
		var units = []
		for index in 8:
			var unit = _preset_actor(
				"Tank", Vector3(43 + (index / 4) * 2.2, 0, 21 + (index % 4) * 2.2)
			)
			units.append(unit)
		await _frames(120)
		for unit in units:
			unit.hp = unit.hp_max * .35
			unit.program.installed = true
			var config = preset_library.defaults("guard")
			config.retreat = 40
			config["return"] = 85
			unit.program.configure(config)
			unit.program.anchor = unit.global_position_yless
			unit.program.safe_point = service.global_position_yless
			_check(unit.program.run(), "Crowd preset fixture refused to run")
		var starting_hp = units.reduce(func(total, unit): return total + unit.hp, 0.0)
		var started = game.simulation_time
		for sample in 4:
			await _frames(1800)
			var gained_hp = (
				units.reduce(func(total, unit): return total + unit.hp, 0.0) - starting_hp
			)
			_check(
				gained_hp <= (game.simulation_time - started) * 2 * .04 * units[0].hp_max + .1,
				"Crowd recovery exceeded the two service channels"
			)
			var rows = units.map(
				func(unit):
					return {
						"hp": unit.hp / unit.hp_max,
						"distance": unit.position.distance_to(service.position),
						"state": unit.program.mode,
						"reason": unit.program.reason
					}
			)
			print(
				"CROWD RECOVERY ",
				faction,
				" seconds=",
				(sample + 1) * 30,
				" ",
				JSON.stringify(rows)
			)
		for unit in units:
			_check(
				(
					unit.hp >= unit.hp_max * .85
					and unit.program.mode != "Blocked"
					and unit.global_position_yless.distance_to(unit.program.anchor) < 1.2
				),
				"Crowded preset did not recover and resume: " + faction
			)
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Crowd recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
