extends SceneTree

var session
var failures = []
var _deadline = 0
var _is_host = false


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
	var offline_hz = Engine.physics_ticks_per_second
	root.get_node("SaveManager").autosaves_enabled = false
	_is_host = "--network-host" in OS.get_cmdline_user_args()
	_deadline = Time.get_ticks_msec() + 60000
	session = load("res://source/match/network/NetworkSession.gd").create(self)
	session.changed.connect(func(): print("STATUS ", session.status))
	if _is_host:
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.advanced_start = true
		settings.map_path = "res://source/match/maps/BastionDesert.tscn"
		settings.visibility = settings.Visibility.FULL
		settings.starting_resources_multiplier = 4
		settings.match_seed = 314159
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = "bastion" if index == 0 else "frontier"
			side.color = root.get_node("Constants").Player.COLORS[index]
			settings.players.append(side)
		_check(session.host(settings, _port(28971)), "Could not host")
		print("NETWORK_READY port=", session.port)
		while not _participants_ready() and _waiting():
			await process_frame
		_check(
			await session.start_battle(_transport_fixture), "Host could not start: " + session.error
		)
		_check(
			Engine.physics_ticks_per_second == session.boundary.TICKS_PER_SECOND,
			"Host clock differs from its boundary"
		)
		var accepted = []
		session.command_resolved.connect(func(command): accepted.append(command))
		var paused_once = false
		var mounted_seen = false
		var passenger_fired = false
		while session.boundary.tick < 1800 and _waiting():
			var rider = _unit("RocketInfantry", "player-1")
			if rider != null and rider.has_meta("garrison_host"):
				if not mounted_seen:
					_transport_hidden(rider, "host")
					mounted_seen = true
				passenger_fired = (
					passenger_fired
					or (
						rider.get_meta("next_attack_availability_time", 0)
						> int(session.game.simulation_time * 1000)
					)
				)
			if not paused_once and session.boundary.tick >= 180:
				paused_once = true
				session.submit({"kind": "pause", "value": true})
				var before = session.game.simulation_time
				await create_timer(.4, true, false, true).timeout
				_check(
					session.game.simulation_time == before and paused,
					"Host pause advanced authority time"
				)
				session.submit({"kind": "pause", "value": false})
			await process_frame
		_check(
			accepted.any(func(command): return _accepted_kind(command, "produce")),
			"No authoritative production command"
		)
		_check(
			accepted.any(func(command): return _accepted_kind(command, "order")),
			"No authoritative movement command"
		)
		_check(
			accepted.any(func(command): return _accepted_kind(command, "ability")),
			"No authoritative ability command"
		)
		_check(mounted_seen and passenger_fired, "Host never hid and fired the mounted passenger")
		_check(session.rejected_commands > 0, "Forged ownership was not rejected")
		print(
			"HOST commands=",
			accepted.size(),
			" rejected=",
			session.rejected_commands,
			" tick=",
			session.boundary.tick,
			" replay=",
			session.recording_path
		)
	else:
		_check(
			session.join(
				"127.0.0.1", _port(28971), "--network-spectator" in OS.get_cmdline_user_args()
			),
			"Could not join"
		)
		while not is_instance_valid(session.game) and _waiting():
			await process_frame
		if is_instance_valid(session.game) and "--network-spectator" in OS.get_cmdline_user_args():
			_check(
				Engine.physics_ticks_per_second == session.boundary.TICKS_PER_SECOND,
				"Spectator clock differs"
			)
			_check(session.local_slot == -1, "Spectator received commander ownership")
			_check(
				not session.submit({"kind": "surrender"}), "Spectator accepted a gameplay intent"
			)
			var saw_mounted = false
			while session.received_tick < 600 and _waiting():
				var rider = _unit("RocketInfantry", "player-1")
				if rider != null and rider.has_meta("garrison_host") and not saw_mounted:
					_transport_hidden(rider, "spectator")
					saw_mounted = true
				await process_frame
			_check(saw_mounted, "Spectator never received mounted transport state")
			_check(
				session.registry.hash_state(session.replica.state) == session.last_hash,
				"Spectator stream checksum differs"
			)
			_world_state_checks()
			print("SPECTATOR tick=", session.received_tick, " hash=", session.last_hash)
		elif is_instance_valid(session.game):
			_check(
				Engine.physics_ticks_per_second == session.boundary.TICKS_PER_SECOND,
				"Guest clock differs"
			)
			var human = session.game._get_human_player()
			_check(
				session.local_slot == 1 and human == session.entities().get("player-1"),
				"Remote commander owns wrong side"
			)
			while _unit("AdvancedTank", "player-1") == null and _waiting():
				await process_frame
			var rig = _unit("AdvancedTank", "player-1")
			var rider = _unit("RocketInfantry", "player-1")
			rider.manual_orders.submit(
				{"kind": "garrison", "point": rig.position, "target": weakref(rig)}
			)
			var worker = _unit("Worker", "player-1")
			var hq = _unit("CommandCenter", "player-1")
			var infantry = _unit("Tank", "player-1")
			var old_position = worker.position
			var point = worker.position + Vector3(0, 0, -5)
			var count = human.live_units().filter(func(unit): return unit.type == "Worker").size()
			var tanks_before = (
				human.live_units().filter(func(unit): return unit.type == "Tank").size()
			)
			var materials = human.resource_a
			var gate = load("res://source/match/network/NetworkGate.gd")
			worker.manual_orders.submit({"kind": "move", "point": point})
			hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
			infantry.abilities.trigger("smoke_screen")
			session.submit(
				{
					"kind": "produce",
					"unit": gate.id_for(_unit("VehicleFactory", "player-1")),
					"role": "Tank"
				}
			)
			session.submit(
				{
					"kind": "produce",
					"unit": gate.id_for(_unit("CommandCenter", "player-0")),
					"role": "Worker"
				}
			)
			var max_jobs = 0
			var saw_batch = false
			var saw_ability = false
			var saw_pause = false
			var pause_epoch = -1
			var saw_mounted = false
			var unloaded = false
			var rig_origin = rig.position
			var reconnected = false
			var desync_checked = false
			var token = session.reconnect_token
			while session.received_tick < 1560 and _waiting():
				if rider.has_meta("garrison_host") and not saw_mounted:
					_transport_hidden(rider, "guest")
					saw_mounted = true
					rig.manual_orders.submit(
						{"kind": "move", "point": rig.position + Vector3(4, 0, 0)}
					)
				if session.received_tick >= 420 and not desync_checked:
					desync_checked = true
					human.resource_a += 1
					_check(not session.verify_replica(), "Live replica tampering was not detected")
				if session.received_tick >= 600 and not unloaded:
					unloaded = true
					session.submit(
						{
							"kind": "order",
							"units": [session.id_for(rider)],
							"order": "stop",
							"point": [42000, 0, 30000]
						}
					)
				if paused and session._pause_epoch > 0 and not saw_pause:
					saw_pause = true
					pause_epoch = session._pause_epoch
					session.submit({"kind": "pause", "value": false})
				if saw_pause and session._pause_epoch == pause_epoch:
					_check(paused, "An older state frame overrode the host pause")
				if session.received_tick >= 300 and not reconnected:
					reconnected = true
					session.peer.close()
				max_jobs = maxi(max_jobs, hq.production_queue._queue.size())
				for job in _unit("VehicleFactory", "player-1").production_queue._queue:
					saw_batch = saw_batch or job.batch_count == 2
				saw_ability = (
					saw_ability or infantry.abilities.get_ability("smoke_screen").cooldown_left > 0
				)
				await process_frame
			_check(
				(
					saw_mounted
					and unloaded
					and not rider.has_meta("garrison_host")
					and rider.visible
					and rider.get_node("Geometry").is_visible_in_tree()
				),
				"Guest unload did not restore one visible infantry body"
			)
			_check(rig.position.distance_to(rig_origin) > 1.0, "Mounted transport never moved")
			_check(
				desync_checked and session.desyncs == 1 and session.verify_replica(),
				"Replica desync did not recover with exact live state"
			)
			_check(saw_pause, "Host pause did not reach the remote client")
			_check(
				reconnected and session.reconnect_token == token, "Reconnect lost commander token"
			)
			_check(
				worker.position.distance_to(old_position) > 1.0, "Replicated worker did not move"
			)
			_check(max_jobs > 0, "Replicated queue never received paid job")
			_check(
				(
					saw_batch
					and (
						human.live_units().filter(func(unit): return unit.type == "Tank").size()
						== tanks_before + 2
					)
				),
				"Paid Frontier pair was not queued and spawned through replication"
			)
			_world_state_checks()
			_check(human.resource_a < materials, "Replicated production did not charge resources")
			_check(saw_ability, "Replicated ability cooldown never activated")
			_check(
				(
					human.live_units().filter(func(unit): return unit.type == "Worker").size()
					== count + 1
				),
				"Production never spawned a live worker"
			)
			_check(
				session.registry.hash_state(session.replica.state) == session.last_hash,
				"Client state hash diverged"
			)
			print(
				"CLIENT tick=",
				session.received_tick,
				" entities=",
				session.entities().size(),
				" hash=",
				session.last_hash
			)
	session.shutdown()
	_check(
		Engine.physics_ticks_per_second == offline_hz, "Session did not restore its offline clock"
	)
	OS.remove_logger(logger)
	failures.append_array(logger.messages)
	for message in failures:
		push_error(message)
	print("Network session ", "host" if _is_host else "client", ": ", failures.size(), " failures")
	if is_instance_valid(session.game):
		session.game.queue_free()
	await process_frame
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _unit(role, owner):
	for node in session.entities().values():
		if (
			is_instance_valid(node)
			and "type" in node
			and node.type == role
			and "player" in node
			and node.player == session.entities().get(owner)
		):
			return node
	return null


