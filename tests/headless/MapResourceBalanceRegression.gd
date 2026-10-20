extends "res://tests/headless/Skirmish.gd"

# Every skirmish start must reach an equivalent economy. Distances are ground
# navigation path lengths between the nearest open sides of a start HQ and of
# each deposit, the trip a worker repeats, so cliffs, shorelines and landmarks
# count. Fields are compared rank by rank: the main and natural of every start,
# and for each opposed pair of starts every field including contested ones and
# their distance from the opponent HQ (exposure).
# Pass --report-only to print the balance tables without failing, and map file
# names (for example BigArena) to measure only those maps.

# Legacy maps have no authored field identity; group nearby deposits there.
const FIELD_LINK = 5.0
# A field belongs to a start only when no other start is within this margin of it.
const OWNERSHIP_MARGIN = .1
# Paths that end farther than this from their target do not reach it.
const REACH = 1.0
# Workers leave and reach a footprint from the nearest open side of this ring.
const APPROACH = 1.0
const HQ_SIDES = 8
const DEPOSIT_SIDES = 12
# Allowed spread between equivalent fields: main/natural, then outer fields,
# whose long routes cross navigation polygons that are never perfectly mirrored.
const NEAR_TOLERANCE = {"relative": .05, "absolute": 1.5}
const FAR_TOLERANCE = {"relative": .10, "absolute": 3.0}

var game
var report_only = false


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	report_only = "--report-only" in OS.get_cmdline_user_args()
	var only = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	for map_path in constants.Match.MAPS:
		if not only.is_empty() and map_path.get_file().get_basename() not in only:
			continue
		await _create(map_path)
		_measure(map_path)
		game.queue_free()
		await _frames(5)
	for message in _errors:
		if report_only:
			print("IMBALANCE ", message)
		else:
			push_error(message)
	print("Map resource balance: %d failures" % _errors.size())
	quit(0 if report_only or _errors.is_empty() else 1)


func _create(map_path):
	# Occupy every start so each one has the same HQ footprint in the ground mesh.
	var settings = _settings("bastion", "helix", false)
	settings.map_path = map_path
	for index in range(2, constants.Match.MAPS[map_path].players):
		var player = settings.players[1].duplicate()
		player.color = Color.from_hsv(index / 8.0, .7, .9)
		settings.players.append(player)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.get_node("IsometricCamera3D").set_physics_process(false)
	for player in get_nodes_in_group("players"):
		player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(60)
	var terrain = game.navigation.terrain
	for frame in 600:
		if terrain.is_synchronized():
			break
		await physics_frame
	await _frames(10)


func _path_length(from, to):
	var nav = game.navigation.terrain.navigation_map_rid
	var path = NavigationServer3D.map_get_path(nav, from, to, true)
	if path.is_empty():
		return INF
	var end = Vector2(path[-1].x, path[-1].z)
	var target = Vector2(to.x, to.z)
	if end.distance_to(target) > REACH:
		return INF
	var length = end.distance_to(target)
	for index in range(1, path.size()):
		length += (path[index - 1] * Vector3(1, 0, 1)).distance_to(path[index] * Vector3(1, 0, 1))
	return length


# Open ground points around a footprint, with the distance back to its center.
func _ring(center, radius, sides):
	var nav = game.navigation.terrain.navigation_map_rid
	var reach = radius + APPROACH
	var result = []
	for index in sides:
		var angle = index * TAU / sides
		var side = Vector3(center.x, 0, center.z) + Vector3(cos(angle), 0, sin(angle)) * reach
		side = game.map.ground_point(Vector2(side.x, side.z))
		var closest = NavigationServer3D.map_get_closest_point(nav, side)
		if Vector2(closest.x, closest.z).distance_to(Vector2(side.x, side.z)) <= .6:
			result.append(side)
	return {"points": result, "reach": reach}


func _trip(start_ring, deposit_ring):
	var best = INF
	for from in start_ring.points:
		for to in deposit_ring.points:
			best = minf(best, _path_length(from, to))
	return best + start_ring.reach + deposit_ring.reach


