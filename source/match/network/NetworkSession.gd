# gdlint: disable=max-returns,max-file-lines
extends Node

## ENet carries only the typed protocol. This node owns one live authoritative
## simulation, or one disabled replica. It survives menu -> battle transitions.
signal changed
signal battle_started
signal command_resolved(command)
signal frame_received(tick)
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
const Boundary = preload("res://source/match/network/SimulationBoundary.gd")
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")
const Digest = preload("res://source/match/network/ReplicaDigest.gd")
const Replay = preload("res://source/match/network/ReplayFile.gd")
const Builder = preload("res://source/match/network/PacketBuilder.gd")
const Reader = preload("res://source/match/network/PacketReader.gd")
const PORT = 28761
const STATE_INTERVAL = 6
const RECONNECT_SECONDS = 30.0
const TERMINAL_DRAIN_MSEC = 1000
var authority = false
var local_slot = -1
var applying = false
var game
var replica
var peer: ENetMultiplayerPeer
var boundary = Boundary.new()
var registry = Frame.new()
var router
var status = ""
var error = ""
var address = "127.0.0.1"
var port = PORT
var spectator = false
var reconnect_token = ""
var settings
var recording_path = ""
var last_hash = ""
var received_tick = 0
var rejected_commands = 0
var desyncs = 0
var peers = {}
var terminal_receipts = {}
var terminal_confirmed = false
var _view_hash = ""
var _tokens = {}
var _last_state = {}
var _sequence = 0
var _hello_sent = false
var _connect_started_ms = 0
var _initializing = false
var _last_send_tick = 0
var _last_full_tick = 0
var _replay
var _retry_left = 0.0
var _reconnect_left = RECONNECT_SECONDS
var _closing = false
var _finished_sent = false
var _builder
var _task = -1
var _definitions = {}
var _full_bytes = PackedByteArray()
var _record_commands = []
var _terminal_queued = false
var _terminal_ack = {}
var _reader
var _read_task = -1
var _incoming = []
var _needs_full = false
var _ingress = {}
var _pause_epoch = 0
var _local_intents = []
var _flush_scheduled = false
var _previous_physics_ticks = -1
var _bootstrap_resync_at = 0


static func current(tree):
	return tree.root.get_node_or_null("NetworkSession")


static func create(tree):
	var existing = current(tree)
	if existing != null:
		existing.shutdown()
		existing.free()
	var session = load("res://source/match/network/NetworkSession.gd").new()
	session.name = "NetworkSession"
	tree.root.add_child(session)
	return session


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100000
	router = load("res://source/match/network/CommandRouter.gd").new()
	router.session = self


func host(match_settings, listen_port: int = PORT, dedicated: bool = false) -> bool:
	if listen_port < 1024 or listen_port > 65535:
		return _fail("Choose a port from 1024 to 65535.")
	authority = true
	local_slot = -1 if dedicated else 0
	settings = match_settings
	port = listen_port
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(port, 16, 3) != OK:
		return _fail("Could not host on this port. Choose another port.")
	peer.peer_connected.connect(_connected)
	peer.peer_disconnected.connect(_disconnected)
	status = (
		tr("Dedicated server hosting on port %d") % port
		if dedicated
		else tr("Hosting on port %d · waiting for a commander") % port
	)
	changed.emit()
	return true


func join(host_address: String, listen_port: int = PORT, watch: bool = false) -> bool:
	if (
		host_address.length() > 253
		or host_address.strip_edges().is_empty()
		or listen_port < 1024
		or listen_port > 65535
	):
		return _fail("Enter a host address and a port from 1024 to 65535.")
	authority = false
	if _definitions.is_empty():
		_prime_definitions()
	address = host_address.strip_edges()
	port = listen_port
	spectator = watch
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(address, port, 3) != OK:
		return _fail("Could not connect to this host.")
	peer.peer_connected.connect(_connected)
	_hello_sent = false
	_connect_started_ms = Time.get_ticks_msec()
	status = "Connecting…"
	changed.emit()
	return true


func _connected(id: int):
	# Building a large battlefield briefly blocks polling on slower machines.
	# ENet's ordinary five-second minimum can drop a healthy loading peer.
	# Keep this grace bounded; the first applied frame restores normal timeouts.
	peer.get_peer(id).set_timeout(32, 30000, 60000)


func _finish_loading_peer(id: int):
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		peer.get_peer(id).set_timeout(32, 5000, 30000)


