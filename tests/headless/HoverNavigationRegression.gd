extends "res://tests/headless/MatchFixture.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/battlefields/FourRiversMap.tscn"
	for side in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = side + 1
		player.faction = "helix" if side == 0 else "bastion"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(90)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var terrain = _game.map.terrain
	var hover = _game.navigation.hover
	var terrain_map = _game.navigation.terrain.navigation_map_rid
	var point = Vector3.INF
	var destination = Vector3.INF
	for row in terrain.rows:
		for column in terrain.columns:
			if terrain.flags[row * terrain.columns + column] & terrain.WATER == 0:
				continue
			var candidate = Vector3(
				(column + .5) * terrain.RESOLUTION, 0, (row + .5) * terrain.RESOLUTION
			)
			var hover_point = NavigationServer3D.map_get_closest_point(
				hover.navigation_map_rid, candidate
			)
			var ground_point = NavigationServer3D.map_get_closest_point(terrain_map, candidate)
			if (
				((hover_point - candidate) * Vector3(1, 0, 1)).length() > .05
				or ((ground_point - candidate) * Vector3(1, 0, 1)).length() < 1.0
			):
				continue
			for offset in [
				Vector3(3, 0, 0), Vector3(0, 0, 3), Vector3(-3, 0, 0), Vector3(0, 0, -3)
			]:
				var other = candidate + offset
				if terrain.flag_at(Vector2(other.x, other.z)) & terrain.WATER == 0:
					continue
				var projected = NavigationServer3D.map_get_closest_point(
					hover.navigation_map_rid, other
				)
				if ((other - projected) * Vector3(1, 0, 1)).length() <= .05:
					point = candidate
					destination = other
					break
			if point.is_finite():
				break
		if point.is_finite():
			break
	_check(point.is_finite(), "Hover fixture found no traversable shallow-water route")
	if point.is_finite():
		var worker = _spawn("Worker", _human, point)
		await _frames(20)
		var movement = worker.get_node("Movement")
		_check(movement._hovering, "Flux Skimmer did not select ground-hover navigation")
		_check(worker.combat_domain() == 1, "Hover harvester became an airborne combat target")
		_check(
			((worker.position - point) * Vector3(1, 0, 1)).length() < .1,
			"Hover spawn snapped out of shallow water"
		)
		_check(
			absf(worker.position.y - movement._hover_height(point)) < .03,
			"Hover body did not float above the water surface"
		)
		if "--native-crowd-runtime" in OS.get_cmdline_user_args():
			_check(movement._native_handle >= 0, "Ground hover disabled native crowd execution")
		await _inspect_hover(worker, "water-start")
		worker.process_mode = Node.PROCESS_MODE_INHERIT
		worker.manual_orders.submit(
			load("res://source/match/orders/ManualOrders.gd").point_order("move", destination)
		)
		await _frames(180)
		print(
			"HOVER ROUTE ",
			point,
			" -> ",
			destination,
			" actual=",
			worker.position,
			" target=",
			movement.target_position,
			" path=",
			movement.get_current_navigation_path(),
			" active=",
			movement._has_destination,
			" speed=",
			movement.speed
		)
		_check(
			(
				((worker.position - destination) * Vector3(1, 0, 1)).length()
				<= movement.target_desired_distance + .05
			),
			"Flux Skimmer could not cross shallow water"
		)
		_check(
			absf(worker.position.y - movement._hover_height(worker.position)) < .03,
			"Moving Flux Skimmer sank into water or rough ground"
		)
		await _inspect_hover(worker, "water-finish")
	await _cross_low_rock()
	var model = load("res://source/match/maps/terrain/TerrainModel.gd").new(
		{
			"size": Vector2(10, 10),
			"blockers":
			[
				{
					"polygon": [Vector2(3, 3), Vector2(7, 3), Vector2(7, 7), Vector2(3, 7)],
					"height": .8
				}
			]
		}
	)
	_check(hover._hoverable(model, 10, 10), "Small rocks block Flux Skimmer navigation")
	model.cover_tops[10 * model.columns + 10] = 4.0
	_check(not hover._hoverable(model, 10, 10), "Hover route crosses a tall solid cliff")
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Hover navigation: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _cross_low_rock():
	var terrain = _game.map.terrain
	var center = Vector3.INF
	for row in range(15, terrain.rows - 15):
		for column in range(15, terrain.columns - 15):
			var free = true
			var floor_height = terrain.ground_tops[row * terrain.columns + column]
			for dz in range(-2, 3):
				for dx in range(-9, 10):
					var index = (row + dz) * terrain.columns + column + dx
					if (
						terrain.flags[index] != 0
						or absf(terrain.ground_tops[index] - floor_height) > .01
					):
						free = false
			if free:
				center = Vector3(
					(column + .5) * terrain.RESOLUTION,
					floor_height,
					(row + .5) * terrain.RESOLUTION
				)
				break
		if center.is_finite():
			break
	_check(center.is_finite(), "No flat rock crossing fixture available")
	if not center.is_finite():
		return
	var cell = Vector2i(
		floori(center.x / terrain.RESOLUTION), floori(center.z / terrain.RESOLUTION)
	)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var index = (cell.y + dz) * terrain.columns + cell.x + dx
			terrain.flags[index] |= terrain.SOLID
			terrain.cover_tops[index] = terrain.ground_tops[index] + .8
	var rock = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = Vector3(2.5, .8, 2.5)
	rock.mesh = shape
	rock.position = center + Vector3.UP * .4
	_game.map.add_child(rock)
	_game.navigation.hover.bake(_game.map)
	for frame in 120:
		if _game.navigation.hover.is_synchronized():
			break
		await _frames(1)
	var worker = _spawn("Worker", _human, center + Vector3(-4, 0, 0))
	await _frames(20)
	worker.process_mode = Node.PROCESS_MODE_INHERIT
	worker.manual_orders.submit(
		load("res://source/match/orders/ManualOrders.gd").point_order(
			"move", center + Vector3(4, 0, 0)
		)
	)
	var highest = worker.global_position.y
	var reviewed = false
	for frame in 180:
		await _frames(1)
		highest = maxf(highest, worker.global_position.y)
		if not reviewed and worker.global_position.y > center.y + .85:
			reviewed = true
			await _inspect_hover(worker, "low-rock")
	_check(highest > center.y + .85, "Flux Skimmer did not float above actual low rock")
	_check(
		absf(worker.global_position.x - center.x - 4) < .6,
		"Low rock stalled or slowed ground-hover crossing"
	)
	print(
		"HOVER LOW ROCK peak=", highest, " ground=", center.y, " arrival=", worker.global_position
	)


func _inspect_hover(_worker, _label):
	pass