func _fields(deposits):
	if "layout" in game.map:
		# Authored piles follow wide arcs and can span several terrain heights.
		# Their shared harvest origin is the field identity, not pile proximity.
		var grouped = {}
		for deposit in deposits:
			if not grouped.has(deposit.harvest_origin):
				grouped[deposit.harvest_origin] = []
			grouped[deposit.harvest_origin].append(deposit)
		return grouped.values()
	var fields = []
	var assigned = {}
	for deposit in deposits:
		if assigned.has(deposit):
			continue
		var field = [deposit]
		assigned[deposit] = true
		var cursor = 0
		while cursor < field.size():
			for other in deposits:
				if (
					not assigned.has(other)
					and other.position.distance_to(field[cursor].position) < FIELD_LINK
				):
					assigned[other] = true
					field.append(other)
			cursor += 1
		fields.append(field)
	return fields


func _authored_owner(field):
	var origin = Vector2(field[0].harvest_origin.x, field[0].harvest_origin.z)
	for entry in game.map.layout.bases + game.map.layout.expansions:
		if entry.field.is_equal_approx(origin):
			return entry.get("player", -1)
	_check(false, "Authored resource field at %s has no layout entry" % origin)
	return -1


func _field_metrics(field, trips):
	var result = {
		"materials": 0,
		"electronics": 0,
		"material_count": 0,
		"electronics_count": 0,
		"nearest_materials": INF,
		"nearest_electronics": INF
	}
	var total = 0.0
	var center = Vector3.ZERO
	for deposit in field:
		var length = trips[deposit]
		total += length
		center += deposit.global_position / field.size()
		if "resource_a" in deposit:
			result.materials += deposit.resource_a
			result.material_count += 1
			result.nearest_materials = minf(result.nearest_materials, length)
		else:
			result.electronics += deposit.resource_b
			result.electronics_count += 1
			result.nearest_electronics = minf(result.nearest_electronics, length)
	result.mean = total / field.size()
	result.center = Vector2(center.x, center.z)
	return result


