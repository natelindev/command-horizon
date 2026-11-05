extends "res://tests/headless/NetworkSessionRegression.gd"

var _group_received = false
var _forgery_checked = false
var _frames_received = 0
var _replay_path = ""
var _catalog
var _activation_wall_us = 0
var _offline_hz = 0
var _guest_finished = false


func _run():
	_offline_hz = Engine.physics_ticks_per_second
	_catalog = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-recording="):
			_replay_path = argument.trim_prefix("--network-recording=")
	if not _replay_path.is_empty():
		await _playback_group()
		return
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	_deadline = Time.get_ticks_msec() + 90000
	if not _is_host and "--network-spectator" not in OS.get_cmdline_user_args():
		session = load("res://tests/headless/InitialFrameLossSession.gd").new()
		session.name = "NetworkSession"
		root.add_child(session)
	else:
		session = load("res://source/match/network/NetworkSession.gd").create(self)
	session.changed.connect(func(): print("GROUP status=", session.status))
	session.frame_received.connect(
		func(tick):
			if _frames_received == 0:
				print("GROUP first_frame=", tick)
			_frames_received += 1
	)
	if _is_host:
		await _host_group()
	else:
		_check(
			session.join(
				"127.0.0.1", _port(28974), "--network-spectator" in OS.get_cmdline_user_args()
			),
			"Group client could not join"
		)
		var next_diagnostic = Time.get_ticks_msec() + 10000
		while not is_instance_valid(session.game) and _waiting():
			if Time.get_ticks_msec() >= next_diagnostic:
				print(
					"GROUP awaiting_initial=",
					JSON.stringify(
						{
							"read_task": session._read_task,
							"incoming": session._incoming.size(),
							"initializing": session._initializing,
							"reader_keys":
							session._reader.result.keys() if session._reader != null else [],
							"needs_full": session._needs_full,
							"paused": paused,
							"process_mode": session.process_mode,
							"replica_stage":
							(
								session.replica.initialization_stage
								if session.replica != null
								else "none"
							)
						}
					)
				)
				next_diagnostic += 10000
			await process_frame
		if is_instance_valid(session.game):
			if session.spectator:
				await _spectate_group()
			else:
				await _guest_group()
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	var role = "host" if _is_host else ("spectator" if session.spectator else "guest")
	await _finish_group("Network group " + role)


