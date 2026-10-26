extends "res://tests/headless/MapResourceBalanceRegression.gd"


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create("res://source/match/maps/battlefields/GlacierNarrowsMap.tscn")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var human = game._get_human_player()
	var cases = []
	# These mirrored lakeshore piles previously overlapped the boathouses.
	for point in [Vector2(62.67173, 62.20346), Vector2(129.3283, 62.20346)]:
		var matches = get_nodes_in_group("resource_units").filter(
			func(unit): return Vector2(unit.position.x, unit.position.z).distance_to(point) < .02
		)
		_check(matches.size() == 1, "Lakeshore deposit moved or disappeared")
		if matches.size() != 1:
			continue
		var deposit = matches[0]
		# Isolate this pile so the harvester cannot silently choose another one.
		deposit.harvest_origin = deposit.global_position_yless
		var worker = load("res://source/match/units/Worker.tscn").instantiate()
		game._setup_and_spawn_unit(
			worker, Transform3D(Basis(), game.map.ground_point(point + Vector2(0, 7))), human, false
		)
		worker.process_mode = Node.PROCESS_MODE_ALWAYS
		cases.append({"worker": worker, "deposit": deposit, "before": deposit.resource_b})
	await _frames(10)
	for entry in cases:
		entry.worker.issue_manual_order(harvest.new(entry.deposit))
	await _frames(900)
	for entry in cases:
		var mined = entry.before - entry.deposit.resource_b
		_check(mined > 0, "Lakeshore electronics unreachable at %s" % entry.deposit.global_position)
		print("GLACIER HARVEST ", entry.deposit.global_position, " mined=", mined)
	game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Glacier harvest: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
