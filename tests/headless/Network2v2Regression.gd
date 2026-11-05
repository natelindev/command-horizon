extends "res://tests/headless/NetworkSessionRegression.gd"

var _role_name = ""


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	# Three processes import a full battlefield concurrently on shared runners.
	# Keep the simulation assertion independent of that startup wall time.
	_deadline = Time.get_ticks_msec() + 120000
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-role="):
			_role_name = arg.trim_prefix("--network-role=")
	if _role_name.is_empty():
		_role_name = "host" if _is_host else "guest"

	session = load("res://source/match/network/NetworkSession.gd").create(self)
	session.changed.connect(func(): print("STATUS ", session.status))

	var port = _port(29201)
	if _is_host:
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.map_path = "res://source/match/maps/battlefields/FourRiversMap.tscn"
		settings.visibility = settings.Visibility.FULL
		settings.match_seed = 424242

		for index in 4:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = 1 if index == 0 else 2
			side.color = root.get_node("Constants").Player.COLORS[index]
			side.faction = ["bastion", "helix", "frontier", "bastion"][index]
			side.team = 0 if index < 2 else 1
			side.spawn_index = index
			if index == 3:
				side.set_meta("ai_commander", true)
			settings.players.append(side)

		_check(session.host(settings, port), "Could not host 2v2 match")
		print("NETWORK_READY port=", session.port)

		while not session.is_ready_to_start() and _waiting():
			await process_frame

		_check(await session.start_battle(), "Host could not start 2v2 battle: " + session.error)

		var players = session.game.get_cached_group("players")
		var Players = load("res://source/match/Players.gd")
		_check(players.size() == 4, "Expected 4 players in 2v2 battle, found %d" % players.size())
		_check(Players.allied(players[0], players[1]), "Slots 0 and 1 must be allied in Team 0")
		_check(Players.allied(players[2], players[3]), "Slots 2 and 3 must be allied in Team 1")
		_check(
			not Players.allied(players[0], players[2]),
			"Slots 0 and 2 must not be allied across teams"
		)

		while (
			session.peers.values().any(func(entry): return not entry.get("ready", false))
			and _waiting()
		):
			await process_frame
		_check(
			(
				session.peers.size() == 2
				and session.peers.values().all(func(entry): return entry.get("ready", false))
			),
			"Both guests must complete their loading handshake"
		)

		# Guests close only after validating their replica. A fixed authority
		# tick cutoff can expire while a slower peer is still loading its map.
		while not session.peers.is_empty() and _waiting():
			await process_frame

		_check(session.boundary.tick >= 60, "2v2 Host did not advance 60 ticks")
	else:
		_check(session.join("127.0.0.1", port, false), "Guest could not join 2v2 host")
		while session.local_slot < 0 and _waiting():
			await process_frame

		_check(
			session.local_slot in [1, 2],
			"Expected guest slot in [1, 2] for %s, got %d" % [_role_name, session.local_slot]
		)

		if _role_name == "guest2":
			# Reproduce a synchronous battlefield setup exceeding ENet's normal
			# five-second minimum even on fast developer machines.
			OS.delay_msec(6500)
		while not is_instance_valid(session.game) and _waiting():
			await process_frame

		while session.received_tick < 60 and _waiting():
			await process_frame

		var players = session.game.get_cached_group("players")
		_check(players.size() == 4, "%s: Expected 4 replicated players" % _role_name)
		_check(session.received_tick >= 60, "%s: Expected >= 60 received ticks" % _role_name)

	var close_started = Time.get_ticks_msec()
	print("Network 2v2 progress: ", _network_progress())
	session.shutdown()
	_check(Time.get_ticks_msec() - close_started < 2000, "2v2 Teardown exceeded time limit")

	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)

	print("Network 2v2 %s: %d failures" % [_role_name, failures.size()])
	if is_instance_valid(session.game):
		session.game.queue_free()
	for index in 5:
		await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)
