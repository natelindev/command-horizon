extends "res://tests/headless/CoastalRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	moving = load("res://source/match/units/actions/Moving.gd")
	var region = "desert"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--region="):
			region = argument.trim_prefix("--region=")
	var maps = {"desert": FRONTIER, "alpine": ALPINE, "industrial": INDUSTRIAL, "coastal": COASTAL}
	if region not in maps:
		quit(2)
		return
	await _skirmish("frontier", maps[region])
	_enemy().set_process(false)
	await _frames(100)
	match region:
		"desert":
			_check(
				await _frontier_routes(game._get_human_player()) == true,
				"Frontier desert traversal aborted"
			)
		"alpine":
			_check(
				await _routes_and_army(game._get_human_player()) == true,
				"Frontier Alpine traversal aborted"
			)
			_check(
				await _relay_and_restore(game._get_human_player(), _enemy()) == true,
				"Frontier Alpine relay/archive aborted"
			)
		"industrial":
			_check(await _industrial_routes() == true, "Frontier Industrial traversal aborted")
			_check(await _infantry_access() == true, "Frontier infantry access aborted")
			_check(
				await _relay_and_restore(game._get_human_player(), _enemy()) == true,
				"Frontier industrial relay/archive aborted"
			)
		"coastal":
			_check(await _coastal_routes() == true, "Frontier Coastal traversal aborted")
	paused = false
	game.queue_free()
	await _frames(5)
	match region:
		"desert":
			await _frontier_economy("frontier")
		"alpine":
			await _standard_economy("frontier")
		"industrial":
			_check(
				await _industrial_economy("frontier") == true, "Frontier Industrial economy aborted"
			)
		"coastal":
			_check(await _coastal_economy("frontier") == true, "Frontier Coastal economy aborted")
	for message in errors:
		push_error(message)
	print("Frontier faction %s routes/economy/archive: %d failures" % [region, errors.size()])
	quit(0 if errors.is_empty() else 1)