func _process(delta):
	_collect_packet()
	_collect_incoming()
	if _closing or peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.poll()
	if (
		not authority
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		and not _hello_sent
	):
		_send(
			1,
			{
				"type": "hello",
				"version": Protocol.VERSION,
				"spectator": spectator,
				"token": reconnect_token
			}
		)
		_hello_sent = true
		_bootstrap_resync_at = Time.get_ticks_msec() + 1000
		status = "Waiting for the host…"
		changed.emit()
	var count = 0
	while (
		peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
		and peer.get_available_packet_count() > 0
		and count < 128
	):
		var sender = peer.get_packet_peer()
		var packet = peer.get_packet()
		_receive(sender, packet)
		count += 1
	if (
		not authority
		and not is_instance_valid(game)
		and not _initializing
		and not reconnect_token.is_empty()
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		and Time.get_ticks_msec() >= _bootstrap_resync_at
	):
		# Recovery must also work before the first state/delta was received.
		# The host can resend its cached full frame even while an encoder is busy.
		_bootstrap_resync_at = Time.get_ticks_msec() + 1000
		_send(1, {"type": "resync"})
	if (
		not authority
		and not reconnect_token.is_empty()
		and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
	):
		_reconnect_left -= delta
		_retry_left -= delta
		if _reconnect_left <= 0:
			_fail("Connection lost. Return to the menu to join another battle.")
			if peer != null:
				peer.close()
			peer = null
			return
		if (
			_retry_left <= 0
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
		):
			status = tr("Connection lost · reconnecting for %.0f s") % _reconnect_left
			changed.emit()
			_retry_left = 2.0
			peer.close()
			join(address, port, spectator)
	if (
		not authority
		and reconnect_token.is_empty()
		and Time.get_ticks_msec() - _connect_started_ms > 8000
	):
		if (
			peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
			or local_slot < 0 and not spectator
		):
			_fail("Could not connect to this host.")
			if peer != null:
				peer.close()
			peer = null
	if authority:
		for token in _tokens.keys():
			if _tokens[token].peer == 0 and _tokens[token].until < Time.get_ticks_msec():
				_tokens.erase(token)


func _receive(sender: int, bytes: PackedByteArray):
	if authority:
		# Commander intents are much smaller than state frames. Apply this bound
		# before JSON parsing, including handshakes and unsupported messages.
		var second = Time.get_ticks_msec() / 1000
		var budget = _ingress.get(sender, {"second": second, "count": 0, "bytes": 0})
		if budget.second != second:
			budget = {"second": second, "count": 0, "bytes": 0}
		budget.count += 1
		budget.bytes += bytes.size()
		_ingress[sender] = budget
		if (
			budget.count > 128
			or budget.bytes > 1024 * 1024
			or bytes.size() > Protocol.MAX_INTENT_BYTES
		):
			return
	if not authority and sender == 1:
		if bytes.is_empty() or bytes.size() > Protocol.MAX_BYTES:
			return
		if _incoming.size() >= 8:
			_incoming.clear()
			_needs_full = true
			_send(1, {"type": "resync"})
		_incoming.append(bytes)
		return
	var protocol = Protocol.new()
	var packet = protocol.decode(bytes)
	if not packet is Dictionary or not packet.get("type") is String:
		_reject(sender, "Invalid packet.")
		return
	_receive_decoded(sender, packet)


