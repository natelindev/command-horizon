extends "res://tests/headless/Skirmish.gd"

const Battlefields = preload("res://source/match/maps/BattlefieldCatalog.gd")
const Snapshot = preload("res://source/match/saves/MatchSnapshot.gd")
const Schema = preload("res://source/match/saves/SnapshotSchema.gd")
const Restore = preload("res://source/match/saves/MatchRestore.gd")
var game
var settings_by_map = {}


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _menu_roster()
	for map_name in Battlefields.MAPS:
		game = await _start(settings_by_map[map_name])
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		await _frames(30)
		await _geometry(map_name)
		var snapshot = _snapshot()
		var schema = Schema.new()
		_check(snapshot != null and schema.validate(snapshot), map_name + " save: " + schema.error)
		print(
			"BATTLEFIELD ",
			map_name,
			" players=",
			game.settings.players.size(),
			" fields=",
			game.map.overview().fields.size(),
			" sites=",
			game.map.points_of_interest.size()
		)
		game.queue_free()
		await _frames(5)
	await _four_player_lifecycle()
	await _outcome_edges()
	for message in _errors:
		push_error(message)
	print("Battlefield expansion: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _menu_roster():
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = "user://battlefield-expansion-%d.cfg" % OS.get_process_id()
	root.add_child(setup)
	var counts = {2: 0, 4: 0}
	for map_name in Battlefields.MAPS:
		var data = Battlefields.MAPS[map_name]
		counts[data.players] += 1
		var path = "res://source/match/maps/%s.tscn" % map_name
		var index = setup._map_paths.find(path)
		_check(index >= 0, "Map missing from picker: " + map_name)
		setup._map_list.select(index)
		setup._on_map_list_item_selected(index)
		setup._player_faction.select(counts[data.players] % 3)
		setup._enemy_faction.select(factions.IDS.size())
		var settings = setup._create_match_settings()
		settings_by_map[map_name] = settings
		_check(settings.players.size() == data.players, "Wrong player count: " + map_name)
		_check(setup._preview.starts.size() == data.players, "Preview hides starts: " + map_name)
		_check(setup._preview.deposits.size() == data.fields.size(), "Preview hides fields")
		_check(setup._preview.points_of_interest.size() == data.sites.size(), "Preview hides sites")
		_check(setup._preview.water.size() == data.water.size(), "Preview hides water")
		for side in settings.players:
			_check(
				side.spawn_index_offset == 0 and side.faction in factions.IDS,
				"Invalid start or faction"
			)
		setup._save_preferences()
		setup._map_list.select(0)
		setup._load_preferences()
		_check(setup._get_selected_map_path() == path, "Map preference did not round-trip")
	_check(counts[2] >= 5 and counts[4] >= 8, "Insufficient new maps")
	DirAccess.remove_absolute(setup.preferences_path)
	setup.queue_free()
	await _frames(3)


func _geometry(map_name):
	var data = Battlefields.MAPS[map_name]
	var map = game.map
	var nav = game.navigation.terrain.navigation_map_rid
	var starts = map.get_node("SpawnPoints").get_children()
	var resources = map.get_node("Resources").get_children()
	_check(starts.size() == data.players, map_name + " missing starts")
	_check(get_nodes_in_group("players").size() == data.players, map_name + " missing armies")
	_check(resources.size() == data.fields.size() * 7, map_name + " missing resources")
	_check(map.points_of_interest.size() == data.players * 3, map_name + " missing facilities")
	_check(
		map.size == Vector2(constants.Match.MAPS[game.settings.map_path].size),
		"Map metadata bounds differ"
	)
	# Remove mobile starting units so routes measure authored geometry, not a
	# stationary engineer standing on a capture approach. HQs remain in place.
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(30)
	for side in data.players:
		var start: Vector3 = starts[side].position
		var field: Vector2 = data.fields[side]
		_check(
			absf(Vector2(start.x, start.z).distance_to(field) - 18.0) < .001,
			"Unbalanced opening distance"
		)
		var origin = start + Vector3(0, 0, 11 if start.z < map.size.y / 2 else -11)
		for other in data.players:
			if other == side:
				continue
			var target: Vector3 = starts[other].position
			target.z += 11 if target.z < map.size.y / 2 else -11
			_check(
				_reachable(nav, origin, target, 1.5),
				map_name + " isolated start %d -> %d" % [side, other]
			)
		for slot in 7:
			var deposit = resources[side * 7 + slot]
			var kind = "resource_a" if slot < 5 else "resource_b"
			_check(deposit.get(kind) == (400 if slot < 5 else 720), "Unbalanced opening stock")
			_check(
				_reachable(nav, origin, deposit.position, 2.0),
				map_name + " inaccessible opening deposit"
			)
	# Every field retains its authored center after navigation initialization,
	# and the whole resource population has a rotated, equally stocked partner.
	for index in data.fields.size():
		var center: Vector3 = resources[index * 7 + 1].position
		_check(
			Vector2(center.x, center.z).distance_to(data.fields[index]) < .05,
			map_name + " displaced field"
		)
		_check(
			_reachable(nav, starts[0].position + Vector3(0, 0, 11), center, 2),
			map_name + " unreachable expansion"
		)
	for deposit in resources:
		var point = Vector2(deposit.position.x, deposit.position.z)
		var opposite = map.size / 2 + (point - map.size / 2).rotated(TAU / data.players)
		var kind = "resource_a" if "resource_a" in deposit else "resource_b"
		var paired = false
		for other in resources:
			var other_point = Vector2(other.position.x, other.position.z)
			if (
				kind in other
				and other.get(kind) == deposit.get(kind)
				and other_point.distance_to(opposite) < .05
			):
				paired = true
		_check(paired, map_name + " asymmetric resource")

	for site in data.sites:
		var point = Vector3(site.position.x, 0, site.position.y)
		for offset in [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6)]:
			_check(
				_reachable(nav, starts[0].position + Vector3(0, 0, 11), point + offset, 1.5),
				map_name + " obstructed facility approach"
			)
	for body in map.interior_obstacles:
		var top = load("res://source/match/maps/Vegetation.gd").bounds(body).end.y
		_check(
			map.flight_height_at(body.position, 1.5) >= top + .8,
			map_name + " aircraft route clips a landmark"
		)
	for pool in data.water:
		var point = Vector3(pool.x, 0, pool.y)
		_check(
			(
				NavigationServer3D.map_get_closest_point(nav, point).distance_to(point)
				>= data.water_radius - 1
			),
			map_name + " navigable water"
		)


