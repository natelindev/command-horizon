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
	var path = "res://source/match/maps/battlefields/%s.tscn" % map_id
	var count = root.get_node("Constants").Match.MAPS[path].players
	var roster = ["bastion", "helix", "frontier"]
	for index in matches:
		var pairing = []
		for side in count:
			pairing.append(roster[(index + side) % roster.size()])
		await _battle(map_id, pairing, 713 + index, minutes)
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
	for index in pairing.size():
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.faction = pairing[index]
		side.controller = 1 if index == 0 else 2
		side.difficulty = 1
		side.color = Color.from_hsv(index / float(pairing.size()), 0.75, 0.95)
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.set_script(load("res://tests/headless/ActiveAiMatch.gd"))
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	var sides = game.get_node("Players").get_children()
	var lanes = []
	var expansions = []
	for _side in sides:
		lanes.append({})
		expansions.append([])
	var next_report = 60.0
	print("AUTHORED AI BEGIN %s %s" % [map_id, " vs ".join(pairing)])
	while game.simulation_time < minutes * 60.0 and not game.finished:
		await process_frame
		for index in sides.size():
			for group in sides[index]._army_groups:
				var via = group.get("via")
				if via != null:
					lanes[index]["%d,%d" % [roundi(via.x), roundi(via.z)]] = true
		if game.simulation_time >= next_report:
			for index in sides.size():
				var bases = sides[index].get_children().filter(
					func(unit): return "type" in unit and unit.type == "CommandCenter"
				)
				expansions[index].append(bases.size())
			print(
				(
					"AUTHORED AI t=%d bases=%s attacks=%s population=%s"
					% [
						next_report,
						expansions.map(func(list): return list[-1]),
						sides.map(func(side): return side.attacks_launched),
						sides.map(func(side): return side.population())
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
		"first_elimination":
		game.eliminated_at.values().min() / 60.0 if not game.eliminated_at.is_empty() else null,
		"sides": []
	}
	for index in sides.size():
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
		# Duels must vary their approach. In free-for-all each commander attacks
		# through the crossing facing its target, so variety is checked overall.
		if sides.size() == 2:
			_check(
				lanes[index].size() >= 2 or sides[index].attacks_launched < 2,
				"%s commander %d used %d lanes" % [map_id, index, lanes[index].size()]
			)
	if sides.size() > 2:
		var used = {}
		for list in lanes:
			used.merge(list)
		_check(
			used.size() >= sides.size() - 1,
			"%s: commanders used only %d crossings" % [map_id, used.size()]
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