func _host_group():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	settings.visibility = settings.Visibility.FULL
	settings.match_seed = 271828
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "frontier"
		side.color = root.get_node("Constants").Player.COLORS[index]
		settings.players.append(side)
	_check(session.host(settings, _port(28974)), "Group host failed")
	print("NETWORK_READY port=", session.port)
	while not _participants_ready() and _waiting():
		await process_frame
	_check(await session.start_battle(_group_fixture), "Group match failed: " + session.error)
	_check(Engine.physics_ticks_per_second == 60, "Group bootstrap did not acquire60Hz")
	var initial_time = session.game.simulation_time
	var initial_tick = session.boundary.tick
	session.command_resolved.connect(_group_command)
	while not _group_received and _waiting():
		await process_frame
	if not _group_received:
		print(
			"GROUP authority_wait=",
			JSON.stringify(
				{
					"tick": session.boundary.tick,
					"last_send": session._last_send_tick,
					"task": session._task,
					"full_bytes": session._full_bytes.size(),
					"peers": session.peers.size()
				}
			)
		)
		return
	var queue = session.game.get_node_or_null("OrderActivationQueue")
	_check(queue != null and queue.statistics().queued == 100, "Host did not admit all100 heads")
	var snapshot = session.registry.capture(session.game, false)
	_check(
		session.registry.validate(snapshot),
		"Paused100-owner snapshot failed: " + session.registry.error
	)
	_check(_waiting_count(snapshot) == 100, "Paused capture lost pending cohort members")
	while session._task >= 0 and _waiting():
		await process_frame
	session._publish()
	while (
		not session.boundary.pending.any(func(row): return row.intent.kind == "formation")
		and _waiting()
	):
		await process_frame
	_check(_forgery_checked, "Mixed-ownership batch did not reach atomic rejection")
	_activation_wall_us = Time.get_ticks_usec()
	var resume_time = session.game.simulation_time
	var resume_tick = session.boundary.tick
	session.submit({"kind": "pause", "value": false})
	while queue != null and queue.statistics().queued > 0 and _waiting():
		await process_frame
	if queue != null:
		var stats = queue.statistics()
		_check(stats.activated_total == 100, "Authority did not activate every admitted member")
		_check(
			stats.maximum_batch <= 96 and stats.maximum_wait_ms <= 100.0,
			"Activation exceeded fixed bounds"
		)
		_check(
			(
				absf(
					(
						session.game.simulation_time
						- resume_time
						- (session.boundary.tick - resume_tick) / 60.0
					)
				)
				< .001
			),
			"World simulation seconds differ from authority ticks/60"
		)
		print(
			"GROUP activation=",
			JSON.stringify(stats),
			" physics_hz=",
			Engine.physics_ticks_per_second,
			" authority_hz=",
			session.boundary.TICKS_PER_SECOND,
			" wall_ms=",
			(Time.get_ticks_usec() - _activation_wall_us) / 1000.0,
			" simulation_seconds=",
			session.game.simulation_time - resume_time,
			" authority_ticks=",
			session.boundary.tick - resume_tick
		)
	await _host_shift_production()
	var expected = (int(_mobiles("player-1")[0].Stance.HOLD_FIRE) + 1) % 4
	var stopped = func(unit):
		return (
			unit.stance == expected
			and unit.manual_orders.current.is_empty()
			and unit.manual_orders.pending.is_empty()
		)
	while not _mobiles("player-1").all(stopped) and _waiting():
		await process_frame
	# Completion is acknowledged only after the remote player has observed the
	# authoritative Stop and stance results. A fixed server delay can end the
	# process before a busy replica has consumed its final frame.
	while not _guest_finished and _waiting():
		await process_frame
	var until_tick = session.boundary.tick + 60
	while session.boundary.tick < until_tick and _waiting():
		await process_frame
	var elapsed = session.game.simulation_time - initial_time
	_check(
		absf(elapsed - (session.boundary.tick - initial_tick) / 60.0) < .001,
		"Long-running world and authority clocks differ"
	)
	print(
		"GROUP clock physics_hz=",
		Engine.physics_ticks_per_second,
		" authority_hz=",
		session.boundary.TICKS_PER_SECOND,
		" ticks=",
		session.boundary.tick - initial_tick,
		" simulation_seconds=",
		elapsed
	)
	_check(session.rejected_commands == 1, "Legal group gestures were rate-limited or rejected")
	print("GROUP host tick=", session.boundary.tick, " replay=", session.recording_path)


func _group_fixture(game):
	var players = game.get_cached_group("players")
	var members = players[1].live_units().filter(
		func(unit): return unit.get_node_or_null("Movement") != null
	)
	while members.size() < 100:
		var index = members.size()
		var unit = load(_catalog.scene_path("frontier", "Infantry")).instantiate()
		game._setup_and_spawn_unit(
			unit,
			Transform3D(Basis(), Vector3(20 + (index % 20) * 1.2, 0, 30 + (index / 20) * 1.2)),
			players[1],
			false
		)
		members.append(unit)
	var structures = players[1].live_units().filter(
		func(unit): return unit.type in _catalog.Bastion.STRUCTURES
	)
	while structures.size() < 40:
		var index = structures.size()
		var structure = load(_catalog.scene_path("frontier", "PowerPlant")).instantiate()
		game._setup_and_spawn_unit(
			structure,
			Transform3D(Basis(), Vector3(8 + (index % 10) * 3.5, 0, 65 + (index / 10) * 3.5)),
			players[1],
			false
		)
		structures.append(structure)
	var second = load(_catalog.scene_path("bastion", "VehicleFactory")).instantiate()
	game._setup_and_spawn_unit(second, Transform3D(Basis(), Vector3(15, 0, 60)), players[0], false)
	for player in players:
		for unit in player.live_units():
			unit.stance = unit.Stance.HOLD_FIRE
			if unit.manual_orders != null:
				unit.manual_orders.cancel()
				unit.action = null


