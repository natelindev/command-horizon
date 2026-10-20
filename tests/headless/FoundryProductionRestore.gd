extends "res://tests/headless/BrokenFoundryRegression.gd"

const FOLDER = "res://docs/playtests/2026-10-07/foundry-production/"


func _run():
	path = "user://foundry-production-restore-%d.json" % OS.get_process_id()
	var reports = []
	for branch in ["legacy", "after"]:
		var store = load("res://source/match/saves/SaveFile.gd").new()
		var data = store.read_file(FOLDER + branch + "-late.json")
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var result = await restore.restore(self, data)
		_check(result.ok, "Production archive rejected: " + branch)
		if not result.ok:
			quit(2)
			return
		game = result.game
		game.progress_path = path
		await _frames(6)
		var again = load("res://source/match/saves/MatchSnapshot.gd").new().capture(game)
		_check(
			(
				again.mission == data.mission
				and game.simulation_time == data.simulation_time
				and paused
			),
			"Paused production state changed: " + branch
		)
		for saved in data.units:
			if saved.role == "VehicleFactory":
				var actual = again.units.filter(func(unit): return unit.id == saved.id)[0]
				_check(actual.production == saved.production, "Paid jobs changed: " + branch)
		game.hud._toggle_pause()
		var start = game.simulation_time
		while game.simulation_time - start < 165:
			await _frames(30)
		var tanks = _units(game._enemy, "Tank")
		var expected = 18 if branch == "legacy" else 20
		var funds = [game._enemy.resource_a, game._enemy.resource_b]
		_check(tanks.size() == expected, "Restoration lost or granted factory output: " + branch)
		# Batches queued after loading no longer pay a chip fee on top of the tank price.
		_check(
			funds == ([248, 76] if branch == "legacy" else [204, 72]),
			"Restoration charged wrong production cost"
		)
		_check(
			game.nodes.all(func(entry): return entry.batches == 3 and entry.left == 0),
			"Restored batch did not finish"
		)
		for entry in game.nodes:
			_check(
				entry.unit.get_node("ProductionQueue").size() == 0, "Restored queue did not drain"
			)
		for tank in tanks:
			_check(
				tank.stance == tank.Stance.HOLD_POSITION,
				"Restored factory output lost its guard post"
			)
		reports.append(
			{"branch": branch, "tanks": tanks.size(), "funds": funds, "time": game.simulation_time}
		)
		await _close()
	FileAccess.open(FOLDER + "restores.json", FileAccess.WRITE).store_string(
		JSON.stringify({"reports": reports, "errors": errors}, "\t")
	)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Foundry production restoration: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