func _receive_decoded(sender: int, packet: Dictionary):
	var protocol = Protocol.new()
	if authority:
		match packet.type:
			"hello":
				_hello(sender, packet)
			"intent":
				if (
					not peers.has(sender)
					or peers[sender].slot < 0
					or packet.keys().size() != 3
					or not packet.get("seq") is int
					or not protocol.valid_intent(packet.get("intent"))
				):
					_reject(sender, "Invalid or spectator command.")
					return
				_queue(peers[sender].slot, packet.seq, packet.intent, sender)
			"ready":
				if peers.has(sender) and packet.keys().size() == 1:
					peers[sender].ready = true
					_finish_loading_peer(sender)
			"terminal_ack":
				if (
					peers.has(sender)
					and _finished_sent
					and is_instance_valid(game)
					and game.finished
					and packet.keys().size() == 3
					and packet.get("tick") is int
					and packet.get("hash") is String
					and packet.get("tick") == boundary.tick
					and packet.get("hash") == last_hash
				):
					peers[sender].terminal_ack = true
					# A commander can close their result immediately. Keep proof of
					# its exact terminal state after the live peer entry is removed.
					terminal_receipts[peers[sender].slot] = {
						"tick": packet.tick, "hash": packet.hash
					}
					_send(
						sender,
						{"type": "terminal_receipt", "tick": packet.tick, "hash": packet.hash}
					)
			"resync":
				if peers.has(sender) and not _full_bytes.is_empty():
					var now = Time.get_ticks_msec()
					if now - peers[sender].get("resync_at", 0) >= 1000:
						peers[sender].resync_at = now
						_send_bytes(sender, _full_bytes)
			_:
				_reject(sender, "Unsupported packet type.")
	elif sender == 1:
		match packet.type:
			"terminal_receipt":
				if (
					not _terminal_ack.is_empty()
					and packet.keys().size() == 3
					and packet.get("tick") is int
					and packet.get("hash") is String
					and packet.tick == received_tick
					and packet.hash == last_hash
					and {"tick": packet.tick, "hash": packet.hash} == _terminal_ack
				):
					terminal_confirmed = true
			"welcome":
				if (
					packet.get("version") != Protocol.VERSION
					or not packet.get("slot") is int
					or packet.slot < -1
					or packet.slot > 3
					or not packet.get("seq") is int
					or packet.seq < 0
					or not packet.get("token") is String
					or packet.token.length() != 64
				):
					return
				local_slot = packet.slot
				reconnect_token = packet.token
				_sequence = maxi(_sequence, packet.get("seq", 0))
				_reconnect_left = RECONNECT_SECONDS
				status = (
					"Spectator connected · shared vision"
					if local_slot < 0
					else "Commander connected · shared vision"
				)
				changed.emit()
			"pause":
				if (
					packet.get("value") is bool
					and packet.get("epoch") is int
					and packet.epoch >= _pause_epoch
					and is_instance_valid(game)
				):
					_pause_epoch = packet.epoch
					_set_pause(packet.value)
			"rejected":
				notice(str(packet.get("reason", "Command rejected.")))
			"lobby":
				status = str(packet.get("status", "Waiting for the host…"))
				changed.emit()


func _hello(sender: int, packet: Dictionary):
	if (
		packet.keys().size() != 4
		or packet.get("version") != Protocol.VERSION
		or not packet.get("spectator") is bool
		or not packet.get("token") is String
		or packet.token.length() not in [0, 64]
	):
		_reject(sender, "Incompatible lobby handshake.")
		return
	if peers.has(sender):
		return
	var token = packet.token
	var slot = -1
	if not token.is_empty():
		if not _tokens.has(token) or _tokens[token].expired or _tokens[token].peer != 0:
			_reject(sender, "Reconnect token is unavailable.")
			return
		slot = _tokens[token].slot
	elif not packet.spectator:
		if is_instance_valid(game):
			_reject(sender, "Battle is already running. Join as a spectator.")
			return
		slot = _next_available_slot()
		if slot < 0:
			_reject(sender, "The commander slot is occupied. Join as a spectator.")
			return
	if token.is_empty():
		token = Crypto.new().generate_random_bytes(32).hex_encode()
	_tokens[token] = {"slot": slot, "peer": sender, "until": 0, "expired": false}
	peers[sender] = {"slot": slot, "token": token}
	_send(
		sender,
		{
			"type": "welcome",
			"version": Protocol.VERSION,
			"slot": slot,
			"token": token,
			"seq": boundary.last_sequences.get(slot, 0)
		}
	)
	var total_commanders = peers.values().filter(func(entry): return entry.slot >= 0).size()
	if local_slot >= 0:
		total_commanders += 1
	status = (
		tr("%d commander connected · %d spectators")
		% [total_commanders, peers.values().filter(func(entry): return entry.slot < 0).size()]
	)
	changed.emit()
	if not _last_state.is_empty():
		_send_bytes(sender, _full_bytes)
	else:
		_send(sender, {"type": "lobby", "status": "Connected · waiting for the host to start"})


func _next_available_slot() -> int:
	if settings == null:
		return -1
	var start_slot = 0 if local_slot < 0 else 1
	for candidate in range(start_slot, settings.players.size()):
		if settings.players[candidate].get_meta("ai_commander", false):
			continue
		var occupied = peers.values().any(func(entry): return entry.slot == candidate)
		var reserved = _tokens.values().any(
			func(entry): return entry.slot == candidate and not entry.expired
		)
		if not occupied and not reserved:
			return candidate
	return -1


