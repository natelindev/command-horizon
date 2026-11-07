extends "res://tests/headless/FactionAsymmetryRegression.gd"


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("frontier")
	var frame = load("res://source/match/network/AuthoritativeFrame.gd").new()
	var protocol = load("res://source/match/network/NetworkProtocol.gd").new()
	var values = load("res://source/match/saves/SaveValue.gd").new()
	var started = Time.get_ticks_usec()
	var baseline = frame.capture(game)
	var capture_ms = (Time.get_ticks_usec() - started) / 1000.0
	_check(
		not baseline.is_empty() and frame.validate(baseline),
		"Initial authority frame failed: " + frame.error
	)
	_check(not paused, "Authority boundary left offline gameplay paused")
	var survivor = _units(human, "Worker")[1]
	var survivor_id = frame.id_for(survivor)
	var initial_hash = frame.hash_state(baseline)
	var legacy = baseline.duplicate(true)
	legacy.erase("camera")
	_check(
		initial_hash == protocol.canonical_hash(values.encode(_legacy_canonical(legacy))),
		"Full captured match changed its pre-optimization checksum"
	)
	var view = baseline.duplicate(true)
	view.camera.position += Vector3(3, 0, 0)
	_check(frame.hash_state(view) == initial_hash, "View-only camera changed simulation hash")
	_units(human, "Worker")[0].queue_free()
	await _frames(2)
	var spawn = _dedicated("Infantry", Vector3(42, 0, 25))
	await _frames(2)
	var current = frame.capture(game)
	_check(
		frame.validate(current), "Changed authority frame failed strict validation: " + frame.error
	)
	_check(frame.id_for(survivor) == survivor_id, "A death renumbered a surviving network entity")
	_check(frame.id_for(spawn) != survivor_id, "A production reused a live network entity ID")
	var changes = frame.delta(baseline, current)
	var reconstructed = frame.apply_delta(baseline, changes)
	_check(
		frame.hash_state(reconstructed) == frame.hash_state(current),
		"Entity delta changed authoritative state"
	)
	_check(
		(
			changes.remove.units.size() == 1
			and changes.upsert.units.any(func(unit): return unit.id == frame.id_for(spawn))
		),
		"Entity births/deaths were omitted from the delta"
	)
	var encoded = values.encode(current)
	var packet = protocol.encode(encoded)
	_check(not packet.is_empty(), "Authority frame exceeds protocol contract: " + protocol.error)
	if not packet.is_empty():
		var recovered = values.decode(protocol.decode(packet))
		_check(
			frame.hash_state(recovered) == frame.hash_state(current),
			"Network encoding changed authority hash"
		)
	await _worker_roundtrip(current)
	print("Authority capture initial_ms=%.3f encoded_bytes=%d" % [capture_ms, packet.size()])
	game.queue_free()
	await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for error in errors:
		push_error(error)
	print("Authoritative frame: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _worker_roundtrip(snapshot):
	var session = load("res://source/match/network/NetworkSession.gd").new()
	session._prime_definitions()
	var builder = load("res://source/match/network/PacketBuilder.gd").new()
	var job = {
		"snapshot": snapshot.duplicate(true),
		"previous": {},
		"definitions": session._definitions,
		"tick": 6,
		"base": 0,
		"full": true,
		"paused": false,
		"finished": false,
		"outcome": ""
	}
	var task = WorkerThreadPool.add_task(builder.prepare.bind(job))
	while not WorkerThreadPool.is_task_completed(task):
		await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_check(
		not builder.result.has("error"),
		"Worker validation failed: " + str(builder.result.get("error", ""))
	)
	if not builder.result.has("error"):
		var reader = load("res://source/match/network/PacketReader.gd").new()
		task = WorkerThreadPool.add_task(
			reader.decode.bind(
				{
					"bytes": builder.result.bytes,
					"tick": 0,
					"previous": {},
					"definitions": session._definitions,
					"needs_full": false
				}
			)
		)
		while not WorkerThreadPool.is_task_completed(task):
			await process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		_check(
			reader.result.has("snapshot"),
			"Worker reader rejected valid frame: " + str(reader.result.get("error", ""))
		)
		if reader.result.has("snapshot"):
			_check(
				builder.validator.hash_state(reader.result.snapshot) == builder.result.hash,
				"Worker roundtrip changed state hash"
			)
	job.snapshot.units[0].hp = -1.0
	task = WorkerThreadPool.add_task(builder.prepare.bind(job))
	while not WorkerThreadPool.is_task_completed(task):
		await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_check(builder.result.has("error"), "Worker accepted malformed state")
	session.free()


func _legacy_canonical(value):
	if value is Dictionary:
		var keys = value.keys().map(func(key): return str(key))
		keys.sort()
		var result = {}
		for key in keys:
			result[key] = _legacy_canonical(value[key])
		return result
	if value is Array:
		return value.map(_legacy_canonical)
	return value
