extends "res://tests/headless/NetworkSessionRegression.gd"


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	_deadline = Time.get_ticks_msec() + 60000
	session = load("res://source/match/network/NetworkSession.gd").create(self)
	if _is_host:
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			settings.players.append(side)
		_check(session.host(settings, _port(28973)), "Disconnect host failed")
		print("NETWORK_READY port=", session.port)
		while session.peers.is_empty() and _waiting():
			await process_frame
		_check(await session.start_battle(), "Disconnect battle failed to start")
		var acknowledged = []
		session.command_resolved.connect(func(command): acknowledged.append(command))
		while acknowledged.is_empty() and _waiting():
			await process_frame
		_check(
			not acknowledged.is_empty() and acknowledged[0].result,
			"Guest did not acknowledge with a legal owned command"
		)
		session.shutdown()
		print("Host closed after a real replicated command")
	else:
		_check(session.join("127.0.0.1", _port(28973)), "Disconnect guest failed to join")
		while (not is_instance_valid(session.game) or session.received_tick < 6) and _waiting():
			await process_frame
		var original = session.game
		var worker = _unit("Worker", "player-1")
		var intent = {
			"kind": "order",
			"units": [session.id_for(worker)],
			"order": "stop",
			"point": load("res://source/match/network/NetworkProtocol.gd").quantize(worker.position)
		}
		var started = Time.get_ticks_msec()
		_check(session.submit(intent), "Owned acknowledgement command was refused")
		while session.peer != null and _waiting():
			await create_timer(.05, true, false, true).timeout
		var elapsed = (Time.get_ticks_msec() - started) / 1000.0
		_check(
			session.peer == null and elapsed >= 29.0 and elapsed < 45.0,
			"Reconnect expiry did not honor its real30-second wall clock"
		)
		_check(
			session.game == original and is_instance_valid(worker),
			"Host loss reloaded or removed the replica"
		)
		_check(not session.submit(intent), "Disconnected commander issued a gameplay order")
		_check(session.error.contains("Connection lost"), "Host loss omitted its recovery message")
		print(
			"Guest retained one replica; reconnect expired after ",
			elapsed,
			" wall seconds; commands blocked"
		)
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)
	print(
		"Network host-loss expiry ",
		"host" if _is_host else "guest",
		": ",
		failures.size(),
		" failures"
	)
	session.shutdown()
	if is_instance_valid(session.game):
		session.game.queue_free()
	for index in 5:
		await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)