func _group_command(command):
	var entries = _entries(command.intent)
	if entries.any(
		func(entry): return entry.kind == "formation" and entry.get("value") == "staggered"
	):
		_check(command.result, "Guest completion acknowledgement was rejected")
		_guest_finished = command.result
	if entries.any(func(entry): return entry.get("token") == 990001):
		_forgery_checked = true
		_check(not command.result, "Mixed-owner batch was accepted")
		_check(
			_mobiles("player-1").all(func(unit): return unit.manual_orders.pending.is_empty()),
			"Rejected batch partially moved its owned member"
		)
	if (
		(
			entries
			. filter(func(entry): return entry.kind == "order" and entry.get("order") == "move")
			. size()
		)
		== 100
	):
		_check(command.result, "Legal100-owner batch was rejected")
		_group_received = true
		session.submit({"kind": "pause", "value": true})


func _host_shift_production():
	var player = session.entities()["player-0"]
	var factories = player.live_units().filter(func(unit): return unit.type == "VehicleFactory")
	var price = _catalog.production_cost(player, "Tank")
	player.resource_a = price.resource_a * 3
	player.resource_b = price.resource_b * 3
	session.game.hud.select_units(factories)
	for index in 4:
		await process_frame
	var menus = session.game.find_child("UnitMenus")
	menus._activate("Tank", false, 5)
	_check(session._local_intents.size() == 5, "Shift production dropped pending attempts")
	while (
		factories[0].production_queue.size() + factories[1].production_queue.size() < 3
		and _waiting()
	):
		await process_frame
	var sizes = factories.map(func(unit): return unit.production_queue.size())
	sizes.sort()
	_check(sizes == [1, 2], "Shift production did not share the two selected factories")
	_check(
		player.resource_a == 0 and player.resource_b == 0,
		"Partial-funds production did not charge exactly three jobs"
	)
	print("GROUP production attempts=5 funded=3 split=", sizes)