func _accepted_kind(command: Dictionary, kind: String) -> bool:
	if not command.result:
		return false
	if command.intent.kind == "batch":
		return command.intent.intents.any(func(entry): return entry.kind == kind)
	return command.intent.kind == kind


func _port(fallback: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-port="):
			return int(argument.trim_prefix("--network-port="))
	return fallback


func _participants_ready() -> bool:
	var commanders = session.peers.values().any(func(entry): return entry.slot == 1)
	var spectator = session.peers.values().any(func(entry): return entry.slot == -1)
	return (
		commanders and (spectator or "--network-expect-spectator" not in OS.get_cmdline_user_args())
	)


func _check(value, message):
	if not value:
		failures.append(message)


func _waiting():
	if Time.get_ticks_msec() >= _deadline:
		_check(false, "Network test exceeded wall-clock deadline: " + session.error)
		return false
	return true


func _transport_fixture(game):
	var catalog = load("res://source/match/FactionCatalog.gd")
	var players = game.get_cached_group("players")
	for entry in [
		["AdvancedTank", players[1], Vector3(42, 0, 30)],
		["RocketInfantry", players[1], Vector3(44, 0, 30)],
		["Tank", players[0], Vector3(42, 0, 36)]
	]:
		var unit = load(catalog.scene_path(entry[1].faction, entry[0])).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), entry[2]), entry[1], false)
		if entry[0] != "RocketInfantry":
			unit.stance = unit.Stance.HOLD_FIRE

	var plant = load(catalog.scene_path(players[0].faction, "PowerPlant")).instantiate()
	game._setup_and_spawn_unit(plant, Transform3D(Basis(), Vector3(25, 0, 25)), players[0], false)
	plant.hp = 0.0
	game.engineering._spawn_emplacement(
		players[0], "bunker", Vector3(30, 0, 40), 0.0, "engineering-bunker-1"
	)
	game.engineering._next_id = 2
	var sites = load("res://source/match/world/PointOfInterestCatalog.gd").sites(game)
	sites[0].captured_by = players[1]
	sites[0].stock_a = 321
	sites[0].income_left = 2.0


