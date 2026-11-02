extends "res://tests/headless/ResourceMapEconomyRegression.gd"

# Elevated-terrain engine contract on the hidden TerrainTestMap: tiers, ramps,
# cliffs, water, fords and solid formations reach navigation exactly as
# authored; vehicles climb ramps but never cliffs; camera picking lands on the
# surface players see; foundations accept gentle ramps but reject cliffs; rebakes stay fast.

const MAP = "res://source/match/maps/battlefields/TerrainTestMap.tscn"
const Placement = preload("res://source/match/utils/UnitPlacementUtils.gd")
var moving
var nav


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	moving = load("res://source/match/units/actions/Moving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var started = Time.get_ticks_msec()
	await _create_match()
	print("Terrain test map ready in %d ms" % (Time.get_ticks_msec() - started))
	nav = game.navigation.terrain.navigation_map_rid
	_check_ground()
	_check_navigation()
	_check_projection()
	_check_placement()
	await _check_picking()
	await _check_rebake()
	await _check_rotated_footprint()
	await _check_travel()
	await _check_save_round_trip()
	await _close()
	for message in _errors:
		push_error(message)
	print("Terrain navigation: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _create_match():
	var settings = _settings("bastion", "helix", false)
	settings.map_path = MAP
	settings.players[1].spawn_index_offset = 0
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(MAP).instantiate()
	root.add_child(game)
	current_scene = game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(90)


func _check_ground():
	var map = game.map
	_check(map.is_elevated() and is_equal_approx(map.max_height(), 6.0), "Map is not elevated")
	_near(map.height_at(Vector2(20, 20)), 3.0, "Main plateau height")
	_near(map.height_at(Vector2(19, 74)), 6.0, "Overlook height")
	_near(map.height_at(Vector2(100, 40)), 0.0, "Low ground height")
	_near(map.height_at(Vector2(49, 45)), 1.5, "Ramp midpoint height", 0.3)
	_near(map.height_at(Vector2(96, 80)), 3.0, "Shared mesa height")
	# The second start receives the rotated plateau.
	_near(map.height_at(Vector2(172, 140)), 3.0, "Rotated plateau height")
	var start: Vector3 = map.get_node("SpawnPoints").get_child(1).position
	_check(start.distance_to(Vector3(168, 3, 132)) < 0.1, "Rotated start marker: %s" % start)
	_check(map.get_node("Resources").get_child_count() == 28, "Four fields of seven deposits")
	_check(map.points_of_interest.size() == 4, "Rotated refinery and data relay pairs")


func _check_navigation():
	# Plateau lip to the ground directly beneath it: units must use the ramp.
	var around = _path_length(Vector3(50, 3, 10), Vector3(62, 0, 10))
	_check(around > 35.0, "Cliff is crossable (path %.1f m)" % around)
	var overlook = NavigationServer3D.map_get_path(
		nav, Vector3(60, 0, 100), Vector3(19, 6, 74), true
	)
	_check(
		not overlook.is_empty() and overlook[-1].distance_to(Vector3(19, 6, 74)) < 1.0,
		"Overlook unreachable by its ramp"
	)
	var pond = NavigationServer3D.map_get_closest_point(nav, Vector3(121, 0, 27))
	_check(Vector2(pond.x, pond.z).distance_to(Vector2(121, 27)) > 4.0, "Pond is walkable")
	var rock = NavigationServer3D.map_get_closest_point(nav, Vector3(115.5, 0, 64.5))
	_check(
		not Geometry2D.is_point_in_polygon(
			Vector2(rock.x, rock.z),
			PackedVector2Array(
				[Vector2(110, 60), Vector2(118, 58), Vector2(121, 68), Vector2(112, 72)]
			)
		),
		"Solid formation is walkable"
	)
	var bridged = _path_length(Vector3(130, 0, 15), Vector3(158, 0, 14))
	_check(bridged < 34.0, "Stream bridge not used (path %.1f m)" % bridged)
	var ford = NavigationServer3D.map_get_closest_point(nav, Vector3(160, -0.3, 52))
	_check(Vector2(ford.x, ford.z).distance_to(Vector2(160, 52)) < 0.5, "Ford is not walkable")
	# Nothing walkable hides beneath a plateau.
	var under = NavigationServer3D.map_get_closest_point(nav, Vector3(30, 0, 30))
	_check(under.y > 2.5, "Navigation mesh tunnels under the plateau")


func _check_projection():
	# Unit positions sit below the walkable surface by their path offset. On every
	# tier and ramp they must project straight up onto it (no sideways drift) and
	# the per-tier fast path must agree with the navigation server.
	var terrain_navigation = game.navigation.terrain
	for point in [
		Vector3(36, 2.4, 12),
		Vector3(19, 5.4, 74),
		Vector3(100, -0.6, 40),
		Vector3(96, 2.4, 80),
		Vector3(49, 0.9, 45),
		Vector3(58.5, -0.6, 20)
	]:
		var fast = terrain_navigation.closest_point(point)
		var surface = game.map.height_at(Vector2(point.x, point.z)) + 0.5
		var exact = NavigationServer3D.map_get_closest_point(
			nav, Vector3(point.x, surface, point.z)
		)
		_check(fast.distance_to(exact) < 0.05, "Projection mismatch at %s" % point)
		_check(
			Vector2(fast.x, fast.z).distance_to(Vector2(point.x, point.z)) < 0.02,
			"Projection drifts sideways at %s: %s" % [point, fast]
		)


func _check_placement():
	var units = get_nodes_in_group("units") + get_nodes_in_group("resource_units")
	_check(
		(
			Placement.validate_agent_placement_position(
				Vector3(36, 3, 12), 2.0, units, nav, game.map
			)
			== Placement.VALID
		),
		"Level plateau rejects a structure"
	)
	_check(
		(
			Placement.validate_agent_placement_position(
				Vector3(56, 3, 20), 2.0, units, nav, game.map
			)
			== Placement.NOT_LEVEL
		),
		"Structure may straddle a cliff"
	)
	_check(
		(
			Placement.validate_agent_placement_position(
				Vector3(49, 1.5, 45), 2.0, units, nav, game.map
			)
			== Placement.VALID
		),
		"Gentle ramp rejects a small foundation"
	)
	_check(
		(
			Placement.validate_agent_placement_position(Vector3(19, 3, 92), 3.0, [], nav, game.map)
			== Placement.NOT_LEVEL
		),
		"Large foundation accepts excessive height variation"
	)
	for point in [Vector3(121, 0, 27), Vector3(115.5, 0, 64.5)]:
		_check(
			(
				Placement.validate_agent_placement_position(point, 2.0, [], nav, game.map)
				!= Placement.VALID
			),
			"Relaxed placement accepts water or solid rock at %s" % point
		)
	var footprint = load("res://source/match/utils/Footprint.gd")
	var outline = PackedVector2Array(
		[Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]
	)
	for entry in [
		[Vector3(36, 3, 12), Placement.VALID],
		[Vector3(49, 1.5, 45), Placement.VALID],
		[Vector3(56, 3, 20), Placement.NOT_LEVEL],
	]:
		var polygon = footprint.outline_at(outline, Transform3D(Basis(), entry[0]))
		var result = Placement.validate_footprint_placement(polygon, [], nav, game.map)
		_check(
			(result == Placement.VALID) == (entry[1] == Placement.VALID),
			"Polygon foundation disagrees with terrain at %s: %d" % [entry[0], result]
		)
	var opponents = get_nodes_in_group("players").filter(
		func(player): return player.has_method("_find_footprint_site")
	)
	var site = opponents[0]._find_footprint_site(Vector3(49, 1.5, 45), outline, nav)
	_check(site.origin.is_finite(), "AI cannot find a supported polygon foundation")
	if site.origin.is_finite():
		_check(
			is_equal_approx(
				site.origin.y, game.map.height_at(Vector2(site.origin.x, site.origin.z))
			),
			"AI polygon placement inherits its search origin's height"
		)


func _check_picking():
	var camera = game.get_node("IsometricCamera3D")
	for target in [Vector3(20, 3, 20), Vector3(19, 6, 74), Vector3(100, 0, 40)]:
		camera.set_position_safely(target)
		await _frames(2)
		var picked = camera.get_ray_intersection(camera.unproject_position(target))
		_check(
			picked is Vector3 and picked.distance_to(target) < 0.3,
			"Picking %s returned %s" % [target, picked]
		)


func _check_rebake():
	var terrain_navigation = game.navigation.terrain
	var started = Time.get_ticks_msec()
	root.get_node("MatchSignals").schedule_navigation_rebake.emit(
		constants.Match.Navigation.Domain.TERRAIN
	)
	await _frames(2)
	while not terrain_navigation.is_synchronized():
		await process_frame
		if Time.get_ticks_msec() - started > 5000:
			break
	var elapsed = Time.get_ticks_msec() - started
	print("Terrain rebake settled in %d ms" % elapsed)
	_check(elapsed < 2000, "Terrain rebake took %d ms" % elapsed)


func _check_travel():
	var human = game._get_human_player()
	var tank = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(tank, Transform3D(Basis(), Vector3(30, 3, 34)), human)
	await _frames(30)
	_check(tank.global_position.y > 2.0, "Tank spawned below its plateau")
	for target in [Vector3(100, 0, 40), Vector3(19, 6, 74), Vector3(30, 3, 34)]:
		tank.issue_manual_order(moving.new(target))
		var frames = 0
		while frames < 60 * 120:
			await _frames(30)
			frames += 30
			if (tank.global_position * Vector3(1, 0, 1)).distance_to(target * Vector3(1, 0, 1)) < 3:
				break
		var flat = (tank.global_position * Vector3(1, 0, 1)).distance_to(target * Vector3(1, 0, 1))
		print("Tank reached %s in %.1f s (miss %.1f m)" % [target, frames / 60.0, flat])
		_check(flat < 3.0, "Tank did not reach %s (%.1f m short)" % [target, flat])
		_check(
			absf(tank.global_position.y - (target.y - 0.6)) < 0.8,
			"Tank height %.2f at %s" % [tank.global_position.y, target]
		)


func _path_length(from: Vector3, to: Vector3) -> float:
	var path = NavigationServer3D.map_get_path(nav, from, to, true)
	var length = 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length if not path.is_empty() else INF


func _near(value, expected, message, tolerance = 0.05):
	_check(
		absf(value - expected) <= tolerance, "%s: %.2f, expected %.2f" % [message, value, expected]
	)


func _check_save_round_trip():
	paused = true
	await _frames(2)
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Elevated capture failed: %s" % builder.error)
	if snapshot == null:
		return
	_check(snapshot.map_revision == 1, "Authored map revision not recorded")
	var tank = get_nodes_in_group("units").filter(func(unit): return unit.type == "Tank")
	var saved_height = tank[0].global_position.y if not tank.is_empty() else 0.0
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var path = "user://terrain-nav-%d.json" % OS.get_process_id()
	_check(file.write_file(path, snapshot), "Could not write elevated save")
	var stale = snapshot.duplicate(true)
	stale.map_revision = 2
	var restorer = load("res://source/match/saves/MatchRestore.gd").new()
	var rejected = await restorer.restore(self, stale)
	_check(not rejected.ok, "Save from another map revision was accepted")
	var loaded = await restorer.restore(self, file.read_file(path))
	_check(loaded.ok, "Elevated restore failed: %s" % loaded.get("error", ""))
	if loaded.has("game"):
		game = loaded.game
	DirAccess.remove_absolute(path)
	if not loaded.ok:
		return
	paused = false
	await _frames(30)
	var restored = get_nodes_in_group("units").filter(func(unit): return unit.type == "Tank")
	_check(
		not restored.is_empty() and absf(restored[0].global_position.y - saved_height) < 0.2,
		"Restored tank left its tier"
	)
	_check(game.map.is_elevated(), "Restored map is not elevated")


# A polygon footprint turns with its body exactly once.
func _check_rotated_footprint():
	var body = Node3D.new()
	body.position = Vector3(140, 0, 100)
	body.rotation.y = deg_to_rad(30)
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.footprint = PackedVector2Array(
		[Vector2(-1, -8), Vector2(1, -8), Vector2(1, 8), Vector2(-1, 8)]
	)
	obstacle.affect_navigation_mesh = true
	obstacle.path_height_offset = .6
	body.add_child(obstacle)
	game.map.get_node("Decorations").add_child(body)
	await _frames(10)
	while not game.navigation.terrain.is_synchronized():
		await process_frame
	var along = body.position + Vector3(0, 0, 6).rotated(Vector3.UP, body.rotation.y)
	var unturned = body.position + Vector3(0, 0, 6)
	var blocked = NavigationServer3D.map_get_closest_point(nav, along + Vector3(0, 0.5, 0))
	var open = NavigationServer3D.map_get_closest_point(nav, unturned + Vector3(0, 0.5, 0))
	_check(
		Vector2(blocked.x, blocked.z).distance_to(Vector2(along.x, along.z)) > 0.5,
		"Rotated footprint does not cover its own axis"
	)
	_check(
		Vector2(open.x, open.z).distance_to(Vector2(unturned.x, unturned.z)) < 0.2,
		"Rotated footprint was turned twice"
	)
	body.queue_free()
	await _frames(10)
