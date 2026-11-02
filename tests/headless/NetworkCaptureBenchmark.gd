extends "res://tests/headless/FactionAsymmetryRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("frontier")
	var catalog = load("res://source/match/BastionCatalog.gd")
	for side in get_nodes_in_group("players"):
		var count = side.live_units().filter(func(unit): return unit.movement_speed > 0).size()
		for index in 100 - count:
			var point = Vector3(8 + index % 12 * 3, 0, 10 + index / 12 * 3)
			_dedicated("Infantry", point, side)
	await _frames(5)
	var frame = load("res://source/match/network/AuthoritativeFrame.gd").new()
	var protocol = load("res://source/match/network/NetworkProtocol.gd").new()
	var values = load("res://source/match/saves/SaveValue.gd").new()
	var baseline = frame.capture(game)
	_check(not baseline.is_empty(), frame.error)
	var samples = []
	var stages = {"capture": [], "schema": [], "delta": [], "hash": [], "codec": []}
	var bytes = 0
	for index in 12:
		var start = Time.get_ticks_usec()
		var checkpoint = start
		var snapshot = frame.capture(game, false)
		stages.capture.append((Time.get_ticks_usec() - checkpoint) / 1000.0)
		checkpoint = Time.get_ticks_usec()
		frame.validate(snapshot)
		stages.schema.append((Time.get_ticks_usec() - checkpoint) / 1000.0)
		checkpoint = Time.get_ticks_usec()
		var delta = frame.delta(baseline, snapshot)
		stages.delta.append((Time.get_ticks_usec() - checkpoint) / 1000.0)
		checkpoint = Time.get_ticks_usec()
		var hash_value = frame.hash_state(snapshot)
		stages.hash.append((Time.get_ticks_usec() - checkpoint) / 1000.0)
		checkpoint = Time.get_ticks_usec()
		var packet = protocol.encode({"state": values.encode(delta), "hash": hash_value})
		stages.codec.append((Time.get_ticks_usec() - checkpoint) / 1000.0)
		bytes = packet.size()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		await _frames(1)
	samples.sort()
	print(
		"Network 200-mobile capture+strict validation+delta+hash+encode ms p50=",
		samples[6],
		" p95=",
		samples[11],
		" delta_bytes=",
		bytes,
		" full_bytes=",
		protocol.encode(values.encode(baseline)).size(),
		" units=",
		baseline.units.size()
	)
	print("Network capture stages ms: ", JSON.stringify(stages))
	await _background_samples(frame, baseline)
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _background_samples(frame, baseline):
	var session = load("res://source/match/network/NetworkSession.gd").new()
	session._prime_definitions()
	var main_samples = []
	var worker_samples = []
	var loops = []
	for index in 8:
		var before = Time.get_ticks_usec()
		var current = frame.capture(game, false)
		main_samples.append((Time.get_ticks_usec() - before) / 1000.0)
		var builder = load("res://source/match/network/PacketBuilder.gd").new()
		before = Time.get_ticks_usec()
		var task = WorkerThreadPool.add_task(
			builder.prepare.bind(
				{
					"snapshot": current,
					"previous": baseline,
					"definitions": session._definitions,
					"tick": 6 + index * 6,
					"base": 0,
					"full": false,
					"paused": false,
					"finished": false,
					"outcome": ""
				}
			)
		)
		var count = 0
		while not WorkerThreadPool.is_task_completed(task):
			count += 1
			await process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		worker_samples.append((Time.get_ticks_usec() - before) / 1000.0)
		loops.append(count)
		_check(not builder.result.has("error"), str(builder.result.get("error", "")))
	main_samples.sort()
	worker_samples.sort()
	print(
		"NETWORK BACKGROUND 200 mobiles main_capture_ms_p50=",
		main_samples[4],
		" p95=",
		main_samples[7],
		" worker_ms_p50=",
		worker_samples[4],
		" p95=",
		worker_samples[7],
		" main_frames_during_jobs=",
		loops
	)
	session.free()