func _world_state_checks():
	var snapshot = session.replica.state
	var ruins = snapshot.get("obstacles", []).filter(func(row): return row.role == "StructureRuin")
	_check(not ruins.is_empty(), "Persistent structural ruin was omitted")
	if not ruins.is_empty():
		var ruin = session.entities().get(ruins[0].id)
		_check(
			(
				is_instance_valid(ruin)
				and ruin.age == ruins[0].ruin.age
				and ruin.materials == ruins[0].ruin.materials
			),
			"Ruin state was not applied to its persistent obstacle"
		)
	var bunker = session.entities().get("engineering-bunker-1")
	_check(
		is_instance_valid(bunker) and bunker.garrison_mount.capacity == 6,
		"Engineering six-slot bunker was not replicated"
	)
	var saved = snapshot.mission.points_of_interest[0]
	var site = session.entities().get(saved.id)
	_check(
		(
			is_instance_valid(site)
			and site.captured_by == session.entities().get("player-1")
			and site.stock_a == saved.stock_a
			and site.income_left == saved.income_left
		),
		"Economic site ownership/income/stock was not replicated"
	)


func _transport_hidden(rider, label):
	var rules = load("res://source/match/combat/CombatRules.gd")
	var shooter = _unit("Tank", "player-0")
	_check(
		not rider.visible and not rider.get_node("Geometry").is_visible_in_tree(),
		label + " passenger model is visible"
	)
	_check(not rules.can_target(shooter, rider), label + " passenger remains an independent target")
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			rider._native_state != null and shooter._native_state != null,
			label + " silently skipped native state"
		)
		_check(
			shooter._native_state.can_target(rider, false) == 0,
			label + " native target filter exposed passenger"
		)
	_check(rider.collision_layer == 0, label + " passenger retained a collision body")
