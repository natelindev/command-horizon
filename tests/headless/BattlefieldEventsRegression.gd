extends "res://tests/headless/UnitAnimationRegression.gd"

const MAP_NAMES = [
	"DesertFrontier",
	"RedrockDivide",
	"Emberworks",
	"RailspireJunction",
	"CoastalFoundry",
	"SunkenExchange",
	"AlpineRelay",
	"GlacierNarrows"
]
var _announcements = []
var _restored = {}


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for map_name in MAP_NAMES:
		await _event_fixture(map_name)
		_test_map(map_name)
		if map_name == "DesertFrontier":
			await _test_lifecycle()
		elif map_name == "RedrockDivide":
			_test_blocked()
		elif map_name == "AlpineRelay":
			await _test_radar()
		await _close()
		paused = false
	for message in _errors:
		push_error(message)
	print("Battlefield events regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _event_fixture(map_name):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.battlefield_events = true
	settings.match_seed = 311
	settings.map_path = "res://source/match/maps/battlefields/%sMap.tscn" % map_name
	var definition = load(settings.map_path.get_basename() + ".gd").DEFINITION
	for side in definition.players:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "frontier" if side == 0 else "bastion"
		player.spawn_index = side
		player.color = Color.from_hsv(side / 4.0, .7, .9)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_players = get_nodes_in_group("players")
	for player in _players:
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.set_process(false)
	_game.set_physics_process(false)
	_game.battlefield_events.set_physics_process(false)
	_game.commander_support.set_physics_process(false)
	await _frames(60)
	for frame in 600:
		if _game.navigation.terrain.is_synchronized():
			break
		await physics_frame
	await _frames(5)
	_game.simulation_time = 0
	_announcements.clear()
	_game.battlefield_events.announced.connect(func(text, _point): _announcements.append(text))


func _test_map(map_name):
	var manager = _game.battlefield_events
	_check(manager.occurrences.size() == 2, map_name + " missing fixed schedule")
	var nav = _game.navigation.terrain
	var own_distances = []
	for index in manager._sites.size():
		var point = manager._choose_point(index, 0)
		_check(point != null, "%s start %d has no legal candidate" % [map_name, index])
		if point == null:
			for choice in (
				[manager._sites[index].position] + Array(manager._sites[index].candidates)
			):
				print(
					"INVALID EVENT CANDIDATE ",
					map_name,
					" ",
					choice,
					" flags=",
					_game.map.terrain.flag_at(choice)
				)
			continue
		var from = nav.closest_point(_game.map.ground_point(_game.map.layout.bases[index].start))
		var path = NavigationServer3D.map_get_path(
			nav.navigation_map_rid, from, nav.closest_point(point), true
		)
		var distance = 0.0
		for step in range(1, path.size()):
			distance += path[step - 1].distance_to(path[step])
		own_distances.append(distance)
		print("EVENT ACCESS ", map_name, " ", index, " point=", point, " distance=", distance)
	if own_distances.size() == manager._sites.size():
		_check(
			own_distances.max() - own_distances.min() < 8.0, map_name + " asymmetric event access"
		)
	for event in manager.occurrences:
		var materials = 0
		var electronics = 0
		for cargo in event.cargos:
			materials += cargo.materials
			electronics += cargo.electronics
		_check(
			materials == (0 if event.kind == "alpine" else 100),
			map_name + " multiplied Materials budget"
		)
		_check(
			electronics == (0 if event.kind == "alpine" else 50),
			map_name + " multiplied Electronics budget"
		)
	_check(manager.minimap_markers(_players[0]).is_empty(), "Scheduled markers revealed early")


func _advance(time):
	_game.simulation_time = time
	_game.battlefield_events._physics_process(0.0)


func _test_lifecycle():
	var manager = _game.battlefield_events
	_check(await _round_trip({}), "Scheduled state failed round trip")
	paused = false
	manager = _game.battlefield_events
	_advance(254.9)
	_check(manager.occurrences[0].state == "scheduled", "Event announced early")
	_advance(255)
	_check(manager.occurrences[0].warning_delivered, "Warning not recorded")
	_check(manager.minimap_markers(_players[0]).size() == 2, "Warning markers missing")
	_check(
		manager.position_reserved(manager.occurrences[0].cargos[0].point, 1.0),
		"Announced position not reserved"
	)
	_check(await _round_trip({}), "Announced state failed round trip")
	paused = false
	manager = _game.battlefield_events
	_announcements.clear()
	manager.announced.connect(func(text, _point): _announcements.append(text))
	_advance(256)
	_check(_announcements.is_empty(), "Reload repeated warning")
	_advance(300)
	_check(manager.occurrences[0].state == "active", "First event did not activate")
	_check(_announcements.size() == 1, "Activation notice was not emitted once")
	var first = manager.occurrences[0].cargos[0]
	var second = manager.occurrences[0].cargos[1]
	_check(
		first.node.pickup_description().has("Supplies · 50 M / 25 E"),
		"Contested crate hover omits its actual resource windfall"
	)
	var worker = _spawn("Worker", 0, first.point + Vector3(0, 0, 1.0))
	var enemy = _spawn("Tank", 1, first.point + Vector3(1.0, 0, 0))
	worker.manual_orders.submit(
		load("res://source/match/orders/ManualOrders.gd").target_order(
			"collect_tactical", first.node
		),
		false,
		false
	)
	_check(
		await _round_trip({"worker": worker, "enemy": enemy, "cargo": first.node}),
		"Active state failed round trip"
	)
	manager = _game.battlefield_events
	worker = _restored.worker
	enemy = _restored.enemy
	first = manager.occurrences[0].cargos[0]
	second = manager.occurrences[0].cargos[1]
	_check(
		worker.action != null and worker.action._target_unit == first.node,
		"Collector target not restored"
	)
	_check(first.node == _restored.cargo, "Cargo stable reference not restored")
	_check(not manager.collect(first.node, worker, 0), "Paused collection changed state")
	paused = false
	var before = _players[0].resource_a
	var before_e = _players[0].resource_b
	var enemy_before = _players[1].resource_a
	# Reverse arrival order: the persisted unit serial wins simultaneous claims.
	_check(manager.collect(first.node, enemy, 0), "Combat unit cannot collect")
	_check(manager.collect(first.node, worker, 0), "Worker cannot collect")
	manager._resolve_claims()
	_check(first.claimant == worker.player, "Stable entity ordering did not resolve claim")
	_check(
		(
			_players[0].resource_a == before + first.materials
			and _players[0].resource_b == before_e + first.electronics
		),
		"Resource payout multiplied or omitted"
	)
	_check(_players[1].resource_a == enemy_before, "Simultaneous claim paid twice")
	var dead = _spawn("Infantry", 0, second.point + Vector3(0, 0, 1))
	_check(manager.collect(second.node, dead, 0), "Infantry collection request rejected")
	dead.hp = 0
	manager._resolve_claims()
	_check(second.status == "available", "Dead collector claimed reward")
	dead.queue_free()
	_check(await _round_trip({}), "Partial claim failed round trip")
	paused = false
	manager = _game.battlefield_events
	var after = _players[0].resource_a
	_advance(480)
	_check(manager.occurrences[0].state == "expired", "Unclaimed reward did not expire")
	_check(_players[0].resource_a == after, "Reload paid a reward again")
	_advance(615)
	_check(manager.occurrences[1].state == "announced", "Second warning missing")
	_advance(660)
	_check(manager.occurrences[1].state == "active", "Second event missing")
	_advance(841)
	_check(manager.occurrences[1].state == "expired", "Second event did not expire")
	_check(await _round_trip({}), "Expired state failed round trip")
	paused = false
	manager = _game.battlefield_events
	_game.settings.battlefield_events = false
	manager.initialize()
	_check(manager.occurrences.is_empty(), "Disabled events still scheduled")


func _test_blocked():
	var manager = _game.battlefield_events
	for site in manager._sites:
		for choice in [site.position] + Array(site.candidates):
			_spawn("Tank", 0, manager._ground_point(choice))
	_advance(300)
	_check(manager.occurrences[0].state == "expired", "Blocked delivery did not cancel")
	_check(
		manager.occurrences[0].cargos.all(func(cargo): return cargo.status == "cancelled"),
		"Blocked cargo survived cancellation"
	)
	_check(
		_announcements.has("Delivery cancelled: landing areas blocked"),
		"Cancellation was not public"
	)
	_check(manager.minimap_markers(_players[0]).is_empty(), "Cancelled cargo retained markers")


func _test_radar():
	var manager = _game.battlefield_events
	_advance(300)
	var cargo = manager.occurrences[0].cargos[0]
	_check(cargo.status == "available", "Alpine terminal unavailable")
	if cargo.status != "available":
		return
	var worker = _spawn("Worker", 0, cargo.point + Vector3(0, 0, 1))
	var enemy = _spawn("Tank", 1, _game.map.ground_point(Vector2(150, 110)))
	_game.settings.visibility = _game.settings.Visibility.PER_PLAYER
	var observed_before = _game.battlefield.is_observed(_players[0], enemy)
	var old_position = enemy.position
	_check(manager.collect(cargo.node, worker, 0), "Terminal collection rejected")
	manager._resolve_claims()
	_check(manager.occurrences[0].state == "claimed", "Linked terminals did not close")
	_check(
		not observed_before and not _game.battlefield.is_observed(_players[0], enemy),
		"Radar snapshot granted attack vision"
	)
	_check(
		manager.radar_blips(_players[0]).has(old_position), "Enemy position omitted from snapshot"
	)
	_check(manager.radar_blips(_players[1]).is_empty(), "Snapshot leaked to opponent")
	enemy.position += Vector3(8, 0, 0)
	_check(
		(
			manager.radar_blips(_players[0]).has(old_position)
			and not manager.radar_blips(_players[0]).has(enemy.position)
		),
		"Snapshot tracked moving enemies"
	)
	_check(await _round_trip({}), "Claimed radar state failed round trip")
	paused = false
	manager = _game.battlefield_events
	_check(manager.radar_blips(_players[0]).has(old_position), "Radar positions lost on reload")
	manager._physics_process(2.99)
	_check(not manager.radar_blips(_players[0]).is_empty(), "Radar expired early")
	manager._physics_process(.02)
	_check(manager.radar_blips(_players[0]).is_empty(), "Radar did not expire after three seconds")
	_check(manager.occurrences[0].state == "claimed", "Radar expiry reset terminal")


func _round_trip(objects) -> bool:
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = capture.capture(_game)
	if snapshot == null:
		_check(false, "Event capture failed: " + capture.error)
		return false
	var ids = {}
	for key in objects:
		ids[key] = capture._reference(objects[key])
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	if not loader.prepare(snapshot):
		_check(false, "Event schema rejected: " + loader.error)
		return false
	var before = snapshot.events.duplicate(true)
	var result = await loader.restore(self, snapshot)
	if not result.ok:
		_check(false, "Event restore failed: " + result.get("error", ""))
		return false
	_game = result.game
	_players = _game.get_node("Players").get_children().filter(
		func(player): return "faction" in player
	)
	for player in _players:
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.set_process(false)
	_game.set_physics_process(false)
	_game.battlefield_events.set_physics_process(false)
	_game.commander_support.set_physics_process(false)
	_restored.clear()
	for key in ids:
		_restored[key] = loader.entities.get(ids[key])
		_check(is_instance_valid(_restored[key]), "Missing event reference: " + key)
	var after = capture.get_script().new().capture(_game)
	_check(after != null and before == after.events, "Event lifecycle changed on reload")
	return true