func _measure(map_path):
	var map_name = map_path.get_file().get_basename()
	var starts = game.map.get_node("SpawnPoints").get_children().map(
		func(marker): return marker.global_position * Vector3(1, 0, 1)
	)
	var count = constants.Match.MAPS[map_path].players
	_check(
		starts.size() == count, "%s has %d starts for %d players" % [map_name, starts.size(), count]
	)
	var headquarters = get_nodes_in_group("units").filter(
		func(unit): return unit.type == "CommandCenter"
	)
	var rings = []
	for index in starts.size():
		var start = starts[index]
		headquarters.sort_custom(
			func(a, b):
				return a.global_position.distance_to(start) < b.global_position.distance_to(start)
		)
		# Spawning can nudge an HQ clear of the map edge; workers use where it stands.
		var hq = headquarters[0]
		_check(
			hq.global_position.distance_to(start) < 6.0,
			"%s start %s has no HQ (nearest %s)" % [map_name, start, hq.global_position]
		)
		starts[index] = hq.global_position * Vector3(1, 0, 1)
		var ring = _ring(starts[index], hq.radius, HQ_SIDES)
		_check(ring.points.size() >= 3, "%s HQ at %s is boxed in" % [map_name, start])
		rings.append(ring)
	var deposits = get_nodes_in_group("resource_units").filter(
		func(deposit): return "resource_a" in deposit or "resource_b" in deposit
	)
	var trips = []
	for ring in rings:
		var row = {}
		for deposit in deposits:
			row[deposit] = _trip(
				ring, _ring(deposit.global_position, deposit.radius, DEPOSIT_SIDES)
			)
		trips.append(row)
	var fields = _fields(deposits)
	var signatures = []
	for index in starts.size():
		var opponent = (index + count / 2) % count
		var signature = []
		for field in fields:
			var own = _field_metrics(field, trips[index])
			own.opponent = _field_metrics(field, trips[opponent]).mean
			if "layout" in game.map:
				# Compare each authored sector's allocation. Small legal route
				# differences must not flip a contested-distance threshold and
				# invent an extra field for one start. Actual travel costs and
				# enemy exposure still face the same strict comparisons below.
				own.owned = _authored_owner(field) == index
			else:
				# Legacy maps infer ownership from distance to the other starts.
				own.owned = range(starts.size()).all(
					func(other):
						return (
							other == index
							or (
								_field_metrics(field, trips[other]).mean
								> own.mean * (1 + OWNERSHIP_MARGIN)
							)
						)
				)
			signature.append(own)
		signature.sort_custom(func(a, b): return a.mean < b.mean)
		signatures.append(signature)
		_check(
			signature.all(func(entry): return entry.mean < INF),
			"%s start %d cannot reach every deposit" % [map_name, index]
		)
	print(
		"MAP ",
		map_name,
		" starts=",
		starts.size(),
		" fields=",
		fields.size(),
		" base-to-base=%.1f" % _trip(rings[0], rings[count / 2])
	)
	for index in starts.size():
		var signature = signatures[index]
		print("  start %d (%.1f, %.1f)" % [index, starts[index].x, starts[index].z])
		for rank in signature.size():
			var entry = signature[rank]
			print(
				(
					(
						"    #%d (%.1f, %.1f) mean=%.1f materials@%.1f electronics@%.1f rival=%.1f"
						% [
							rank + 1,
							entry.center.x,
							entry.center.y,
							entry.mean,
							entry.nearest_materials,
							entry.nearest_electronics,
							entry.opponent
						]
					)
					+ (
						" A=%d/%d B=%d/%d"
						% [
							entry.materials,
							entry.material_count,
							entry.electronics,
							entry.electronics_count
						]
					)
				)
			)
	# The two starts used by a skirmish (and every other opposed pair) must see
	# the same economy, field by field, including contested and enemy fields.
	for index in range(count / 2):
		_compare(
			"%s starts %d/%d" % [map_name, index, index + count / 2],
			signatures[index],
			signatures[index + count / 2],
			true
		)
	# Every start, including those of larger maps, owns the same base fields.
	var owned = signatures.map(
		func(signature): return signature.filter(func(entry): return entry.owned)
	)
	for index in range(1, starts.size()):
		_check(
			owned[index].size() == owned[0].size(),
			(
				"%s starts 0/%d own %d and %d fields"
				% [map_name, index, owned[0].size(), owned[index].size()]
			)
		)
		_compare("%s starts 0/%d own" % [map_name, index], owned[0], owned[index], false)


func _compare(label_prefix, reference, other, complete):
	other = other.duplicate()
	var depth = mini(reference.size(), other.size())
	var worst = 0.0
	for rank in depth:
		var expected = reference[rank]
		# Match each field with its counterpart; nearly equidistant fields may be
		# listed in either order on mirrored starts.
		var best = null
		var best_cost = INF
		for candidate in other:
			var cost = absf(candidate.mean - expected.mean)
			if complete:
				cost += absf(candidate.opponent - expected.opponent)
			if (
				candidate.materials != expected.materials
				or candidate.electronics != expected.electronics
				or candidate.material_count != expected.material_count
				or candidate.electronics_count != expected.electronics_count
			):
				cost += 100000.0
			if cost < best_cost:
				best_cost = cost
				best = candidate
		var label = "%s field #%d" % [label_prefix, rank + 1]
		_check(best != null, label + " has no reachable counterpart")
		if best == null:
			continue
		other.erase(best)
		_check(best_cost < 100000.0, label + " stock or deposit count differs")
		var tolerance = NEAR_TOLERANCE if rank < 2 else FAR_TOLERANCE
		var metrics = ["mean", "nearest_materials", "nearest_electronics"]
		if complete:
			metrics.append("opponent")
		for metric in metrics:
			var a = expected[metric]
			var b = best[metric]
			if a == INF and b == INF:
				continue
			var spread = absf(a - b)
			var allowed = maxf(tolerance.absolute, tolerance.relative * (a + b) / 2)
			worst = maxf(worst, spread / maxf(.001, (a + b) / 2))
			_check(
				spread <= allowed,
				"%s %s %.1f vs %.1f (allowed %.1f)" % [label, metric, a, b, allowed]
			)
	print(
		"  BALANCE %s %d fields worst relative spread %.1f%%" % [label_prefix, depth, worst * 100]
	)
