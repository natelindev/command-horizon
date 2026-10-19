extends "res://tests/headless/CampaignRegression.gd"

# Full commander-versus-commander matches on authored battlefields. Records
# match length, expansion headquarters over time and which crossings the
# attack waves staged through. Acceptance: median match of at least 20
# minutes, every commander expands, someone takes a third base, and waves use
# more than one lane.
#   Godot --headless --fixed-fps 60 --path . --script tests/headless/AuthoredMapAiMatch.gd
#     -- [MapId] [--matches=N] [--minutes=M]

const LIMIT_MINUTES = 40.0
var _results = []


func _initialize():
	_run.call_deferred()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	var map_id = "RedrockDivideMap"
	var matches = 2
	var minutes = LIMIT_MINUTES
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--matches="):
			matches = int(argument.trim_prefix("--matches="))
		elif argument.begins_with("--minutes="):
			minutes = float(argument.trim_prefix("--minutes="))
		elif not argument.begins_with("--"):
			map_id = argument
	var factions = [["bastion", "helix"], ["helix", "frontier"], ["frontier", "bastion"]]
	for index in matches:
		await _battle(map_id, factions[index % factions.size()], 713 + index, minutes)
	var durations = _results.map(func(row): return row.minutes)
	durations.sort()
	var median = durations[durations.size() / 2] if not durations.is_empty() else 0.0
	print("AUTHORED AI SUMMARY median=%.1f min durations=%s" % [median, durations])
	DirAccess.make_dir_recursive_absolute("res://tmp/map-rebuild")
	var file = FileAccess.open("res://tmp/map-rebuild/ai-%s.json" % map_id, FileAccess.WRITE)
	file.store_string(JSON.stringify(_results, "  "))
	_check(median >= 20.0, "Median match %.1f min is under 20" % median)
	for error in errors:
		push_error(error)
	print("Authored AI matches: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _battle(map_id, pairing, match_seed, minutes):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/battlefields/%s.tscn" % map_id
	settings.match_seed = match_seed
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.faction = pairing[index]
		side.controller = index + 1
		side.difficulty = 1
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
	var lanes = [{}, {}]
	var expansions = [[], []]
	var next_report = 60.0
	print("AUTHORED AI BEGIN %s %s vs %s" % [map_id, pairing[0], pairing[1]])
	while game.simulation_time < minutes * 60.0 and not game.finished:
		await process_frame
		for index in 2:
			for group in sides[index]._army_groups:
				var via = group.get("via")
				if via != null:
					lanes[index]["%d,%d" % [roundi(via.x), roundi(via.z)]] = true
		if game.simulation_time >= next_report:
			for index in 2:
				var bases = sides[index].get_children().filter(
					func(unit): return "type" in unit and unit.type == "CommandCenter"
				)
				expansions[index].append(bases.size())
			print(
				(
					"AUTHORED AI t=%d bases=%s attacks=%s population=%s"
					% [
						next_report,
						[expansions[0][-1], expansions[1][-1]],
						[sides[0].attacks_launched, sides[1].attacks_launched],
						[sides[0].population(), sides[1].population()]
					]
				)
			)
			next_report += 60.0
	var row = {
		"map": map_id,
		"pairing": pairing,
		"minutes": game.simulation_time / 60.0,
		"finished": game.finished,
		"result": game.result,
		"sides": []
	}
	for index in 2:
		var peak = expansions[index].max() if not expansions[index].is_empty() else 1
		row.sides.append(
			{
				"faction": pairing[index],
				"attacks": sides[index].attacks_launched,
				"structures": sides[index].structures_built,
				"peak_bases": peak,
				"lanes": lanes[index].keys()
			}
		)
		_check(peak >= 2, "%s commander %d never expanded" % [map_id, index])
		_check(
			lanes[index].size() >= 2 or sides[index].attacks_launched < 2,
			"%s commander %d used %d lanes" % [map_id, index, lanes[index].size()]
		)
	_check(
		row.sides.any(func(side): return side.peak_bases >= 3),
		"%s: neither commander took a third base" % map_id
	)
	_results.append(row)
	print("AUTHORED AI RESULT ", JSON.stringify(row))
	if not game.finished:
		_describe_stalemate(sides)
	paused = false
	game.queue_free()
	await _frames(10)


# Where an unfinished match stands: each side's structures and where its
# combat units are and what they are doing.
func _describe_stalemate(sides):
	for index in sides.size():
		var side = sides[index]
		var structures = []
		var army = {}
		for unit in side.get_children():
			if not "type" in unit:
				continue
			if unit.has_method("is_constructed"):
				structures.append(
					(
						"%s@%d,%d"
						% [
							unit.type,
							roundi(unit.global_position.x),
							roundi(unit.global_position.z)
						]
					)
				)
			elif unit.attack_range != null and unit.movement_speed > 0:
				var action = (
					unit.action.get_script().resource_path.get_file() if unit.action else "idle"
				)
				var cell = (
					"%d,%d"
					% [
						roundi(unit.global_position.x / 10) * 10,
						roundi(unit.global_position.z / 10) * 10
					]
				)
				var key = "%s %s" % [action, cell]
				army[key] = army.get(key, 0) + 1
		print("STALEMATE side %d structures %s" % [index, structures])
		print("STALEMATE side %d army %s" % [index, army])
		for group in side._army_groups:
			print(
				(
					"STALEMATE side %d group %s point %s via %s members %d"
					% [index, group.kind, group.point, group.get("via"), group.members.size()]
				)
			)
