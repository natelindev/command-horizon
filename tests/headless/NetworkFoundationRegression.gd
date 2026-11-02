extends SceneTree

var errors = []
var session_type


class ClockGame:
	extends Node
	var hud = null
	var finished = false


func _initialize():
	call_deferred("_run")


func _run():
	session_type = load("res://source/match/network/NetworkSession.gd")
	var protocol = load("res://source/match/network/NetworkProtocol.gd").new()
	var boundary = load("res://source/match/network/SimulationBoundary.gd").new()
	var replay_type = load("res://source/match/network/ReplayFile.gd")
	var intent = {
		"kind": "order",
		"units": ["unit_0"],
		"order": "move",
		"point": [1234, 0, 5678],
		"append": false
	}
	_check(protocol.valid_intent(intent), "Legal typed movement intent was rejected")
	var decoded = protocol.decode(protocol.encode(intent))
	_check(
		decoded == intent and decoded.point[0] is int,
		"Protocol changed quantized commands or integer types"
	)
	_check(
		protocol.quantize(Vector3(1.23449, 0, 5.67849)) == intent.point,
		"Millimetre input quantization differs"
	)
	_check(
		protocol.vector(intent.point).is_equal_approx(Vector3(1.234, 0, 5.678)),
		"Quantized input reconstruction differs"
	)
	for bad in [
		{"kind": "call", "method": "free"},
		{"kind": "order", "units": ["unit_0"], "order": "move", "point": [1.2, 0, 0]},
		{"kind": "order", "units": ["../../root"], "order": "move", "point": [0, 0, 0]},
		{"kind": "ability", "unit": "unit_0", "id": "phase_shift", "script": "res://anything.gd"},
	]:
		_check(not protocol.valid_intent(bad), "Unsafe command shape was accepted")
	var group = []
	var members = []
	for index in 100:
		members.append("unit-%d" % index)
	for index in 100:
		group.append(
			{
				"kind": "order",
				"units": [members[index]],
				"order": "move",
				"point": [1000 + index * 100, 0, 2000],
				"members": members,
				"token": index + 1
			}
		)
	var batch = protocol.pack_batch(group)
	_check(protocol.valid_intent(batch), "Legal100-member gesture was rejected")
	_check(
		batch.cohorts.size() == 1 and protocol.unpack_batch(batch) == group,
		"Group admission lost individual destinations/tokens or duplicated shared membership"
	)
	_check(protocol.work_cost(batch) == 100, "Batch evaded logical-work accounting")
	_check(protocol.encode(batch).size() < protocol.MAX_INTENT_BYTES, "Legal group exceeds ingress")
	for bad in [
		{"kind": "batch", "intents": [batch], "cohorts": []},
		{"kind": "batch", "intents": [{"kind": "pause", "value": true}], "cohorts": []},
		{"kind": "batch", "intents": [{"kind": "surrender"}], "cohorts": []},
		{"kind": "batch", "intents": group + group, "cohorts": []},
	]:
		_check(not protocol.valid_intent(bad), "Unsafe or oversized batch was accepted")
	var bad_cohort = batch.duplicate(true)
	bad_cohort.intents[0].cohort = 900
	_check(not protocol.valid_intent(bad_cohort), "Unknown shared formation was accepted")
	var work_boundary = boundary.get_script().new()
	for index in 10:
		_check(work_boundary.enqueue(0, index + 1, batch), "Legal group burst lost work credit")
	_check(not work_boundary.enqueue(0, 11, batch), "Batches multiplied the peer work budget")
	var target_order = intent.duplicate(true)
	target_order.target = "unit-9"
	_check(
		not protocol.encode(target_order).is_empty(), "Native dictionary member keys were rejected"
	)
	_check(protocol.encode(self).is_empty(), "Protocol serialized an engine object")
	var deep = []
	var nested = deep
	for _index in protocol.MAX_DEPTH + 2:
		var child = []
		nested.append(child)
		nested = child
	_check(protocol.encode(deep).is_empty(), "Protocol accepted an excessive nesting depth")
	_check(
		protocol.decode(PackedByteArray([123, 125])) == {}, "Empty inert JSON object was rejected"
	)
	_check(
		(
			protocol.canonical_hash({"b": 2, "a": [1, 2]})
			== protocol.canonical_hash({"a": [1, 2], "b": 2})
		),
		"Canonical hash depends on dictionary insertion order"
	)
	_check(
		boundary.enqueue(1, 1, intent) and boundary.enqueue(0, 1, intent),
		"Valid authority input was rejected"
	)
	intent.point[0] = 9999
	_check(not boundary.enqueue(1, 1, intent), "Duplicate input sequence was accepted")
	_check(
		boundary.advance(func(_slot, _intent): return true).is_empty(),
		"Input bypassed its fixed-tick delay"
	)
	var applied = boundary.advance(func(_slot, _intent): return true)
	_check(
		(
			applied.size() == 2
			and applied[0].slot == 0
			and applied[1].slot == 1
			and applied[0].intent.point[0] == 1234
		),
		"Authority ordering or immutable command capture changed"
	)
	for index in 64:
		_check(boundary.enqueue(2, index + 1, intent), "Legal input budget was rejected")
	_check(not boundary.enqueue(2, 65, intent), "Authority command rate limit was bypassed")
	var file = replay_type.new()
	var path = "user://network-foundation-%d.rtsreplay" % OS.get_process_id()
	DirAccess.remove_absolute(path)
	_check(
		file.begin(path, {"protocol": 1, "map": "PlainAndSimple", "seed": 771}),
		"Could not create binary replay: " + file.error
	)
	var state = {"tick": 0, "units": [{"id": "unit_0", "point": [1000, 0, 2000], "hp": 100000}]}
	_check(file.append(replay_type.FRAME, 0, state), "Initial authoritative frame was not recorded")
	_check(file.append(replay_type.COMMAND, 2, applied[0]), "Quantized command was not recorded")
	state.tick = 6
	state.units[0].point = [1500, 0, 2000]
	var end_hash = protocol.canonical_hash(state)
	_check(
		file.append(replay_type.FRAME, 6, {"state": state, "hash": end_hash}),
		"Final authoritative frame was not recorded"
	)
	_check(file.finish(6, end_hash), "Replay did not finalize")
	var raw = FileAccess.get_file_as_bytes(path)
	_check(raw.slice(0, 8) == PackedByteArray(file.MAGIC), "Replay is not the framed binary format")
	_check(file.open_read(path), "Valid binary replay was rejected: " + file.error)
	_check(
		file.records.size() == 5 and file.frames.size() == 2,
		"Replay omitted commands or state frames"
	)
	_check(
		file.read_record(file.frame_at(6)).hash == end_hash and file.footer.hash == end_hash,
		"Replay end-state checksum differs"
	)
	_check(file.records[file.frame_at(3)].tick == 0, "Replay seek selected a future frame")
	file.close()
	raw[raw.size() - 3] = raw[raw.size() - 3] ^ 127
	var corrupt = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_buffer(raw)
	corrupt.close()
	_check(
		not file.open_read(path) and FileAccess.get_file_as_bytes(path) == raw,
		"Corrupt replay was accepted or changed"
	)
	DirAccess.remove_absolute(path)
	_check(file.begin(path, {"protocol": 1}), "Limit fixture did not open")
	_check(file.append(replay_type.FRAME, 0, state), "Limit fixture frame failed")
	file._written_records = replay_type.MAX_RECORDS - 1
	_check(
		not file.append(replay_type.COMMAND, 1, applied[0]),
		"Replay accepted work beyond its record budget"
	)
	_check(file.finish(0, end_hash), "Record budget did not reserve its playable footer")
	_check(file.open_read(path), "Record-limited replay was not playable: " + file.error)
	file.close()
	DirAccess.remove_absolute(path)
	_ordinary_teardown()
	await _clock_lifecycle(intent)
	for message in errors:
		push_error(message)
	print("Network foundation: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(condition, message):
	if not condition:
		errors.append(message)


func _ordinary_teardown():
	var session = session_type.create(self)
	session.peer = ENetMultiplayerPeer.new()
	_check(session.peer.create_server(0) == OK, "Ordinary teardown transport did not open")
	var started = Time.get_ticks_msec()
	session.shutdown()
	_check(
		Time.get_ticks_msec() - started < 250 and session.peer == null,
		"An ordinary in-progress close waited for terminal receipts"
	)
	session.shutdown()
	_check(session.peer == null and session._closing, "Repeated teardown reopened its transport")
	session.queue_free()


func _clock_lifecycle(intent: Dictionary):
	var offline_hz = Engine.physics_ticks_per_second
	var session = session_type.create(self)
	session.use_fixed_clock()
	session.use_fixed_clock()
	_check(Engine.physics_ticks_per_second == 60, "Session did not acquire60Hz")
	var game = ClockGame.new()
	root.add_child(game)
	game.set_meta("network_session", session)
	session.game = game
	session.authority = true
	session.boundary.tick = 9
	session.last_hash = "a".repeat(64)
	session.peers[7] = {"slot": 1}
	var receipt = {"type": "terminal_ack", "tick": 9, "hash": session.last_hash}
	session._receive_decoded(7, receipt)
	_check(
		session.terminal_receipts.is_empty(), "A live nonterminal state accepted a final receipt"
	)
	game.finished = true
	session._finished_sent = true
	var forged = receipt.duplicate()
	forged.hash = "b".repeat(64)
	session._receive_decoded(7, forged)
	_check(session.terminal_receipts.is_empty(), "A forged final hash was accepted")
	session._receive_decoded(7, receipt)
	session.peers.erase(7)
	_check(
		session.terminal_receipts.get(1, {}) == {"tick": 9, "hash": session.last_hash},
		"Validated terminal receipt disappeared with its live peer"
	)
	session.authority = false
	session.received_tick = 9
	var confirmation = {"type": "terminal_receipt", "tick": 9, "hash": session.last_hash}
	session._receive_decoded(1, confirmation)
	_check(not session.terminal_confirmed, "An unvalidated frame acquired a terminal confirmation")
	session._terminal_ack = {"tick": 9, "hash": session.last_hash}
	session._receive_decoded(7, confirmation)
	_check(not session.terminal_confirmed, "A foreign sender confirmed a terminal frame")
	for invalid in [
		{"type": "terminal_receipt", "tick": 8, "hash": session.last_hash},
		{"type": "terminal_receipt", "tick": 9, "hash": "b".repeat(64)},
		{"type": "terminal_receipt", "tick": 9, "hash": session.last_hash, "extra": true},
	]:
		session._receive_decoded(1, invalid)
		_check(not session.terminal_confirmed, "A forged terminal confirmation was accepted")
	session._receive_decoded(1, confirmation)
	_check(session.terminal_confirmed, "The exact host terminal confirmation was rejected")
	_check(not session._fail("Clock lifecycle regression"), "Fatal failure reported success")
	_check(
		Engine.physics_ticks_per_second == offline_hz and paused and session._closing,
		"Fatal session did not release the physics clock and freeze gameplay"
	)
	_check(
		game.has_meta("network_session") and not session.submit(intent),
		"Failed view lost its read-only input gate"
	)
	session.shutdown()
	_check(
		not paused and Engine.physics_ticks_per_second == offline_hz,
		"Final teardown retained pause/clock"
	)
	game.queue_free()
	session.queue_free()
	await process_frame
