extends "res://tests/headless/MapResourceBalanceRegression.gd"

# Check the published mesh with all deposits and neutral buildings present.
# A connected centerline alone misses pinched mouths and single-file dikes.
const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
# Enough centerline room for three maximum-radius ground units.
const MIN_USABLE_WIDTH = 3.6
const SAMPLE_STEP = 0.25


func _run():
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var only = Array(OS.get_cmdline_user_args())
	for map_path in constants.Match.MAPS:
		if not Registry.is_authored(map_path) or map_path.get_file() == "TerrainTestMap.tscn":
			continue
		var id = map_path.get_file().get_basename()
		if not only.is_empty() and id not in only:
			continue
		await _create(map_path)
		for player in get_nodes_in_group("players"):
			player.process_mode = Node.PROCESS_MODE_INHERIT
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		await _frames(5)
		var layout = game.map.layout
		for ramp in layout.ramps:
			_check_width(ramp.get("name", "ramp"), ramp.from, ramp.to, ramp.width)
		for bridge in layout.bridges:
			_check_width("bridge", bridge.line[0], bridge.line[-1], bridge.width)
		if id == "SaltwindBasinMap":
			for player in layout.players:
				var definition = Registry.definition(map_path)
				for ends in [
					[Vector2(32, 130), Vector2(72, 130)], [Vector2(52, 112), Vector2(52, 150)]
				]:
					_check_width(
						"dike",
						Registry.Layout.transform_point(ends[0], definition, player),
						Registry.Layout.transform_point(ends[1], definition, player),
						8.0
					)
			await _traffic(Vector2(30, 130), Vector2(74, 130))
		elif id == "FourRiversMap":
			var bridge = layout.bridges[0]
			await _traffic(bridge.line[0], bridge.line[-1])
		elif id == "CopperBadlandsMap":
			for ramp in layout.ramps:
				if ramp.get("player", -1) == 0 and ramp.name.begins_with("Haul ramp"):
					await _traffic(ramp.from, ramp.to)
		elif id == "CoastalFoundryMap":
			var definition = Registry.definition(map_path)
			for player in layout.players:
				var a = Registry.Layout.transform_point(Vector2(60, 34), definition, player)
				var b = Registry.Layout.transform_point(Vector2(60, 52), definition, player)
				_check_width("Foundry hall approach", a, b, 12.0, 8.0)
				await _traffic(a, b)
		elif id == "RailspireJunctionMap":
			# Narrow approaches can deadlock only for some avoidance schedules.
			# Repeat both directions before accepting the crossing as usable.
			for trial in 3:
				for ramp in layout.ramps:
					if ramp.get("player", -1) == 0 and ramp.name == "Overpass approach":
						await _traffic(ramp.from, ramp.to)
		print("PASSAGES ", id)
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Map passages: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _check_width(label, a: Vector2, b: Vector2, width: float, required_width := MIN_USABLE_WIDTH):
	var normal = (b - a).normalized().orthogonal()
	var minimum = INF
	var worst = a
	var nav = game.navigation.terrain.navigation_map_rid
	for step in range(1, 20):
		var center = a.lerp(b, step / 20.0)
		var run = 0.0
		var longest = 0.0
		for side in range(-int(width / SAMPLE_STEP / 2), int(width / SAMPLE_STEP / 2) + 1):
			var flat = center + normal * side * SAMPLE_STEP
			var point = game.map.ground_point(flat) + Vector3.UP * .5
			# Closest-point projection shifts slightly along voxelized slopes.
			# Allow half a navigation voxel, while rejecting genuinely blocked samples.
			var projected = NavigationServer3D.map_get_closest_point(nav, point)
			if (
				Vector2(projected.x, projected.z).distance_to(flat) < .2
				and absf(projected.y - point.y) < .75
			):
				run += SAMPLE_STEP
				longest = maxf(longest, run)
			else:
				run = 0.0
		if longest < minimum:
			minimum = longest
			worst = center
	_check(
		minimum >= required_width,
		(
			"%s %s at %s has only %.2f m of continuous navigation width"
			% [game.map.layout.id, label, worst, minimum]
		)
	)


# Three tanks in each direction, through the same passage at the same time.
# Every tank must cross within a bounded time and stay near the crossing;
# finding a long route around the obstacle is not a successful passage.
func _traffic(a: Vector2, b: Vector2):
	var moving = load("res://source/match/units/actions/Moving.gd")
	var axis = (b - a).normalized()
	var tanks = []
	var goals = []
	var max_detour = 0.0
	for side in 2:
		for rank in 3:
			var lateral = axis.orthogonal() * (rank - 1) * 2.4
			var start = (a if side == 0 else b) + lateral
			var goal = (b if side == 0 else a) + lateral
			var tank = load("res://source/match/units/Tank.tscn").instantiate()
			game._setup_and_spawn_unit(
				tank, Transform3D(Basis(), game.map.ground_point(start)), game._get_human_player()
			)
			tanks.append(tank)
			goals.append(game.map.ground_point(goal))
	await _frames(30)
	for i in tanks.size():
		tanks[i].issue_manual_order(moving.new(goals[i]))
	var reached = false
	for tick in 150:
		await _frames(30)
		reached = true
		for i in tanks.size():
			var point = Vector2(tanks[i].global_position.x, tanks[i].global_position.z)
			max_detour = maxf(max_detour, absf((point - a).cross(axis)))
			if point.distance_to(Vector2(goals[i].x, goals[i].z)) > 3.0:
				reached = false
		if reached:
			break
	if not reached:
		for i in tanks.size():
			print("STRANDED %d at %s goal %s" % [i, tanks[i].global_position, goals[i]])
	var label = "%s %s -> %s" % [game.map.layout.id, a, b]
	_check(reached, "Opposing tanks failed to cross " + label)
	_check(max_detour < 12.0, "Tanks detoured around passage " + label)
	print("TRAFFIC %s reached=%s lateral=%.1f" % [label, reached, max_detour])
	for tank in tanks:
		tank.queue_free()
	await _frames(5)
