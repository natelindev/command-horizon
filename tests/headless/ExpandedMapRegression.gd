extends "res://tests/headless/ResourceMapEconomyRegression.gd"

const EXPANDED_MAPS = ["ExpandedDesertFrontier", "ExpandedAlpineRelay", "ExpandedCoastalFoundry"]


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	progress_path = "user://expanded-map-%d.json" % OS.get_process_id()
	root.get_node("SaveManager").autosaves_enabled = false
	await _menu()
	var maps = (
		["ExpandedCoastalFoundry"]
		if "--coastal-only" in OS.get_cmdline_user_args()
		else EXPANDED_MAPS
	)
	var geometry_only = "--geometry-only" in OS.get_cmdline_user_args()
	for faction in factions.IDS:
		for map_name in maps:
			await _create(map_name, faction)
			await _geometry(map_name)
			if not geometry_only:
				_check(await _fields() == true, "Expanded map economy aborted")
			await _close()
	if not geometry_only:
		for map_name in maps:
			await _egress(map_name)
	DirAccess.remove_absolute(progress_path)
	for message in _errors:
		push_error(message)
	print("Expanded maps: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _menu():
	var preferences = "user://expanded-map-menu-%d.cfg" % OS.get_process_id()
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	setup.preferences_path = preferences
	root.add_child(setup)
	_check("ExpandedDesertFrontier" in setup._get_selected_map_path(), "Fresh setup uses small map")
	_check(setup._map_paths.size() == 3, "Retired sparse maps remain in the new-game picker")
	for map_name in EXPANDED_MAPS:
		var path = "res://source/match/maps/%s.tscn" % map_name
		var index = setup._map_paths.find(path)
		_check(index >= 0, "Expanded map missing from setup: " + map_name)
		setup._map_list.select(index)
		setup._on_map_list_item_selected(index)
		_check(setup._preview.deposits.size() == 8, "Expanded preview omits resource fields")
		_check(setup._preview.points_of_interest.size() == 6, "Expanded preview omits facilities")
		setup._save_preferences()
		var config = ConfigFile.new()
		config.load(preferences)
		_check(config.get_value("setup", "map") == path, "Map preference lacks stable path")
		setup._map_list.select(0)
		setup._load_preferences()
		_check(setup._get_selected_map_path() == path, "Map preference restore changed selection")
	var legacy = ConfigFile.new()
	legacy.set_value("setup", "map", 5)
	legacy.save(preferences)
	setup._load_preferences()
	_check(
		"/ExpandedCoastalFoundry.tscn" in setup._get_selected_map_path(),
		"Legacy coastal preference did not select its replacement"
	)
	for old_name in setup.LEGACY_MAP_NAMES:
		legacy.set_value("setup", "map", "res://source/match/maps/%s.tscn" % old_name)
		legacy.save(preferences)
		setup._load_preferences()
		var expected = old_name if old_name in EXPANDED_MAPS else "Expanded" + old_name
		if expected not in EXPANDED_MAPS:
			expected = "ExpandedDesertFrontier"
		_check(expected in setup._get_selected_map_path(), "Legacy map routing failed: " + old_name)
	setup.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(preferences)


func _create(map_name, faction, mission = ""):
	await super._create(map_name, faction, mission)
	# Isolate authored routes from frozen opening infantry/engineers at HQ doors.
	# The separate paid-production case retains the live starting army.
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(30)


func _geometry(map_name):
	var map = game.map
	var overview = map.overview()
	var ambient = load("res://source/match/ambient/AmbientCatalog.gd")
	_check(not ambient.entries(game.settings.map_path).is_empty(), "Expanded map lost ambient life")
	var audio = load("res://source/match/audio/EnvironmentAudio.gd")
	var expected_region = (
		"desert" if "Desert" in map_name else ("alpine" if "Alpine" in map_name else "coastal")
	)
	_check(
		audio.region_for(game.settings.map_path) == expected_region,
		"Expanded map lost existing biome audio"
	)
	var world = map.get_node("LivingWorld")
	_check(world._alpine == ("Alpine" in map_name), "Expanded map lost alpine biome")
	_check(world._coastal == ("Coastal" in map_name), "Expanded map lost coastal biome")
	if "Coastal" in map_name:
		_check(
			game.get_node("NeutralWorld").buildings.size() == 7,
			"Expanded coastal map lost destructible landmarks"
		)
	_check(map.size.x >= 192 and map.size.y >= 144, "Expanded map is too small")
	_check(overview.fields.size() == 8, "Expanded field count is not eight")
	_check(map.points_of_interest.size() == 6, "Expanded facilities were not populated")
	var nav = game.navigation.terrain.navigation_map_rid
	var starts = map.get_node("SpawnPoints").get_children()
	_check_starting_fields(map, nav, starts, overview)
	var from = starts[0].position + Vector3(0, 0, 12)
	var to = (
		starts[1].position + Vector3(0, 0, -12 if starts[1].position.z > map.size.y / 2 else 12)
	)
	var route = NavigationServer3D.map_get_path(nav, from, to, true)
	_check(not route.is_empty(), "No ground route between bases: " + map_name)
	if not route.is_empty():
		_check((route[-1] * Vector3(1, 0, 1)).distance_to(to) < 1.5, "Cross-map route ends early")
	for site in load("res://source/match/world/PointOfInterestCatalog.gd").definitions(
		game.settings.map_path
	):
		var point = Vector3(site.position.x, 0, site.position.y)
		for resource in map.get_node("Resources").get_children():
			_check(point.distance_to(resource.position) >= 14, "Facility crowds resource deposit")
		for index in overview.ridges.size():
			_check(
				site.position.distance_to(overview.ridges[index]) >= overview.radius + 14,
				"Facility crowds major terrain footprint"
			)
		for building in overview.get("buildings", []):
			var nearest = site.position.clamp(building.position, building.end)
			_check(site.position.distance_to(nearest) >= 14, "Facility crowds solid landmark")
		for offset in [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6)]:
			var approach = point + offset
			var closest = NavigationServer3D.map_get_closest_point(nav, approach)
			_check(
				(closest * Vector3(1, 0, 1)).distance_to(approach) < 1.5,
				"Facility has obstructed capture/service ring"
			)
	var resources = get_nodes_in_group("resource_units")
	for resource in resources:
		var point = Vector2(resource.position.x, resource.position.z)
		var opposite = (
			Vector2(map.size.x - point.x, point.y) if "Coastal" in map_name else map.size - point
		)
		var kind = "resource_a" if "resource_a" in resource else "resource_b"
		var paired = false
		for other in resources:
			var other_point = Vector2(other.position.x, other.position.z)
			if kind in other and other_point.distance_to(opposite) < .05:
				paired = resource.get(kind) == other.get(kind)
		_check(paired, "Expanded map resource positions/stocks favor one starting side")
	for field in overview.fields:
		var centered = false
		for unit in resources:
			var position_2d = Vector2(unit.position.x, unit.position.z)
			if "resource_a" in unit and position_2d.distance_to(field) < .05:
				centered = true
		_check(centered, "Authored expanded field was displaced during navigation initialization")

	if "Coastal" in map_name:
		var water = Vector3(96, 0, 45)
		var nearest = NavigationServer3D.map_get_closest_point(nav, water)
		_check(nearest.distance_to(water) > 10, "Expanded harbor water admits ground units")
		for index in range(1, route.size()):
			for step in 20:
				_check(
					map.is_land(route[index - 1].lerp(route[index], step / 20.0)),
					"Expanded harbor ground route crosses water"
				)
	print(
		"EXPANDED GEOMETRY ",
		map_name,
		" size=",
		map.size,
		" fields=",
		overview.fields.size(),
		" facilities=",
		map.points_of_interest.size(),
		" route_points=",
		route.size()
	)


