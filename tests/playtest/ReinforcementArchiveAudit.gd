extends "res://tests/headless/ReinforcementResearchRegression.gd"

const ARCHIVE = (
	"res://docs/playtests/2026-10-06/relay-commitment/" + "final6-earned-case6-10-technology.json"
)
const OUTPUT = "res://docs/playtests/2026-10-06/reinforcement-pacing/"


func _run():
	var prefix = OUTPUT + "archive"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-prefix="):
			prefix = argument.trim_prefix("--output-prefix=")
	for suffix in ["-audit.json", "-control-after.json", "-reinforcement-after.json"]:
		if FileAccess.file_exists(prefix + suffix):
			push_error("Use a fresh --output-prefix; retained pacing evidence already exists")
			quit(2)
			return
	_load_policy()
	var records = []
	for enabled in [false, true]:
		var files = load("res://source/match/saves/SaveFile.gd").new()
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var result = await restore.restore(self, files.read_file(ARCHIVE))
		_check(result.ok, "Earned pacing archive failed to restore")
		if not result.ok:
			continue
		game = result.game
		human = game._get_human_player()
		opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		prioritize_reinforcements = enabled
		vehicle_sequence = 0
		_spent = Vector2.ZERO
		metrics = {}
		var before = _policy_army()
		var started = game.simulation_time
		var row = {
			"reinforcement_first": enabled,
			"first_new_ground": -1.0,
			"first_nine_ground": -1.0,
			"samples": []
		}
		paused = false
		for tick in 600:
			_produce()
			await _frames(30)
			var elapsed = game.simulation_time - started
			var army = _policy_army()
			if row.first_new_ground < 0 and army.any(func(unit): return unit not in before):
				row.first_new_ground = elapsed
			if row.first_nine_ground < 0 and army.size() >= 9:
				row.first_nine_ground = elapsed
			if tick % 60 == 0:
				row.samples.append(
					{"seconds": elapsed, "army": army.size(), "economy": _research_snapshot()[0]}
				)
			if game.finished:
				break
		row.final = {
			"elapsed": game.simulation_time - started,
			"army": _policy_army().size(),
			"economy": _research_snapshot()[0]
		}
		row.decisions = metrics.get("production_decisions", {})
		row.research = metrics.get("reference_research_orders", [])
		row.paid = [_spent.x, _spent.y]
		var label = "reinforcement" if enabled else "control"
		paused = true
		var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new().capture(game)
		_check(
			files.write_file(prefix + "-" + label + "-after.json", snapshot),
			"Pacing audit archive failed"
		)
		print("ARCHIVE PACING ", JSON.stringify(row))
		records.append(row)
		paused = false
		game.queue_free()
		await _frames(5)
	var file = FileAccess.open(prefix + "-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	for message in _errors:
		push_error(message)
	print("Reinforcement archive audit: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
