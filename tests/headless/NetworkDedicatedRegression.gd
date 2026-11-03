extends "res://tests/headless/NetworkSessionRegression.gd"

var _role_name = ""


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	_deadline = Time.get_ticks_msec() + 45000
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-role="):
			_role_name = arg.trim_prefix("--network-role=")
	if _role_name.is_empty():
		_role_name = "server" if _is_host else "guest"

	session = load("res://source/match/network/NetworkSession.gd").create(self)
	session.changed.connect(func(): print("STATUS ", session.status))

	var port = _port(29202)
	if _is_host:
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
		settings.visibility = settings.Visibility.FULL
		settings.match_seed = 987654

		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = 1 if index == 0 else 2
			side.color = root.get_node("Constants").Player.COLORS[index]
			side.faction = "bastion" if index == 0 else "frontier"
			side.team = index
			side.spawn_index = index
			settings.players.append(side)

		# Host as dedicated server (local_slot = -1)
		_check(session.host(settings, port, true), "Could not host dedicated server")
		_check(session.local_slot == -1, "Dedicated server local_slot must be -1")
		_check(session.authority == true, "Dedicated server authority must be true")
		print("NETWORK_READY port=", session.port)

		while not session.is_ready_to_start() and _waiting():
			await process_frame

		_check(await session.start_battle(), "Dedicated server could not start battle: " + session.error)
		var p0 = session.game.get_cached_group("players")[0]
		_check(not p0.is_processing(), "Dedicated server must not process local human inputs on player 0")

		while session.boundary.tick < 500 and not session.peers.is_empty() and _waiting():
			await process_frame

		_check(session.boundary.tick >= 60, "Dedicated server did not advance 60 ticks")
	else:
		_check(session.join("127.0.0.1", port, false), "Guest could not join dedicated server")
		while session.local_slot < 0 and _waiting():
			await process_frame

		_check(
			session.local_slot in [0, 1],
			"Dedicated guest expected slot 0 or 1 for %s, got %d" % [_role_name, session.local_slot]
		)

		while not is_instance_valid(session.game) and _waiting():
			await process_frame

		while session.received_tick < 60 and _waiting():
			await process_frame

		_check(session.received_tick >= 60, "%s: Expected >= 60 received ticks" % _role_name)

	var close_started = Time.get_ticks_msec()
	session.shutdown()
	_check(Time.get_ticks_msec() - close_started < 2000, "Dedicated teardown exceeded time limit")

	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)

	print("Network dedicated %s: %d failures" % [_role_name, failures.size()])
	if is_instance_valid(session.game):
		session.game.queue_free()
	for index in 5:
		await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)
