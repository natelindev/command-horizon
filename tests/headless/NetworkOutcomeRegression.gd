extends "res://tests/headless/NetworkSessionRegression.gd"


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	_deadline = Time.get_ticks_msec() + 30000
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	var dropping = "--terminal-drop-host" in OS.get_cmdline_user_args()
	session = load("res://source/match/network/NetworkSession.gd").create(self)
	session.changed.connect(func(): print("STATUS ", session.status))
	if _is_host:
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.visibility = settings.Visibility.FULL
		settings.map_path = "res://source/match/maps/BastionDesert.tscn"
		settings.match_seed = 314160
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = "bastion" if index == 0 else "frontier"
			settings.players.append(side)
		_check(session.host(settings, _port(28972)), "Outcome host failed")
		print("NETWORK_READY port=", session.port)
		while session.peers.is_empty() and _waiting():
			await process_frame
		_check(await session.start_battle(_lethal_fixture), "Outcome battle failed to start")
		var hq = _unit("CommandCenter", "player-1")
		var shooter = _unit("Tank", "player-0")
		var presentation = session.game.get_node("BattlePresentation")
		_check(
			not presentation.can_present_collapse(hq),
			"Network HQ death enabled cinematic time/camera changes"
		)
		session.game.get_node("IsometricCamera3D").set_process(false)
		var camera = session.game.get_node("IsometricCamera3D").transform
		shooter.manual_orders.submit(
			{"kind": "attack", "point": hq.position, "target": weakref(hq)}
		)
		while not session._finished_sent and _waiting():
			await process_frame
		_check(
			session.game.finished and session.game.result == "Victory",
			"Host did not receive actual lethal-HQ victory"
		)
		_check(
			(
				Engine.time_scale == 1.0
				and session.game.get_node("IsometricCamera3D").transform == camera
			),
			"Network HQ death changed clock or camera"
		)
		_check(
			not session.last_hash.is_empty() and session._replay == null,
			"Terminal state was not published and replay finalized while paused"
		)
		print(
			"HOST terminal tick=",
			session.boundary.tick,
			" result=",
			session.game.result,
			" hash=",
			session.last_hash
		)
		if dropping:
			await _drop_during_pending_receipt()
		else:
			# The guest may still be restoring its initial world when this tiny
			# lethal fixture finishes. Its exact ACK proves its result is ready.
			var wait_until = Time.get_ticks_msec() + 10000
			while not session.terminal_receipts.has(1) and Time.get_ticks_msec() < wait_until:
				await process_frame
			# Close immediately after that ACK, without waiting for disconnect.
			# The confirmation must remain serviced through concurrent teardown.
			var host_close_started = Time.get_ticks_msec()
			session.shutdown()
			_check(
				Time.get_ticks_msec() - host_close_started < 1500,
				"Host terminal teardown exceeded its bounded drain"
			)
			print("HOST_TERMINAL_DRAIN elapsed_ms=", Time.get_ticks_msec() - host_close_started)
			_check(session.peers.is_empty(), "Commander did not close its completed result")
			_check(
				(
					session.terminal_receipts.get(1, {})
					== {"tick": session.boundary.tick, "hash": session.last_hash}
				),
				"Guest did not acknowledge terminal state"
			)
	else:
		_check(session.join("127.0.0.1", _port(28972)), "Outcome guest failed to connect")
		while (not is_instance_valid(session.game) or not session.game.finished) and _waiting():
			await process_frame
		_check(
			is_instance_valid(session.game) and session.game.result == "Defeat",
			"Guest saw host-perspective outcome instead of its own defeat"
		)
		_check(paused, "Guest result did not pause locally")
		_check(session.verify_replica(), "Terminal live entity digest differs")
		print(
			"GUEST terminal tick=",
			session.received_tick,
			" result=",
			session.game.result,
			" hash=",
			session.last_hash
		)
	var close_started = Time.get_ticks_msec()
	session.shutdown()
	if not _is_host:
		_check(
			session.terminal_confirmed != dropping,
			"Terminal confirmation did not match the actual host receipt"
		)
	_check(
		Time.get_ticks_msec() - close_started < 1500, "Terminal teardown exceeded its bounded drain"
	)
	print(
		"TERMINAL_CLOSE confirmed=",
		session.terminal_confirmed,
		" elapsed_ms=",
		Time.get_ticks_msec() - close_started
	)
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)
	print(
		"Network terminal-drop " if dropping else "Network lethal HQ ",
		"host" if _is_host else "guest",
		": ",
		failures.size(),
		" failures"
	)
	if is_instance_valid(session.game):
		session.game.queue_free()
	for index in 5:
		await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _drop_during_pending_receipt():
	# Observe both the frame ACK and teardown retry before dropping the real
	# host. No artificial sleep decides whether the guest entered its drain.
	session.set_process(false)
	session.peer.get_host().flush()
	var protocol = load("res://source/match/network/NetworkProtocol.gd").new()
	var received = 0
	var deadline = Time.get_ticks_msec() + 5000
	while received < 2 and Time.get_ticks_msec() < deadline:
		session.peer.poll()
		while session.peer.get_available_packet_count() > 0:
			var sender = session.peer.get_packet_peer()
			var packet = protocol.decode(session.peer.get_packet())
			if (
				packet is Dictionary
				and packet.keys().size() == 3
				and packet.get("type") == "terminal_ack"
				and packet.get("tick") == session.boundary.tick
				and packet.get("hash") == session.last_hash
				and session.peers.get(sender, {}).get("slot", -1) == 1
			):
				received += 1
		if received < 2:
			await process_frame
	_check(received >= 2, "Host did not observe the guest's pending teardown receipt")
	_check(
		session.terminal_receipts.is_empty(), "Dropped host falsely confirmed the terminal frame"
	)
	print("HOST terminal drop after pending ACK count=", received)
	session.peer.close()
	session.peer = null


func _lethal_fixture(game):
	var players = game.get_cached_group("players")
	for unit in players[1].live_units().duplicate():
		if unit.type != "CommandCenter":
			unit.free()
	var hq = players[1].live_units()[0]
	hq.hp = 1.0
	var tank = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(
		tank, Transform3D(Basis(), hq.global_position + Vector3(0, 0, -6)), players[0], false
	)
	tank.stance = tank.Stance.HOLD_FIRE
