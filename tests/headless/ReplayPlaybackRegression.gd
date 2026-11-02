extends SceneTree
var errors = []


class RuntimeErrors:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _initialize():
	call_deferred("_run")


func _run():
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	var path = _recording_path()
	if path.is_empty():
		push_error("Run NetworkSessionRegression first to create a real transport recording.")
		await root.get_node("Globals").quit_game(1)
		return
	var playback = load("res://source/match/network/ReplayPlayback.gd").new()
	root.add_child(playback)
	var opened = await playback.open(path)
	_check(opened, "Could not open real recording: " + playback.error)
	if opened:
		playback.playing = false
		var first = playback.game
		var headquarters = playback.replica.entities.values().filter(
			func(node):
				return is_instance_valid(node) and "type" in node and node.type == "CommandCenter"
		)
		var hq = headquarters[0]
		var mounted = _mounted_checkpoint(playback)
		_check(not mounted.is_empty(), "Real recording has no mounted transport checkpoint")
		if not mounted.is_empty():
			_check(playback.seek(mounted.tick), "Seek while mounted failed")
			var rider = playback.replica.entities[mounted.rider]
			_check(
				(
					rider.has_meta("garrison_host")
					and not rider.visible
					and not rider.get_node("Geometry").is_visible_in_tree()
				),
				"Replay seek revealed a mounted passenger"
			)
			var shooter = headquarters[0]
			_check(
				not load("res://source/match/combat/CombatRules.gd").can_target(shooter, rider),
				"Replay passenger became an independent target"
			)
			if "--native-unit-state" in OS.get_cmdline_user_args():
				_check(rider._native_state != null, "Native replay silently skipped unit state")
		_check(playback.seek(playback.duration), "Seek to end failed: " + playback.error)
		_check(playback.last_hash == playback.archive.footer.hash, "End-state hash differs")
		if not mounted.is_empty():
			var rider = playback.replica.entities[mounted.rider]
			_check(
				(
					not rider.has_meta("garrison_host")
					and rider.visible
					and rider.get_node("Geometry").is_visible_in_tree()
				),
				"Replay unload did not restore the infantry body"
			)
		_check(playback.seek(playback.duration / 2), "Backward seek failed: " + playback.error)
		_check(
			playback.game == first and is_instance_valid(hq),
			"Seeking reloaded the match or replaced surviving entities"
		)
		_check(playback.seek(0), "Seek to initial state failed")
		_check(not playback.submit({"kind": "surrender"}), "Playback accepted gameplay input")
		var digest = load("res://source/match/network/ReplicaDigest.gd")
		var before_input = digest.live(playback.replica)
		hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
		for candidate in playback.replica.entities.values():
			if candidate.get_node_or_null("Movement") != null:
				candidate.manual_orders.submit(
					{"kind": "move", "point": candidate.position + Vector3.RIGHT}
				)
				candidate.cycle_stance()
				break
		_check(
			digest.live(playback.replica) == before_input,
			"Read-only replay gate changed live gameplay"
		)
		playback.speed = 4.0
		playback.playing = true
		var before = playback.tick
		playback._process(.25)
		_check(playback.tick > before, "Replay speed did not advance playback")
		playback.toggle()
		before = playback.tick
		playback._process(.25)
		_check(playback.tick == before, "Paused replay advanced")
		print(
			"Replay streamed playback frames=",
			playback.archive.frames.size(),
			" duration=",
			playback.duration,
			" final_hash=",
			playback.archive.footer.hash
		)
	playback.shutdown()
	if is_instance_valid(playback.game):
		playback.game.queue_free()
	playback.queue_free()
	for index in 5:
		await process_frame
	var verifier = load("res://source/match/network/ReplayVerifier.gd").new()
	root.add_child(verifier)
	var report = await verifier.verify(self, path)
	_check(
		report.error == "" and report.commands >= 4 and report.frames > 1,
		"Input re-simulation verifier did not execute the real command stream"
	)
	print("Replay input re-simulation: ", JSON.stringify(report))
	var offline_hz = Engine.physics_ticks_per_second
	var invalid = await verifier.verify(self, "user://replays/missing-replay-fixture.rtsreplay")
	_check(
		not invalid.ok and not invalid.error.is_empty(),
		"Missing replay was accepted on verifier reuse"
	)
	_check(
		(
			verifier._commands.is_empty()
			and verifier._frames.is_empty()
			and verifier._archive._file == null
		),
		"Failed verifier reuse retained commands or an open archive"
	)
	_check(
		Engine.physics_ticks_per_second == offline_hz, "Rejected replay changed the offline clock"
	)
	verifier.queue_free()
	for index in 5:
		await process_frame
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for error in errors:
		push_error(error)
	print("Replay playback and verifier: ", errors.size(), " failures")
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value:
		errors.append(message)


func _mounted_checkpoint(playback) -> Dictionary:
	var state = {}
	var frame = load("res://source/match/network/AuthoritativeFrame.gd")
	for index in playback.archive.frames:
		var packet = playback.archive.read_record(index)
		var data = _decode(packet.state)
		state = data if packet.full else frame.apply_delta(state, data)
		for unit in state.units:
			if unit.has("garrison_mount") and not unit.garrison_mount.occupants.is_empty():
				return {
					"tick": packet.tick, "rig": unit.id, "rider": unit.garrison_mount.occupants[0]
				}
	return {}


func _decode(value):
	return load("res://source/match/saves/SaveValue.gd").new().decode(value)


func _recording_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-recording="):
			return argument.trim_prefix("--network-recording=")
	var files = Array(DirAccess.open("user://replays").get_files()).filter(
		func(path): return path.ends_with(".rtsreplay")
	)
	files.sort()
	files.reverse()
	for filename in files:
		var archive = load("res://source/match/network/ReplayFile.gd").new()
		if not archive.open_read("user://replays/" + filename):
			continue
		var initial = _decode(archive.header.get("initial"))
		archive.close()
		if initial is Dictionary and initial.settings.match_seed == 314159:
			return "user://replays/" + filename
	return ""
