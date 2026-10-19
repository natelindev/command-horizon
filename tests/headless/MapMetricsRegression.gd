extends "res://tests/headless/TerrainNavRegression.gd"

# Numeric acceptance for every authored battlefield in the skirmish roster.
# Travel times use real navigation paths at basic tank speed. Each map must
# pass before it is offered in the skirmish picker:
#   Godot --headless --fixed-fps 60 --path . --script tests/headless/MapMetricsRegression.gd
#     -- [--report-only] [MapId ...]

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const TANK_SPEED = 2.6
const TARGETS = {
	"base_to_base": [75.0, 110.0],
	"natural": [0.0, 25.0],
	"home_field": [7.0, 11.0],
	"ramp_width": 6.0,
	"build_sites": 40,
	"fairness": 0.05,
	"fields_2p": 12,
	"fields_4p": 16,
}
var report_only = false


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	report_only = "--report-only" in OS.get_cmdline_user_args()
	var only = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	for path in _roster():
		var id = path.get_file().get_basename()
		if not only.is_empty() and id not in only:
			continue
		await _measure(path)
	for message in _errors:
		push_error(message)
	print("Map metrics: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _roster():
	var paths = []
	var only = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	for file in DirAccess.get_files_at(Registry.ROOT):
		if not file.ends_with(".tscn"):
			continue
		var id = file.get_basename()
		# The engine test battlefield is measured only on request.
		if id == "TerrainTestMap" and id not in only:
			continue
		paths.append(Registry.ROOT + file)
	return paths


func _metric(condition, message):
	if report_only:
		if not condition:
			print("  (target missed) " + message)
		return
	_check(condition, message)


func _measure(path):
	var layout = Registry.layout(path)
	var settings = _settings("bastion", "helix", false)
	settings.map_path = path
	settings.players.resize(1)
	for index in range(1, layout.players):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		player.faction = "helix"
		player.color = Color.from_hsv(index / 4.0, 0.7, 0.9)
		settings.players.append(player)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(60)
	nav = game.navigation.terrain.navigation_map_rid
	var id = layout.id
	print("== %s (%s, %d players)" % [layout.name, id, layout.players])
	var starts = []
	for base in layout.bases:
		starts.append(game.map.ground_point(base.start))
	_travel(id, starts)
	_naturals(id, layout, starts)
	_home_fields(id, layout)
	_ramps(id, layout)
	_build_space(id, starts)
	_resources(id, layout, starts)
	_sites(id, starts)
	await _close()


func _seconds(from: Vector3, to: Vector3) -> float:
	return _path_length(from, to) / TANK_SPEED


func _travel(id, starts):
	var times = []
	for a in starts.size():
		for b in range(a + 1, starts.size()):
			var seconds = _seconds(starts[a], starts[b])
			times.append(seconds)
			print("  base %d -> base %d: %.1f s" % [a + 1, b + 1, seconds])
	if times.is_empty():
		return
	times.sort()
	var nearest = times[0]
	_metric(
		nearest >= TARGETS.base_to_base[0] and nearest <= TARGETS.base_to_base[1],
		"%s nearest rival base %.1f s outside %s" % [id, nearest, TARGETS.base_to_base]
	)


func _naturals(id, layout, starts):
	var naturals = []
	for player in starts.size():
		var best = INF
		for expansion in layout.expansions:
			if expansion.get("player", -1) != player:
				continue
			best = minf(best, _seconds(starts[player], game.map.ground_point(expansion.site)))
		naturals.append(best)
		print("  base %d natural: %.1f s" % [player + 1, best])
		_metric(
			best >= TARGETS.natural[0] and best <= TARGETS.natural[1],
			"%s base %d natural %.1f s outside %s" % [id, player + 1, best, TARGETS.natural]
		)
	_fair(id, "natural", naturals)


func _home_fields(id, layout):
	var battlefield = load("res://source/match/maps/AuthoredBattlefield.gd")
	for base in layout.bases:
		for point in battlefield.field_points(base.start, base.field):
			var distance = point.distance_to(base.start)
			_metric(
				distance >= TARGETS.home_field[0] and distance <= TARGETS.home_field[1],
				"%s home deposit %.1f m from its start" % [id, distance]
			)


func _ramps(id, layout):
	for ramp in layout.ramps:
		_metric(
			ramp.width >= TARGETS.ramp_width,
			"%s ramp at %s only %.1f m wide" % [id, ramp.from, ramp.width]
		)


# Level, reachable footprints for a 2.5 m structure near each start.
func _build_space(id, starts):
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var obstacles = get_nodes_in_group("units") + get_nodes_in_group("resource_units")
	for index in starts.size():
		var start = starts[index]
		var count = 0
		for x in range(-30, 31, 4):
			for z in range(-30, 31, 4):
				var point = game.map.ground_point(Vector2(start.x + x, start.z + z))
				if Vector2(x, z).length() > 30:
					continue
				if (
					(
						placement.validate_agent_placement_position(
							point, 2.5, obstacles, nav, game.map
						)
						== placement.VALID
					)
					and _path_length(start, point) < 45.0
				):
					count += 1
		print("  base %d build sites: %d" % [index + 1, count])
		_metric(
			count >= TARGETS.build_sites, "%s base %d has %d build sites" % [id, index + 1, count]
		)


func _resources(id, layout, starts):
	var totals = []
	for _player in starts.size():
		totals.append(Vector2.ZERO)
	var unreachable = 0
	for deposit in get_nodes_in_group("resource_units"):
		var nearest = 0
		for player in starts.size():
			if (
				deposit.global_position.distance_to(starts[player])
				< deposit.global_position.distance_to(starts[nearest])
			):
				nearest = player
		totals[nearest] += Vector2(
			deposit.get("resource_a") if "resource_a" in deposit else 0,
			deposit.get("resource_b") if "resource_b" in deposit else 0
		)
		if _path_length(starts[nearest], deposit.global_position) == INF:
			unreachable += 1
	_metric(unreachable == 0, "%s has %d unreachable deposits" % [id, unreachable])
	var fields = layout.bases.size() + layout.expansions.size()
	var required = TARGETS.fields_2p if layout.players == 2 else TARGETS.fields_4p
	print("  fields: %d; per-player stock: %s" % [fields, totals])
	_metric(fields >= required, "%s has %d fields (need %d)" % [id, fields, required])
	var materials = []
	for total in totals:
		materials.append(total.x)
	_fair(id, "materials", materials)


func _sites(id, starts):
	for site in game.map.points_of_interest:
		var reachable = false
		for start in starts:
			if _path_length(start, site.global_position + Vector3(4, 0, 0)) < INF:
				reachable = true
		_metric(reachable, "%s site %s unreachable" % [id, site.label_title])


func _fair(id, label, values):
	if values.size() < 2:
		return
	var low = values.min()
	var high = values.max()
	_metric(
		high <= low * (1.0 + TARGETS.fairness) + 0.5,
		"%s %s unfair between starts: %s" % [id, label, values]
	)
