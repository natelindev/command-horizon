extends "res://tests/headless/MapResourceBalanceRegression.gd"

# Points of interest on every skirmish map: capturable facilities, salvage
# caches, story landmarks and ground cover. Checks that each map is populated,
# that opposed starts meet the same sites at the same ground distance, and that
# landmarks keep bases, deposits, facilities, civilian routes and paths open.
# Pass --report-only to print the tables without failing.

# Building room kept clear around every HQ, beyond the landmark footprint.
const BASE_CLEARANCE = 14.0
# Open ground kept between a landmark and a deposit or a facility capture ring.
const DEPOSIT_GAP = 2.5
const SITE_GAP = 1.5
const SITE_TOLERANCE = {"relative": .08, "absolute": 3.0}
# Contested sites (facilities, relays, caches) and landmark bodies per map;
# two-player maps default to two sites and four landmarks. The compact original
# desert and Open Plains keep their open floors; Great Expanse dresses only the
# flanks between the starts that meet in a skirmish.
const MINIMUMS = {
	"BastionDesert": {"sites": 4, "landmarks": 2},
	"PlainAndSimple": {"sites": 2, "landmarks": 0},
	"BigArena": {"sites": 4, "landmarks": 4},
}

var landmarks
var sites_catalog


func _run():
	constants = root.get_node("Constants")
	landmarks = load("res://source/match/world/MapLandmarks.gd")
	sites_catalog = load("res://source/match/world/PointOfInterestCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	report_only = "--report-only" in OS.get_cmdline_user_args()
	var only = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	for map_path in constants.Match.MAPS:
		if not only.is_empty() and map_path.get_file().get_basename() not in only:
			continue
		await _create(map_path)
		_inspect(map_path)
		game.queue_free()
		await _frames(5)
		await _archive_skirmish(map_path)
	for message in _errors:
		if report_only:
			print("POI ISSUE ", message)
		else:
			push_error(message)
	print("Map points of interest: %d failures" % _errors.size())
	quit(0 if report_only or _errors.is_empty() else 1)


func _inspect(map_path):
	var map_name = map_path.get_file().get_basename()
	var map = game.map
	var count = constants.Match.MAPS[map_path].players
	var nav = game.navigation.terrain.navigation_map_rid
	var headquarters = get_nodes_in_group("units").filter(
		func(unit): return unit.type == "CommandCenter"
	)
	var starts = []
	var rings = []
	for marker in map.get_node("SpawnPoints").get_children():
		headquarters.sort_custom(
			func(a, b):
				return (
					a.global_position.distance_to(marker.global_position)
					< b.global_position.distance_to(marker.global_position)
				)
		)
		starts.append(headquarters[0].global_position * Vector3(1, 0, 1))
		rings.append(_ring(starts[-1], headquarters[0].radius, HQ_SIDES))
	var sites = sites_catalog.sites(game)
	var dressing = map.get_node_or_null("WorldDressing")
	var bodies = (
		dressing.get_children().filter(func(node): return node.has_meta("landmark"))
		if dressing != null
		else []
	)
	var covers = (
		dressing.get_children().filter(func(node): return node is MultiMeshInstance3D)
		if dressing != null
		else []
	)
	var caches = get_nodes_in_group("resource_units").filter(
		func(deposit): return deposit.has_meta("salvage_cache")
	)
	var anchors = []
	for deposit in caches:
		if deposit.get_meta("salvage_cache") not in anchors:
			anchors.append(deposit.get_meta("salvage_cache"))
	var relays = map.relays if "relays" in map else []
	var buildings = game.get_node("NeutralWorld").buildings
	var cover = 0
	for instance in covers:
		cover += instance.multimesh.instance_count
	print(
		(
			"POI %s facilities=%d relays=%d garrisons=%d caches=%d landmarks=%d cover=%d"
			% [
				map_name,
				sites.size(),
				relays.size(),
				buildings.size(),
				anchors.size(),
				bodies.size(),
				cover
			]
		)
	)
	_check(
		sites.size() == sites_catalog.definitions(map_path).size(), map_name + " facilities missing"
	)
	var minimum = MINIMUMS.get(map_name, {"sites": 2, "landmarks": 4})
	_check(
		sites.size() + relays.size() + anchors.size() >= minimum.sites,
		map_name + " lacks contested sites to capture or salvage"
	)
	_check(bodies.size() >= minimum.landmarks, map_name + " lacks story landmarks")
	_check(cover >= 20 and covers.size() <= 8, map_name + " ground cover is missing or unbatched")
	_symmetric(map_name, map_path)
	_clearances(map_name, map, starts, bodies, sites)
	# Every site and cache is reachable, and opposed starts meet them alike.
	var targets = []
	for site in sites:
		targets.append({"label": site.kind, "point": site.global_position, "radius": site.radius})
	for anchor in anchors:
		targets.append({"label": "cache", "point": Vector3(anchor.x, 0, anchor.y), "radius": 2.0})
	for relay in relays:
		targets.append({"label": "relay", "point": relay.global_position, "radius": .85})
	var distances = []
	for ring in rings:
		var row = []
		for target in targets:
			row.append(_trip(ring, _ring(target.point, target.radius, DEPOSIT_SIDES)))
		distances.append(row)
	for index in starts.size():
		for target_index in targets.size():
			_check(
				distances[index][target_index] < INF,
				(
					"%s start %d cannot reach %s at %s"
					% [map_name, index, targets[target_index].label, targets[target_index].point]
				)
			)
	for index in range(count / 2):
		_compare_sites(map_name, targets, distances, index, index + count / 2)


func _compare_sites(map_name, targets, distances, first, second):
	# Sort each start's sites by kind, then distance, and compare in order.
	var lists = []
	for start in [first, second]:
		var entries = []
		for index in targets.size():
			entries.append({"label": targets[index].label, "distance": distances[start][index]})
		entries.sort_custom(
			func(a, b): return a.label < b.label or (a.label == b.label and a.distance < b.distance)
		)
		lists.append(entries)
	var worst = 0.0
	for index in lists[0].size():
		var a = lists[0][index]
		var b = lists[1][index]
		var allowed = maxf(
			SITE_TOLERANCE.absolute, SITE_TOLERANCE.relative * maxf(a.distance, b.distance)
		)
		worst = maxf(worst, absf(a.distance - b.distance))
		_check(
			a.label == b.label and absf(a.distance - b.distance) <= allowed,
			(
				"%s starts %d/%d %s at %.1f vs %s at %.1f (allowed %.1f)"
				% [map_name, first, second, a.label, a.distance, b.label, b.distance, allowed]
			)
		)
	print("  SITES %s starts %d/%d worst spread %.1f m" % [map_name, first, second, worst])


func _symmetric(map_name, map_path):
	if not landmarks.LAYOUTS.has(landmarks.layout_name(map_path)):
		_check(false, map_name + " has no landmark layout")
		return
	var scale = landmarks.layout_scale(game.map)
	var placed = landmarks.placements(map_path, scale)
	var items = placed.landmarks + placed.caches
	for item in items:
		for image in landmarks.images(map_path, item.position, scale):
			_check(
				items.any(func(other): return _twin(other, item, image)),
				(
					"%s %s at %s lacks its mirror"
					% [map_name, item.get("asset", "cache"), item.position]
				)
			)
	# Facilities pair with the same kind at the opposed start's image.
	var definitions = sites_catalog.definitions(map_path)
	for site in definitions:
		var image = landmarks.images(map_path, site.position, scale)[-1]
		_check(
			definitions.any(func(other): return _twin(other, site, image)),
			"%s %s at %s lacks its opposed twin" % [map_name, site.kind, site.position]
		)


func _twin(candidate, item, image):
	return (
		candidate.get("asset") == item.get("asset")
		and candidate.get("kind") == item.get("kind")
		and candidate.position.distance_to(image) < .05
	)


func _clearances(map_name, map, starts, bodies, sites):
	var deposits = get_nodes_in_group("resource_units")
	var overview = map.overview() if map.has_method("overview") else {}
	for body in bodies:
		var point = body.global_position * Vector3(1, 0, 1)
		var radius = body.get_node("MovementObstacle").radius
		var label = "%s landmark %s at (%.1f, %.1f)" % [map_name, body.name, point.x, point.z]
		for start in starts:
			_check(
				point.distance_to(start) >= BASE_CLEARANCE + radius,
				label + " crowds a start base (%.1f m)" % point.distance_to(start)
			)
		for deposit in deposits:
			var gap = point.distance_to(deposit.global_position * Vector3(1, 0, 1))
			_check(
				gap >= radius + deposit.radius + DEPOSIT_GAP,
				label + " blocks a deposit approach (%.1f m)" % gap
			)
		for site in sites:
			var gap = point.distance_to(site.global_position * Vector3(1, 0, 1))
			_check(
				gap >= radius + site.CAPTURE_RADIUS + SITE_GAP,
				label + " crowds a facility (%.1f m)" % gap
			)
		for road in overview.get("roads", []):
			var closest = Geometry2D.get_closest_point_to_segment(
				Vector2(point.x, point.z), Vector2(road.x, road.y), Vector2(road.z, road.w)
			)
			# Story props may stand on a shoulder but never across a whole road.
			_check(
				closest.distance_to(Vector2(point.x, point.z)) >= radius * .5,
				label + " sits across a road"
			)
		# Like every authored landmark, a solid story prop is ground cover.
		_check(
			not game.battlefield.line_clear(
				point + Vector3(-radius - 2, .7, 0), point + Vector3(radius + 2, .7, 0)
			),
			label + " does not block ground sight"
		)
		if map.has_method("is_land"):
			for index in 8:
				var edge = point + Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8) * radius
				_check(map.is_land(edge), label + " stands in the harbor")
	# Civilian traffic and residents keep walking clear of every new site.
	var ambient = load("res://source/match/ambient/AmbientCatalog.gd")
	var footprints = []
	for body in bodies:
		footprints.append(
			[body.name, body.global_position, body.get_node("MovementObstacle").radius]
		)
	for site in sites:
		footprints.append([site.label_title, site.global_position, site.radius])
	for deposit in deposits.filter(func(node): return node.has_meta("salvage_cache")):
		footprints.append(["cache", deposit.global_position, deposit.radius])
	for entry in ambient.entries(game.settings.map_path):
		for distance in range(ceili(entry.length)):
			var point = ambient.point(entry, float(distance)) * Vector3(1, 0, 1)
			for footprint in footprints:
				var gap = point.distance_to(footprint[1] * Vector3(1, 0, 1))
				_check(
					gap > footprint[2] + .5,
					"%s %s blocks ambient route %s" % [map_name, footprint[0], entry.id]
				)
	# Facility capture rings stay open ground.
	var nav = game.navigation.terrain.navigation_map_rid
	for site in sites:
		for index in 8:
			var approach = (
				site.global_position
				+ Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8) * (site.CAPTURE_RADIUS + 1)
			)
			var closest = NavigationServer3D.map_get_closest_point(nav, approach)
			_check(
				(closest * Vector3(1, 0, 1)).distance_to(approach * Vector3(1, 0, 1)) < 1.0,
				"%s facility %s has an obstructed capture ring" % [map_name, site.label_title]
			)


# Saves of a regular two-player skirmish keep every facility, and saves from
# before a map gained facilities still load.
func _archive_skirmish(map_path):
	var map_name = map_path.get_file().get_basename()
	var settings = _settings("bastion", "helix", false)
	settings.map_path = map_path
	settings.players[1].spawn_index_offset = constants.Match.MAPS[map_path].players / 2 - 1
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	for player in get_nodes_in_group("players"):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, map_name + " snapshot failed: " + capture.error)
	if data != null:
		var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
		_check(schema.validate(data.duplicate(true)), map_name + " save rejected: " + schema.error)
		var sites = data.mission.get("points_of_interest", [])
		if not sites.is_empty():
			var partial = data.duplicate(true)
			partial.mission.points_of_interest = sites.slice(0, sites.size() - 1)
			_check(not schema.validate(partial), map_name + " save missing a facility accepted")
	paused = false
	game.queue_free()
	await _frames(5)