func _guest_group():
	_check(
		session.dropped_initial and session.recovered_after_ms >= 0,
		"Bootstrap loss was not exercised"
	)
	_check(
		session.recovered_after_ms < 1800,
		"Lost first state did not recover through the cached bootstrap retry"
	)
	print("GROUP bootstrap lost_first=true recovery_ms=", session.recovered_after_ms)
	var units = _mobiles("player-1")
	_check(units.size() == 100, "Guest did not receive the legal100-mobile roster")
	var first = units[0]
	var bad = [
		{
			"kind": "order",
			"units": [session.id_for(first)],
			"order": "move",
			"point": [45000, 0, 45000],
			"token": 990001
		},
		{
			"kind": "order",
			"units": [session.id_for(_unit("Worker", "player-0"))],
			"order": "move",
			"point": [45000, 0, 45000]
		}
	]
	_check(
		session.submit(_protocol().pack_batch(bad)), "Could not send mixed-owner rejection fixture"
	)
	while not session.status.contains("does not own") and _waiting():
		await process_frame
	session.game.hud.select_units(units)
	for index in 4:
		await process_frame
	var origins = units.map(func(unit): return unit.position)
	var controller = session.game._get_human_player().get_node("UnitActionsController")
	var before = session._sequence
	controller._try_navigating_selected_units_towards_position(Vector3(48, 0, 50))
	controller._on_terrain_target_heading_set(Vector3(48, 0, 50), Vector3.RIGHT)
	while not paused or _waiting_count(session.replica.state) != 100:
		if not _waiting():
			return
		await process_frame
	_check(
		session._sequence - before == 2,
		"100 destinations and100 revisions were not bounded into two packets"
	)
	_check(
		not session.game.has_node("OrderActivationQueue"), "Replica scheduled authoritative starts"
	)
	var game = session.game
	var token = session.reconnect_token
	var welcomes_before = session.welcome_count
	session.peer.close()
	# Decoding an old queued frame is not proof of a new connection. Wait for
	# the new welcome, then a frame received after that handshake.
	while session.welcome_count <= welcomes_before and _waiting():
		await process_frame
	var frames_before = _frames_received
	while _frames_received <= frames_before:
		if not _waiting():
			return
		await process_frame
	_check(
		session.game == game and session.reconnect_token == token and paused,
		"Paused pending reconnect replaced the game/ownership/time"
	)
	_check(_waiting_count(session.replica.state) == 100, "Reconnect lost pending per-unit intents")
	session.submit({"kind": "formation", "units": units.map(session.id_for), "value": "box"})
	var moved = 0
	while moved < 64 and _waiting():
		moved = 0
		for index in units.size():
			if units[index].position.distance_to(origins[index]) > .1:
				moved += 1
		await process_frame
	_check(moved >= 64, "Real100-owner movement did not affect the replicated world")
	var structures = session.entities().values().filter(
		func(unit):
			return (
				"type" in unit
				and unit.type in _catalog.Bastion.STRUCTURES
				and unit.player == session.entities()["player-1"]
			)
	)
	_check(structures.size() == 40, "Mixed roster did not contain40 actual controlled structures")
	game.hud.select_units(units + structures)
	for index in 3:
		await process_frame
	var menus = game.find_child("UnitMenus")
	_check(menus._selection.size() == 140, "Group Stop lost the mixed140-entity roster")
	_check(menus._command_card != null, "Mixed roster did not expose its command card")
	if menus._command_card == null:
		return
	menus._command_card._on_stop()
	menus._command_card._on_hold()
	var expected = (int(units[0].stance) + 1) % 4
	print("GROUP guest Stop/stance expected=", expected, " initial=", units[0].stance)
	# The command-card gesture calls this method on each selected body.
	for unit in units:
		unit.cycle_stance()
	var stopped = func(unit):
		return (
			unit.stance == expected
			and unit.manual_orders.pending.is_empty()
			and unit.manual_orders.current.is_empty()
		)
	while not units.all(stopped) and _waiting():
		await process_frame
	_check(units.all(stopped), "Replica did not observe all100 Stop and stance results")
	_check(
		not game.has_node("OrderActivationQueue"), "Stop/stance created a replica activation queue"
	)
	_check(session.verify_replica(), "Grouped replica live hash differs")
	session.submit({"kind": "formation", "units": units.map(session.id_for), "value": "staggered"})
	var acknowledgement_tick = session.received_tick
	while session.received_tick <= acknowledgement_tick and _waiting():
		await process_frame
	print(
		"GROUP guest moved=",
		moved,
		" reconnect_pending=100 mixed_selected=140 stopped=100 held=100 stances=100"
	)


func _spectate_group():
	var saw_pending = false
	while (not saw_pending or session.received_tick < 180) and _waiting():
		saw_pending = saw_pending or _waiting_count(session.replica.state) == 100
		await process_frame
	_check(saw_pending, "Spectator missed the paused100-member pending state")
	_check(not session.game.has_node("OrderActivationQueue"), "Spectator scheduled starts")
	_check(session.verify_replica(), "Spectator grouped live hash differs")


