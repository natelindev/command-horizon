extends "res://tests/headless/CampaignRegression.gd"

const SECONDS = 360.0
var _results = []


func _initialize():
	_run.call_deferred()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	for faction in ["bastion", "helix", "frontier"]:
		for difficulty in 3:
			await _battle(faction, difficulty)
	DirAccess.make_dir_recursive_absolute("res://tmp/hero-campaign")
	var file = FileAccess.open("res://tmp/hero-campaign/active-ai-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_results, "  "))
	for error in errors:
		push_error(error)
	print("Active AI balance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _battle(faction, difficulty):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	settings.match_seed = 713
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.faction = faction
		side.controller = index + 1
		side.difficulty = 1 if index == 0 else difficulty
		side.color = Color.GOLD if index == 0 else Color.CYAN
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.set_script(load("res://tests/headless/ActiveAiMatch.gd"))
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	var sides = game.get_node("Players").get_children()
	var first_attacks = [-1.0, -1.0]
	var next_report = 60
	print("ACTIVE AI BEGIN ", faction, " normal vs ", difficulty)
	while game.simulation_time < SECONDS and not game.finished:
		await process_frame
		for index in 2:
			if first_attacks[index] < 0 and sides[index].attacks_launched > 0:
				first_attacks[index] = game.simulation_time
		if game.simulation_time >= next_report:
			print("ACTIVE AI ", faction, " difficulty=", difficulty, " time=", next_report)
			next_report += 60
	var row = {
		"faction": faction,
		"difficulty": difficulty,
		"seconds": game.simulation_time,
		"result": game.result,
		"first_attacks": first_attacks,
		"sides": []
	}
	for side in sides:
		row.sides.append(
			{
				"structures_built": side.structures_built,
				"attacks": side.attacks_launched,
				"population": side.population(),
				"materials": side.resource_a,
				"electronics": side.resource_b
			}
		)
		_check(side.structures_built >= 2, "Active commander failed to build: " + faction)
		_check(side.attacks_launched > 0, "Active commander never attacked: " + faction)
		_check(side.resource_a >= 0 and side.resource_b >= 0, "AI overspent resources")
	_results.append(row)
	print("ACTIVE AI RESULT ", JSON.stringify(row))
	paused = false
	game.queue_free()
	await _frames(5)
