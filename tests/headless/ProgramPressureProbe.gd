extends "res://tests/headless/SaveRestoreEdges.gd"

const SOURCES = [
	"res://docs/playtests/2026-10-06/paid-retrofit/earned-2-case2-11-retrofit_installed.json",
	"res://docs/playtests/2026-10-06/paid-retrofit/earned-6-case6-11-retrofit_installed.json"
]


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var output = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output == "":
		quit(2)
		return
	var observations = []
	for source in SOURCES:
		var loaded = await Restore.new().restore(self, FileStore.new().read_file(source))
		_check(loaded.ok, "Earned first-program source failed to restore")
		if not loaded.ok:
			break
		game = loaded.game
		var owner = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
		_check(enemy.is_processing(), "Enemy strategy is disabled in pressure continuation")
		var tanks = _units(owner, "Tank").filter(func(unit): return unit.program.installed)
		_check(not tanks.is_empty(), "Earned archive lacks installed armor")
		var tank = tanks[0]
		var safe = _units(owner, "CommandCenter")[0].position + Vector3(-6, 0, 0)
		var anchor = Vector3(20, 0, 40)
		tank.program.configure(
			load("res://source/match/programs/ProgramLibrary.gd").defaults("guard")
		)
		tank.program.anchor = anchor
		tank.program.safe_point = safe
		_check(tank.program.run(), "Earned fitted tank refused Guard")
		var start = game.simulation_time
		var samples = []
		var captured = false
		paused = false
		for frame in 7200:
			if not is_instance_valid(tank) or tank.is_queued_for_deletion() or game.finished:
				break
			if frame % 60 == 0:
				samples.append(
					{
						"seconds": game.simulation_time - start,
						"hp": tank.hp,
						"max": tank.hp_max,
						"position": [tank.position.x, tank.position.z],
						"mode": tank.program.mode,
						"reason": tank.program.reason
					}
				)
				if not captured and "No recovery support" in tank.program.reason:
					paused = true
					_check(
						FileStore.new().write_file(
							output + "-" + owner.faction + "-unsupported.json",
							Snapshot.new().capture(game)
						),
						"Pressure archive capture failed"
					)
					paused = false
					captured = true
			await _frames(1)
		var result = {
			"source": source,
			"faction": owner.faction,
			"start": start,
			"elapsed": game.simulation_time - start,
			"alive": is_instance_valid(tank) and not tank.is_queued_for_deletion(),
			"unsupported_captured": captured,
			"samples": samples
		}
		observations.append(result)
		print(
			"PRESSURE OBSERVED ",
			owner.faction,
			" alive=",
			result.alive,
			" unsupported=",
			captured,
			" seconds=",
			result.elapsed
		)
		paused = false
		game.queue_free()
		await _frames(5)
	FileAccess.open(output + ".json", FileAccess.WRITE).store_string(
		JSON.stringify(observations, "\t")
	)
	for message in errors:
		push_error(message)
	print("Program pressure probe: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