func _reachable(nav, origin, target, tolerance):
	var route = NavigationServer3D.map_get_path(nav, origin, target, true)
	return (
		not route.is_empty()
		and (route[-1] * Vector3(1, 0, 1)).distance_to(target * Vector3(1, 0, 1)) <= tolerance
	)


func _four_player_lifecycle():
	var settings = settings_by_map.CinderRing.duplicate(true)
	settings.advanced_start = true
	game = await _start(settings)
	var players = get_nodes_in_group("players")
	for player in players:
		player.set_process(false)
	# Keep nonempty AI group state on every side; restore must not drop AI 2/3.
	for index in range(1, 4):
		var unit = _unit(players[index], "Tank")
		players[index]._army_groups = [
			{
				"kind": "assault",
				"point": Vector3(112, 0, 112),
				"members": [unit],
				"started": game.simulation_time,
				"retiring": false,
				"workers": []
			}
		]
		var destination = (
			load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
			. _enemy_start(game, players[index])
		)
		_check(
			destination != game.map.get_node("SpawnPoints").get_child(index).position,
			"AI targets itself"
		)
	game.map.points_of_interest[0].captured_by = players[3]
	game.map.points_of_interest[0]._update_presentation()
	var snapshot = _snapshot()
	var schema = Schema.new()
	_check(schema.validate(snapshot), "Four-player snapshot: " + schema.error)
	var malformed = snapshot.duplicate(true)
	malformed.players[3].ai.groups[0].members = (
		malformed.players[2].ai.groups[0].members.duplicate()
	)
	_check(not Schema.new().validate(malformed), "Cross-owner fourth-player AI group accepted")
	var restored = await Restore.new().restore(self, snapshot)
	_check(restored.ok, "Four-player restore failed: " + str(restored.get("error", "")))
	if not restored.ok:
		game.queue_free()
		await _frames(5)
		return
	game = current_scene
	players = get_nodes_in_group("players")
	_check(players.size() == 4, "Restore omitted commanders")
	for index in range(1, 4):
		players[index].set_process(false)
		_check(players[index]._army_groups.size() == 1, "Restore omitted AI army state")
	_check(
		game.map.points_of_interest[0].captured_by == players[3],
		"Fourth-player facility ownership lost"
	)
	# First and second eliminations must leave the game running.
	for index in [3, 2]:
		_unit(players[index], "CommandCenter").queue_free()
		await _frames(2)
		game._check_outcome(61)
		await _frames(2)
		_check(not game.finished, "Premature victory after one rival was eliminated")
		_check(game._defeat_timers[players[index]] == 0, "Elimination not persistent")
		_check(players[index].population() == 0, "Eliminated army remains active")
	var eliminated_save = _snapshot()
	_check(Schema.new().validate(eliminated_save), "Eliminated-player save rejected")
	restored = await Restore.new().restore(self, eliminated_save)
	_check(restored.ok, "Elimination restore failed")
	game = current_scene
	players = get_nodes_in_group("players")
	game._check_outcome(.1)
	_check(
		not game.finished and game._defeat_timers[players[3]] == 0,
		"Restored elimination ended match"
	)
	_unit(players[1], "CommandCenter").queue_free()
	await _frames(2)
	game._check_outcome(61)
	_check(game.finished and game.result == "Victory", "Last rival did not trigger victory")
	game.queue_free()
	paused = false
	await _frames(5)


func _snapshot():
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	_check(data != null, "Snapshot capture failed: " + builder.error)
	paused = false
	return data


func _outcome_edges():
	for expected in ["Defeat", "Draw", "Victory"]:
		game = await _start(settings_by_map.CinderRing)
		var players = get_nodes_in_group("players")
		for index in players.size():
			players[index].set_process(false)
			if (
				expected == "Draw"
				or (expected == "Defeat" and index == 0)
				or (expected == "Victory" and index > 0)
			):
				_unit(players[index], "CommandCenter").queue_free()
		await _frames(2)
		game._check_outcome(61)
		_check(
			game.finished and game.result == expected, "Incorrect four-player outcome: " + expected
		)
		game.queue_free()
		paused = false
		await _frames(5)
