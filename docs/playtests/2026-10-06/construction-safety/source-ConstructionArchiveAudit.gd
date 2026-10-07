extends "res://tests/headless/SafeConstructionRegression.gd"

const ARCHIVE = (
	"res://docs/playtests/2026-10-06/reinforcement-pacing/"
	+ "control6-earned-case6-10-armor_recovery.json"
)


func _run():
	_load_policy()
	var archive_path = ARCHIVE
	var prefix = "res://docs/playtests/2026-10-06/construction-safety/archive"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive_path = argument.trim_prefix("--archive=")
		if argument.begins_with("--output-prefix="):
			prefix = argument.trim_prefix("--output-prefix=")
	for suffix in ["-audit.json", "-original-after.json", "-safe-after.json"]:
		if FileAccess.file_exists(prefix + suffix):
			push_error("Use a fresh output prefix; construction evidence already exists")
			quit(2)
			return
	var records = []
	for enabled in [false, true]:
		var files = load("res://source/match/saves/SaveFile.gd").new()
		var restored = await load("res://source/match/saves/MatchRestore.gd").new().restore(
			self, files.read_file(archive_path)
		)
		_check(restored.ok, "Earned construction archive failed to restore")
		if not restored.ok:
			continue
		game = restored.game
		human = game._get_human_player()
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		safe_construction = enabled
		metrics = {}
		_spent = Vector2.ZERO
		var started = game.simulation_time
		var tracked = []
		var row = {
			"safe": enabled,
			"started": started,
			"first_complete": null,
			"foundations": [],
			"samples": []
		}
		paused = false
		for tick in 240:
			var units = plan_rules.owned_units(human)
			var workers = units.filter(func(unit): return unit.type == "Worker")
			var barracks = units.filter(func(unit): return unit.type == "Barracks")
			if (
				barracks.is_empty()
				and not workers.is_empty()
				and human.has_resources(factions.cost(human, "Barracks", true))
			):
				_place("Barracks", workers[0])
				var foundation = _unit(human, "Barracks")
				if foundation != null:
					tracked.append(
						{
							"unit": weakref(foundation),
							"bought": game.simulation_time,
							"position": _site_array(foundation.position),
							"complete": null,
							"lost": null
						}
					)
			await _frames(30)
			for entry in tracked:
				var unit = entry.unit.get_ref()
				if unit == null and entry.lost == null:
					entry.lost = game.simulation_time
				if unit != null and unit.is_constructed() and entry.complete == null:
					entry.complete = game.simulation_time
					if row.first_complete == null:
						row.first_complete = game.simulation_time - started
			if tick % 40 == 0:
				row.samples.append(
					{
						"seconds": game.simulation_time,
						"funds": [human.resource_a, human.resource_b],
						"barracks":
						(
							plan_rules
							. owned_units(human)
							. filter(func(unit): return unit.type == "Barracks")
							. size()
						)
					}
				)
			if game.finished:
				break
		for entry in tracked:
			entry.erase("unit")
		row.foundations = tracked
		row.elapsed = game.simulation_time - started
		row.spent = [_spent.x, _spent.y]
		row.decisions = metrics.get("construction_decisions", [])
		row.final_funds = [human.resource_a, human.resource_b]
		row.result = game.result if game.finished else "unfinished"
		paused = true
		var label = "safe" if enabled else "original"
		_check(
			files.write_file(
				prefix + "-" + label + "-after.json",
				load("res://source/match/saves/MatchSnapshot.gd").new().capture(game)
			),
			"Construction audit archive failed"
		)
		print("ARCHIVE CONSTRUCTION ", JSON.stringify(row))
		records.append(row)
		paused = false
		game.queue_free()
		await _frames(5)
	var output = FileAccess.open(prefix + "-audit.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	output.close()
	for message in _errors:
		push_error(message)
	print("Construction archive audit: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