func _check_starting_fields(map, nav, starts, overview):
	var deposits = map.get_node("Resources").get_children()
	# The seven individual distances, not just the field center, match both
	# players on all maps. Stocks and expansion layouts are unaffected.
	var expected = [
		sqrt(336.25), 18.0, sqrt(336.25), sqrt(213.3125), sqrt(213.3125), sqrt(298.25), sqrt(422.5)
	]
	for side in 2:
		var start: Vector3 = starts[side].position
		var origin = Vector2(start.x, start.z)
		_check(
			absf(overview.fields[side].distance_to(origin) - 18.0) < .001,
			"Starting field distance differs"
		)
		var forward: Vector2 = (overview.fields[side] - origin).normalized()
		var doorstep = start + Vector3(forward.x, 0, forward.y) * 5.0
		for slot in 7:
			var deposit = deposits[side * 7 + slot]
			var point: Vector3 = deposit.position * Vector3(1, 0, 1)
			_check(
				absf(point.distance_to(start) - expected[slot]) < .05,
				(
					"Starting pile moved or has inconsistent distance: %s side %d slot %d"
					% [map.scene_file_path, side, slot]
				)
			)
			_check(
				(
					deposit.get("resource_a" if slot < 5 else "resource_b")
					== (400 if slot < 5 else 720)
				),
				"Starting resource stock changed"
			)
			var route = NavigationServer3D.map_get_path(nav, doorstep, point, true)
			# Resource footprints are excluded from the shared largest-agent mesh.
			# The reachable endpoint must be inside the actual gathering range.
			var work_range = (
				deposit.radius
				+ constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
				+ constants.Match.Terrain.Navmesh.CELL_SIZE
			)
			_check(
				(
					not route.is_empty()
					and (route[-1] * Vector3(1, 0, 1)).distance_to(point) <= work_range
				),
				(
					"Starting pile has no harvest approach: %s side %d slot %d endpoint %s target %s"
					% [
						map.scene_file_path,
						side,
						slot,
						route[-1] if not route.is_empty() else Vector3.INF,
						point
					]
				)
			)


func _egress(map_name):
	var settings = _settings("bastion", "helix", true)
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	game = await _start(settings)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.issue_manual_order(null)
		if unit.attack_range != null:
			unit.sight_range = 0
	await _frames(120)
	for player in get_nodes_in_group("players"):
		var factories = player.get_children().filter(
			func(unit): return "type" in unit and unit.type == "VehicleFactory"
		)
		var factory = factories[0]
		var old_tanks = player.get_children().filter(
			func(unit): return "type" in unit and unit.type == "Tank"
		)
		_check(
			factory.production_queue.produce(load(Catalog.scene_path("Tank"))) != null,
			"Expanded base cannot start paid tank production"
		)
		await _frames(1500)
		var produced = player.get_children().filter(
			func(unit): return "type" in unit and unit.type == "Tank" and not unit in old_tanks
		)
		_check(produced.size() == 1, "Expanded base factory exit blocks paid tank")
		if produced.size() != 1:
			continue
		var tank = produced[0]
		var destination = factory.position + Vector3(0, 0, 18)
		tank.sight_range = 0
		tank.issue_manual_order(load("res://source/match/units/actions/Moving.gd").new(destination))
		await _frames(1200)
		_check(
			(tank.position * Vector3(1, 0, 1)).distance_to(destination) < 2,
			"Produced tank cannot leave expanded base"
		)
	game.queue_free()
	await _frames(5)