func _playback_group():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	var playback = load("res://source/match/network/ReplayPlayback.gd").new()
	root.add_child(playback)
	_check(await playback.open(_replay_path), "Group recording did not open: " + playback.error)
	if playback.archive != null and playback.game != null:
		playback.playing = false
		var frame = load("res://source/match/network/AuthoritativeFrame.gd")
		var state = {}
		var waiting_tick = -1
		var group_commands = 0
		var recorded = {"move": 0, "revise_order": 0, "stop": 0, "hold": 0, "stance": 0}
		for index in playback.archive.records.size():
			var record = playback.archive.records[index]
			var data = playback.archive.read_record(index)
			if record.kind == playback.archive.COMMAND:
				var entries = _entries(data.intent)
				group_commands += entries.size()
				if data.result:
					for entry in entries:
						var kind = entry.get("order", "") if entry.kind == "order" else entry.kind
						if recorded.has(kind):
							recorded[kind] += maxi(1, entry.get("units", []).size())
			elif record.kind == playback.archive.FRAME:
				var decoded = load("res://source/match/saves/SaveValue.gd").new().decode(data.state)
				state = decoded if data.full else frame.apply_delta(state, decoded)
				if _waiting_count(state) == 100:
					waiting_tick = record.tick
		_check(
			recorded.values().all(func(count): return count == 100),
			(
				"Binary omitted exact100-actor destinations/revisions/Stop/Hold/stance: "
				+ str(recorded)
			)
		)
		_check(
			waiting_tick >= 0 and playback.seek(waiting_tick), "No seekable paused100-member state"
		)
		_check(
			_waiting_count(playback.replica.state) == 100, "Pending replay seek lost cohort intents"
		)
		_check(
			not playback.game.has_node("OrderActivationQueue"), "Replay scheduled authority starts"
		)
		_check(playback.seek(playback.duration), "Group end seek failed")
		_check(
			playback.last_hash == playback.archive.footer.hash, "Grouped replay footer hash differs"
		)
		print(
			"GROUP replay logical_entries=",
			group_commands,
			" actors=",
			JSON.stringify(recorded),
			" waiting_tick=",
			waiting_tick,
			" final_hash=",
			playback.last_hash
		)
	playback.shutdown()
	if is_instance_valid(playback.game):
		playback.game.queue_free()
	playback.queue_free()
	for index in 5:
		await process_frame
	var verifier = load("res://source/match/network/ReplayVerifier.gd").new()
	root.add_child(verifier)
	var report = await verifier.verify(self, _replay_path)
	_check(
		report.error == "" and report.commands >= 4 and report.frames > 2,
		"Large-cohort input re-simulation did not execute its real command stream"
	)
	print("GROUP input re-simulation=", JSON.stringify(report))
	_check(
		Engine.physics_ticks_per_second == _offline_hz, "Input re-simulation retained60Hz offline"
	)
	verifier.queue_free()
	for index in 5:
		await process_frame
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	await _finish_group("Network group replay")


func _mobiles(owner: String) -> Array:
	return session.entities().values().filter(
		func(unit):
			return (
				is_instance_valid(unit)
				and "player" in unit
				and unit.player == session.entities().get(owner)
				and unit.get_node_or_null("Movement") != null
			)
	)


func _waiting_count(snapshot: Dictionary) -> int:
	var count = 0
	for row in snapshot.get("units", []):
		if (
			row.player == "player-1"
			and not row.orders.get("pending", []).is_empty()
			and row.orders.get("current", {}).is_empty()
		):
			count += 1
	return count


func _entries(intent: Dictionary) -> Array:
	return _protocol().unpack_batch(intent) if intent.kind == "batch" else [intent]


func _protocol():
	return load("res://source/match/network/NetworkProtocol.gd").new()


func _finish_group(label: String):
	if session != null:
		session.shutdown()
		_check(
			Engine.physics_ticks_per_second == _offline_hz,
			"Group session did not restore its offline clock"
		)
		if is_instance_valid(session.game):
			session.game.queue_free()
	for message in failures:
		push_error(message)
	print(label, ": ", failures.size(), " failures")
	await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)
