extends "res://tests/headless/MatchFixture.gd"

var _harvest_script


func _run():
	_harvest_script = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _elevated_blocked_face_delivery()
	await _forward_refinery_delivery()
	for message in _errors:
		push_error(message)
	print("Worker return stall regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _start_map(map_path: String, faction: String = "bastion"):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = map_path
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	for side in get_nodes_in_group("players"):
		if side != _human:
			side.set_process(false)
	await _frames(15)
	await _game.navigation.wait_until_synchronized(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	await _frames(15)


func _find_cc():
	for unit in get_nodes_in_group("units"):
		if unit.player == _human and unit.type == "CommandCenter":
			return unit
	return null


func _elevated_blocked_face_delivery():
	var map_path = "res://source/match/maps/battlefields/PinebreakValleyMap.tscn"
	await _start_map(map_path, "bastion")
	var cc = _find_cc()
	# Place a blocking structure right on one approach side of the elevated CC.
	var blocker = _spawn("Barracks", _human, cc.global_position + Vector3(-4.2, 0, 0))
	blocker.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(10)
	await _game.navigation.wait_until_synchronized(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	await _frames(10)
	var deposits = get_nodes_in_group("resource_units").filter(func(r): return "resource_a" in r)
	deposits.sort_custom(
		func(a, b):
			return (
				cc.global_position.distance_to(a.global_position)
				< cc.global_position.distance_to(b.global_position)
			)
	)
	var deposit = deposits[0]
	var workers = []
	for index in 6:
		var offset = Vector3(-7.0 - (index % 3) * 1.4, 0, (index - 2.5) * 1.3)
		var point = cc.global_position + offset
		point.y = _game.map.height_at(Vector2(point.x, point.z))
		var worker = _spawn("Worker", _human, point)
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		workers.append(worker)
	await _frames(15)
	var before = _human.resource_a
	for worker in workers:
		worker.resource_a = 8
		worker.issue_manual_order(_harvest_script.new(deposit))
	var delivered_flags = {}
	for _frame in 900:
		await physics_frame
		for worker in workers:
			if worker.resource_a == 0:
				delivered_flags[worker] = true
		if delivered_flags.size() == workers.size():
			break
	_check(
		delivered_flags.size() == workers.size(),
		(
			"Elevated blocked-face CC stalled returning workers: %d/%d delivered"
			% [delivered_flags.size(), workers.size()]
		)
	)
	_check(
		_human.resource_a >= before + workers.size() * 8,
		"Elevated CC return lost delivered materials"
	)
	_game.queue_free()
	await _frames(6)


func _forward_refinery_delivery():
	var map_path = "res://source/match/maps/DesertFrontier.tscn"
	await _start_map(map_path, "bastion")
	var cc = _find_cc()
	var refinery_pos = cc.global_position + Vector3(12, 0, 0)
	var refinery = _spawn("ForwardRefinery", _human, refinery_pos)
	refinery.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(10)
	await _game.navigation.wait_until_synchronized(
		root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	)
	await _frames(10)
	var deposits = get_nodes_in_group("resource_units").filter(func(r): return "resource_a" in r)
	var workers = []
	for index in 4:
		var angle = index * TAU / 4.0 + PI / 4.0
		var worker = _spawn(
			"Worker", _human, refinery_pos + Vector3(cos(angle), 0, sin(angle)) * 6.0
		)
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		workers.append(worker)
	await _frames(15)
	var before = _human.resource_a
	for worker in workers:
		worker.resource_a = 8
		worker.issue_manual_order(_harvest_script.new(deposits[0]))
	var delivered_flags = {}
	for _frame in 700:
		await physics_frame
		for worker in workers:
			if worker.resource_a == 0:
				delivered_flags[worker] = true
		if delivered_flags.size() == workers.size():
			break
	_check(
		delivered_flags.size() == workers.size(),
		(
			"ForwardRefinery rectangular footprint stalled returning workers: %d/%d delivered"
			% [delivered_flags.size(), workers.size()]
		)
	)
	_check(_human.resource_a > before, "ForwardRefinery return did not credit materials")
	_game.queue_free()
	await _frames(6)