func is_ready_to_start() -> bool:
	if not authority or is_instance_valid(game) or settings == null:
		return false
	var start_slot = 0 if local_slot < 0 else 1
	var required_slots = 0
	for index in range(start_slot, settings.players.size()):
		if settings.players[index].get_meta("ai_commander", false):
			continue
		required_slots += 1
		var filled = peers.values().any(func(entry): return entry.slot == index)
		if not filled:
			return false
	return required_slots > 0 or local_slot >= 0


func start_battle(setup: Callable = Callable()) -> bool:
	if not is_ready_to_start():
		return _fail("Connect all required commanders before starting.")
	use_fixed_clock()
	var map = load(settings.map_path).instantiate()
	if not settings.scenario.is_empty():
		map.scenario = settings.scenario.duplicate(true)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = map
	game.set_meta("network_local_slot", local_slot)
	game.set_meta("network_session", self)
	var tree = get_tree()
	var previous = tree.current_scene
	tree.paused = true
	if is_instance_valid(previous):
		previous.queue_free()
		await previous.tree_exited
	tree.root.add_child(game)
	tree.current_scene = game
	var cached_players = game.get_cached_group("players")
	for index in cached_players.size():
		var player = cached_players[index]
		var is_local_human = local_slot >= 0 and index == local_slot
		var is_ai = (
			index < settings.players.size()
			and settings.players[index].get_meta("ai_commander", false)
		)
		if not is_local_human and not is_ai:
			player.set_process(false)
			player.set_physics_process(false)
	if setup.is_valid():
		applying = true
		setup.call(game)
		applying = false
	# Navigation publication must settle without advancing either commander.
	for index in 8:
		await tree.process_frame
		await tree.physics_frame
	var initial = registry.capture(game)
	if initial.is_empty():
		return _fail(registry.error)
	_last_state = initial
	last_hash = Frame.hash_state(initial)
	DirAccess.make_dir_recursive_absolute("user://replays")
	recording_path = (
		"user://replays/battle-%d-%d.rtsreplay"
		% [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	)
	_replay = Replay.new()
	var metadata = {
		"protocol": Protocol.VERSION,
		"tick_rate": 60,
		"authority": "server",
		"shared_vision": true,
		"initial": Values.new().encode(initial)
	}
	if not _replay.begin(recording_path, metadata):
		notice(_replay.error)
		_replay = null
	_prime_definitions()
	var first = Builder.new()
	first.prepare(_packet_job(initial, true))
	if first.result.has("error"):
		return _fail(first.result.error)
	_commit_packet(first.result)
	tree.paused = false
	status = "Battle running · shared vision"
	changed.emit()
	battle_started.emit()
	return true


func _physics_process(_delta):
	if authority and is_instance_valid(game) and game.finished:
		if not _finished_sent and not _terminal_queued and _task < 0:
			boundary.tick += 1
			_terminal_queued = true
			_publish()
		return
	if not authority or not is_instance_valid(game) or get_tree().paused or game.restoring:
		return
	var results = boundary.advance(router.apply)
	for command in results:
		command_resolved.emit(command)
		if _replay != null:
			_record_commands.append({"tick": boundary.tick, "command": command.duplicate(true)})
		if not command.result:
			_reject(_peer_for_slot(command.slot), router.error)
	if boundary.tick % STATE_INTERVAL == 0 and _task < 0:
		_publish()


func _prime_definitions():
	var depth = load("res://source/match/saves/GameplayDepthSchema.gd").new()
	var catalog = load("res://source/match/BastionCatalog.gd")
	_definitions._sites = {}
	_definitions._relays = {}
	var sites = load("res://source/match/world/PointOfInterestCatalog.gd")
	var layouts = load("res://source/match/maps/terrain/BattlefieldRegistry.gd")
	for map_path in load("res://source/match/MatchConstants.gd").MAPS:
		_definitions._sites[map_path] = sites.definitions(map_path).duplicate(true)
		_definitions._relays[map_path] = layouts.layout(map_path).get("relays", []).size()
	for faction in ["bastion", "helix", "frontier"]:
		for role in catalog.NAMES:
			_definitions[faction + ":" + role] = depth.definitions(role, faction).duplicate(true)
		for role in catalog.MISSION_NAMES:
			_definitions[faction + ":" + role] = depth.definitions(role, faction).duplicate(true)


func _packet_job(snapshot: Dictionary, full: bool) -> Dictionary:
	return {
		"snapshot": snapshot,
		"previous": _last_state,
		"definitions": _definitions,
		"tick": boundary.tick,
		"base": _last_send_tick,
		"full": full,
		"paused": get_tree().paused,
		"pause_epoch": _pause_epoch,
		"finished": game.finished,
		"outcome": game.result
	}


func _publish():
	# One immutable job in flight bounds memory and sheds obsolete captures.
	if _task >= 0:
		return
	var captured = registry.capture(game, false)
	if captured.is_empty():
		_fail(registry.error)
		return
	if _builder == null:
		_builder = Builder.new()
	_task = WorkerThreadPool.add_task(
		_builder.prepare.bind(
			_packet_job(captured, game.finished or boundary.tick - _last_full_tick >= 120)
		)
	)


func _collect_packet():
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	# Completed-task join is a memory barrier, never a wait on active gameplay.
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var prepared = _builder.result
	if prepared.has("error"):
		_fail(prepared.error)
		return
	_commit_packet(prepared)


func _commit_packet(prepared: Dictionary):
	for id in peers:
		_send_bytes(id, prepared.bytes)
	_flush_commands(prepared.tick)
	if (
		_replay != null
		and not _replay.append_prepared(Replay.FRAME, prepared.tick, prepared.record)
	):
		notice(_replay.error)
		_finish_recording()
	_last_state = prepared.snapshot
	_last_send_tick = prepared.tick
	if prepared.full:
		_last_full_tick = prepared.tick
	last_hash = prepared.hash
	_full_bytes = prepared.full_bytes
	if prepared.finished:
		_finished_sent = true
		_finish_recording()


func _flush_commands(through_tick: int):
	while not _record_commands.is_empty() and _record_commands[0].tick <= through_tick:
		var entry = _record_commands.pop_front()
		if _replay != null:
			_replay.append(Replay.COMMAND, entry.tick, entry.command)


func _collect_incoming():
	if _read_task >= 0 and WorkerThreadPool.is_task_completed(_read_task):
		WorkerThreadPool.wait_for_task_completion(_read_task)
		_read_task = -1
		var decoded = _reader.result
		if decoded.get("resync", false):
			_send(1, {"type": "resync"})
		if decoded.has("error"):
			notice(decoded.error)
		elif decoded.has("snapshot"):
			_apply_frame(decoded.packet, decoded.snapshot)
		elif decoded.has("packet"):
			_receive_decoded(1, decoded.packet)
	if _read_task < 0 and not _initializing and not _incoming.is_empty():
		if _reader == null:
			_reader = Reader.new()
		_read_task = WorkerThreadPool.add_task(
			_reader.decode.bind(
				{
					"bytes": _incoming.pop_front(),
					"tick": received_tick,
					"previous": replica.state if replica != null else {},
					"definitions": _definitions,
					"needs_full": _needs_full
				}
			)
		)


func _apply_frame(packet: Dictionary, snapshot: Dictionary):
	use_fixed_clock()
	_needs_full = false
	applying = true
	if replica == null:
		_initializing = true
		replica = load("res://source/match/network/AuthoritativeReplica.gd").new()
		var ok = await replica.initialize(get_tree(), snapshot, local_slot, self, true)
		_initializing = false
		if not ok:
			applying = false
			_fail(replica.error)
			return
		game = replica.game
		# Service acknowledgements accumulated during synchronous scene setup
		# before returning to the shorter live-match timeout.
		if peer != null:
			peer.poll()
		_send(1, {"type": "ready"})
		_finish_loading_peer(1)
		battle_started.emit()
	else:
		if not replica.apply(snapshot, true):
			applying = false
			_fail(replica.error)
			return
	applying = false
	received_tick = packet.tick
	last_hash = packet.hash
	_view_hash = packet.get("view_hash", "")
	var verified = verify_replica()
	if packet.pause_epoch >= _pause_epoch:
		_pause_epoch = packet.pause_epoch
		_set_pause(packet.paused)
	if packet.finished and verified and not game.finished:
		game.finished = true
		game.result = _local_result(snapshot)
		if local_slot >= 0:
			game.hud.show_result(game.result)
		else:
			game.hud.show_notice("Battle ended.")
	if packet.finished:
		if verified:
			var receipt = {"tick": received_tick, "hash": last_hash}
			if receipt != _terminal_ack:
				terminal_confirmed = false
				_terminal_ack = receipt
			_send(1, {"type": "terminal_ack", "tick": received_tick, "hash": last_hash})
		else:
			_terminal_ack.clear()
			terminal_confirmed = false
	frame_received.emit(received_tick)


func submit(intent: Dictionary) -> bool:
	# Direct commands (including pause) retain their order relative to a group
	# gesture waiting for the end of the current input callback.
	_flush_local_intents()
	if not _can_submit():
		return false
	var protocol = Protocol.new()
	if not protocol.valid_intent(intent):
		notice(protocol.error)
		return false
	_sequence += 1
	if authority:
		return _queue(local_slot, _sequence, intent, 0)
	_send(1, {"type": "intent", "seq": _sequence, "intent": intent})
	return true


func use_fixed_clock():
	if _previous_physics_ticks < 0:
		_previous_physics_ticks = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = Boundary.TICKS_PER_SECOND


func submit_group_member(intent: Dictionary) -> bool:
	if not _can_submit():
		return false
	var protocol = Protocol.new()
	if not protocol.valid_intent(intent) or intent.kind in ["batch", "pause", "surrender"]:
		notice("Invalid grouped command.")
		return false
	if _local_intents.size() >= Protocol.MAX_GROUP_ENTRIES:
		_flush_local_intents()
	_local_intents.append(intent.duplicate(true))
	if not _flush_scheduled:
		_flush_scheduled = true
		_flush_local_intents.call_deferred()
	return true


func _flush_local_intents():
	_flush_scheduled = false
	if _local_intents.is_empty():
		return
	var entries = _local_intents
	_local_intents = []
	submit(entries[0] if entries.size() == 1 else Protocol.pack_batch(entries))


func _can_submit() -> bool:
	if (
		_closing
		or not is_instance_valid(game)
		or spectator
		or local_slot < 0
		or game.finished
		or (
			not authority
			and (
				peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
			)
		)
	):
		notice("Spectators and disconnected commanders cannot issue orders.")
		return false
	return true


func _queue(slot: int, sequence: int, intent: Dictionary, sender: int) -> bool:
	if not is_instance_valid(game):
		return false
	if intent.kind == "pause":
		if slot != 0:
			_reject(sender, "Only the host can pause the battle.")
			return false
		_pause_epoch += 1
		_set_pause(intent.value)
		for id in peers:
			_send(id, {"type": "pause", "value": intent.value, "epoch": _pause_epoch})
		return true
	if not boundary.enqueue(slot, sequence, intent):
		_reject(sender, boundary.error)
		return false
	return true


func _set_pause(value: bool):
	get_tree().paused = value
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud._pause_owned = value
		game.hud._refresh_shortcuts()


func entities() -> Dictionary:
	return registry.entities if authority else (replica.entities if replica != null else {})


func id_for(node) -> String:
	if not is_instance_valid(node):
		return ""
	if authority:
		return registry.id_for(node)
	for id in entities():
		if entities()[id] == node:
			return id
	return ""


func notice(message: String):
	status = message
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.show_notice(message)
	changed.emit()


func _send(id: int, packet: Dictionary):
	if (
		peer == null
		or (not authority and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED)
	):
		return
	var codec = Protocol.new()
	var bytes = codec.encode(packet)
	if bytes.is_empty():
		_fail(codec.error)
		return
	_send_bytes(id, bytes)


func _send_bytes(id: int, bytes: PackedByteArray):
	if peer == null or bytes.is_empty():
		return
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.transfer_channel = 0
	peer.put_packet(bytes)


func _reject(id: int, reason: String):
	rejected_commands += 1
	if id > 0:
		_send(id, {"type": "rejected", "reason": reason})
	else:
		notice(reason)


func _peer_for_slot(slot: int) -> int:
	for id in peers:
		if peers[id].slot == slot:
			return id
	return 0


func _disconnected(id: int):
	_ingress.erase(id)
	if not peers.has(id):
		return
	var entry = peers[id]
	_tokens[entry.token].peer = 0
	_tokens[entry.token].until = Time.get_ticks_msec() + int(RECONNECT_SECONDS * 1000)
	peers.erase(id)
	notice(
		(
			"Commander disconnected · battle continues; reconnect within 30 s"
			if entry.slot >= 0
			else "Spectator disconnected"
		)
	)


func _finish_recording():
	if _replay != null:
		_replay.finish(boundary.tick, last_hash)
		_replay = null


func _terminal_waiting() -> bool:
	if authority:
		# Keep servicing the confirmation until the guest closes, including
		# simultaneous result-view exits. The drain still has a hard deadline.
		return _finished_sent and is_instance_valid(game) and game.finished and not peers.is_empty()
	return not _terminal_ack.is_empty() and not terminal_confirmed


func _drain_terminal():
	# Reliable packets still need ENet service after put_packet(). Only final
	# receipts are serviced during teardown; gameplay and ordinary exits never
	# wait here. Confirmation prevents close() from discarding the final ACK.
	if (
		peer == null
		or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
		or not _terminal_waiting()
	):
		return
	if not authority:
		_send(1, {"type": "terminal_ack", "tick": _terminal_ack.tick, "hash": _terminal_ack.hash})
	var transport = peer
	var deadline = Time.get_ticks_msec() + TERMINAL_DRAIN_MSEC
	var remaining = 128
	var protocol = Protocol.new()
	while (
		Time.get_ticks_msec() < deadline
		and remaining > 0
		and _terminal_connected(transport)
		and _terminal_waiting()
	):
		transport.get_host().flush()
		transport.poll()
		if not _terminal_connected(transport):
			break
		while transport.get_available_packet_count() > 0 and remaining > 0:
			var sender = transport.get_packet_peer()
			var bytes = transport.get_packet()
			remaining -= 1
			if bytes.size() > 256:
				continue
			var packet = protocol.decode(bytes)
			if not packet is Dictionary:
				continue
			if authority and packet.get("type") == "terminal_ack":
				_receive(sender, bytes)
			elif not authority and sender == 1 and packet.get("type") == "terminal_receipt":
				_receive_decoded(sender, packet)
		if _terminal_waiting():
			OS.delay_msec(1)
	if _terminal_connected(transport):
		transport.get_host().flush()


func _terminal_connected(transport) -> bool:
	return (
		peer == transport
		and transport != null
		and transport.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	)


func shutdown():
	_local_intents.clear()
	if _closing:
		get_tree().paused = false
		return
	_closing = true
	# Only teardown joins unfinished work. No Node or ENet access occurs there.
	if _read_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_read_task)
		_read_task = -1
	_incoming.clear()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var prepared = _builder.result
		if not prepared.has("error"):
			_commit_packet(prepared)
	if authority and is_instance_valid(game) and _replay != null:
		var final = registry.capture(game, false)
		if not final.is_empty() and boundary.tick > _last_send_tick:
			var last = Builder.new()
			last.prepare(_packet_job(final, true))
			if not last.result.has("error"):
				_commit_packet(last.result)
	_finish_recording()
	_reader = null
	_builder = null
	_drain_terminal()
	if peer != null:
		peer.close()
	peer = null
	if is_instance_valid(game):
		game.remove_meta("network_session")
	if _previous_physics_ticks > 0:
		Engine.physics_ticks_per_second = _previous_physics_ticks
		_previous_physics_ticks = -1
	get_tree().paused = false


func _exit_tree():
	shutdown()


func _fail(message: String) -> bool:
	error = message
	# A fatal active-session error must release its clock while leaving the
	# displayed match paused/read-only until the player returns through its menu.
	if _previous_physics_ticks > 0:
		shutdown()
		if is_instance_valid(game):
			game.set_meta("network_session", self)
			get_tree().paused = true
	notice(message)
	return false


func verify_replica() -> bool:
	if replica == null or Digest.live(replica) != _view_hash:
		desyncs += 1
		notice("Replica state diverged. Requesting an authoritative refresh.")
		_send(1, {"type": "resync"})
		return false
	return true


func _local_result(snapshot: Dictionary) -> String:
	var survivors = snapshot.players.filter(
		func(side):
			return (
				side.command_left > 0.0
				and snapshot.units.any(func(unit): return unit.player == side.id)
			)
	)
	if survivors.is_empty():
		return "Draw"
	var viewer = entities().get("player-%d" % maxi(0, local_slot))
	return (
		"Victory"
		if survivors.any(func(side): return viewer.is_allied_with(entities()[side.id]))
		else "Defeat"
	)
