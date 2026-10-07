extends "res://tests/headless/AlpineRegression.gd"


func _initialize():
	create_timer(1200).timeout.connect(
		func():
			push_error("Alpine environment regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, ALPINE)
		_enemy().set_process(false)
		await _frames(60)
		_geometry()
		await _flight()
		await _passes()
		_geometry()
		await _relay_and_restore(game._get_human_player(), _enemy())
		_geometry()
		paused = false
		game.queue_free()
		await _frames(5)
		await _economy(faction)
	manager.autosaves_enabled = autosaves
	print("Alpine environment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _enemy():
	return get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]


func _geometry():
	var map = game.map
	_check(map.get_node("Decorations").get_child_count() == 6, "Alpine blocker count changed")
	for index in range(6):
		var shelf = map.get_node("Decorations").get_child(index)
		var blocker = shelf.get_node("MovementObstacle")
		_check(
			is_equal_approx(blocker.radius, 6.5) and is_equal_approx(blocker.sight_height, 1.15),
			"Shelf gameplay envelope changed"
		)
		var center = shelf.global_position
		_check(
			not game.battlefield.line_clear(
				center + Vector3(-7, 0.8, 0), center + Vector3(7, 0.8, 0)
			),
			"Shelf no longer blocks ground sight/fire"
		)
		_check(
			game.battlefield.line_clear(center + Vector3(-7, 1.5, 0), center + Vector3(7, 1.5, 0)),
			"Shelf incorrectly blocks elevated sight/fire"
		)
		var points = _vertices(shelf.get_node("Model"))
		_check(points.size() > 1000, "Detailed shelf geometry missing")
		var highest = 0.0
		var widest = 0.0
		for point in points:
			var local = point - shelf.global_position
			highest = maxf(highest, local.y)
			widest = maxf(widest, Vector2(local.x, local.z).length())
		_check(
			highest <= 1.15 and widest <= 6.5,
			"Imported shelf exceeds actual sight/navigation bounds"
		)
	for z in [40, 76]:
		_check(
			game.battlefield.line_clear(Vector3(52, 0.8, z), Vector3(76, 0.8, z)),
			"Alpine open pass gained an optical blocker"
		)
	var cover = map.get_node("AlpineGroundCover")
	_check(cover.get_child_count() == 12, "Alpine ground cover missing")
	for plant in cover.get_children():
		_check(
			plant.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Low ground cover gained physics"
		)
		for vertex in _vertices(plant):
			_check(vertex.y < 0.3, "Ground cover obstructs unit visibility")
	var exterior = map.exterior
	_check(exterior.models.size() == 28, "Exterior landmarks or vegetation missing")
	for model in exterior.models:
		var point = model.position
		var radius = model.get_meta("exterior_radius")
		_check(
			(
				point.x + radius < 0
				or point.z + radius < 0
				or point.x - radius > 128
				or point.z - radius > 104
			),
			"Exterior asset footprint enters playable terrain"
		)
		_check(
			model.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Scenic geometry gained physics"
		)
		for vertex in _vertices(model):
			_check(
				vertex.x < 0 or vertex.z < 0 or vertex.x > 128 or vertex.z > 104,
				"Imported exterior mesh enters map"
			)
	var arrays = exterior.ground.mesh.surface_get_arrays(0)
	for point in arrays[Mesh.ARRAY_VERTEX]:
		_check(
			point.x < 0 or point.z < 0 or point.x > 128 or point.z > 104,
			"Backdrop terrain changes playable ground"
		)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var point = arrays[Mesh.ARRAY_VERTEX][index]
		var inner_edge = (
			(
				(is_equal_approx(point.x, -2) or is_equal_approx(point.x, 130))
				and point.z >= -2
				and point.z <= 106
			)
			or (
				(is_equal_approx(point.z, -2) or is_equal_approx(point.z, 106))
				and point.x >= -2
				and point.x <= 130
			)
		)
		if inner_edge:
			_check(
				is_zero_approx(point.y) and arrays[Mesh.ARRAY_NORMAL][index].y > 0.999,
				"Backdrop has a height or lighting seam at the playable plane"
			)
	var minimum_normal_y = 1.0
	for normal in arrays[Mesh.ARRAY_NORMAL]:
		minimum_normal_y = minf(minimum_normal_y, normal.y)
	_check(minimum_normal_y > 0.2, "Backdrop terrain has inverted normals")
	var human = game._get_human_player()
	_check(
		not game.battlefield.is_observed(human, _units(_enemy(), "CommandCenter")[0]),
		"Backdrop revealed hidden enemy"
	)
	print("PASS: shelf geometry/sight/fire, exterior bounds/seams/normals and hidden enemy")


func _vertices(model):
	var points = PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			for point in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.global_transform * point)
	return points


func _flight():
	var human = game._get_human_player()
	for role in ["Drone", "Helicopter"]:
		for z in [12, 24, 49, 61, 86, 98]:
			var aircraft = _spawn_alpine(role, human, Vector3(48, 1.5, z))
			aircraft.issue_manual_order(moving.new(Vector3(80, 1.5, z)))
			var crossed = false
			for frame in 1000:
				await physics_frame
				if absf(aircraft.position.x - 64) < 6.5:
					crossed = true
					_check(aircraft.position.y >= 1.45, "Aircraft clips alpine shelf")
				if aircraft.position.x > 79:
					break
			_check(crossed and aircraft.position.x > 79, "Aircraft failed alpine ridge crossing")
			aircraft.queue_free()
			await _frames(3)
	print("PASS: drone and strike aircraft cross all six alpine shelves")


func _passes():
	var human = game._get_human_player()
	var ground = root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	var air = root.get_node("Constants").Match.Navigation.Domain.AIR
	for z in [36.0, 73.0, 2.5]:
		var route = _route(ground, Vector3(40, 0, z), Vector3(88, 0, z))
		_check(route.size() >= 2 and _length(route) < 55, "Alpine pass/bypass geometry changed")
	var base = _length(_route(ground, Vector3(25, 0, 18), Vector3(103, 0, 86))) / 2.6
	var ridge = _length(_route(ground, Vector3(52, 0, 55), Vector3(76, 0, 55)))
	var flight = _length(_route(air, Vector3(52, 1.5, 55), Vector3(76, 1.5, 55)))
	_check(base >= 35 and base <= 55 and ridge > flight + 8, "Alpine route identity changed")
	print("Alpine environment routes: base %.1fs, ground %.1fm / air %.1fm" % [base, ridge, flight])
	var army = []
	var origins = []
	var targets = []
	for lane in 3:
		for index in 16:
			var columns = 2 if lane == 2 else 4
			var z = [33.0, 70.0, 1.5][lane] + (index % columns) * 2.0
			var origin = Vector3(40 - (index / columns) * 2.5, 0, z)
			var target = Vector3(88 + (index / columns) * 2.5, 0, z)
			army.append(_spawn_alpine("Tank", human, origin))
			origins.append(origin)
			targets.append(target)
	await _frames(10)
	for index in army.size():
		army[index].issue_manual_order(moving.new(targets[index]))
	await _frames(600)
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Alpine environment snapshot failed: " + builder.error)
	if snapshot == null:
		return
	var ids = army.map(func(unit): return builder._reference(unit))
	var file = FileStore.new()
	var archive = "user://alpine-environment-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Alpine environment archive write failed")
	var reader = Restore.new()
	var restored = await reader.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(restored.ok, "Alpine environment archive load failed")
	if not restored.ok:
		return
	game = restored.game
	_enemy().set_process(false)
	army = ids.map(func(id): return reader.entities[id])
	_check(
		game.map.size == Vector2(128, 104) and game.settings.map_path == ALPINE,
		"Alpine archive map identity changed"
	)
	_check(get_nodes_in_group("resource_units").size() == 16, "Alpine archive duplicated fields")
	game.hud._toggle_pause()
	await _frames(3000)
	_check(army.all(func(unit): return unit.position.x > 85), "Alpine 16-tank approach stuck")
	for index in army.size():
		army[index].issue_manual_order(moving.new(origins[index]))
	await _frames(3600)
	for unit in army:
		if unit.position.x >= 43:
			print(
				"Alpine retreat stranded: ",
				unit.position,
				" target ",
				unit.get_node("Movement").target_position
			)
	_check(army.all(func(unit): return unit.position.x < 43), "Alpine 16-tank retreat stuck")
	for unit in army:
		unit.queue_free()
	await _frames(5)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(ground)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(64, 0, 55), 2.0, [], nav)
			== placement.NOT_NAVIGABLE
		),
		"Alpine shelf accepts building placement"
	)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(64, 0, 36), 2.0, [], nav)
			== placement.VALID
		),
		"Alpine pass staging ground rejects construction"
	)
	print("PASS: three 16-tank alpine advances/retreats, moving archive and placement")


func _economy(faction):
	await _skirmish(faction, ALPINE, false)
	_enemy().set_process(false)
	var human = game._get_human_player()
	var sides = [human, _enemy()]
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var materials = 0
	var electronics = 0
	for deposit in get_nodes_in_group("resource_units"):
		if "resource_a" in deposit:
			materials += deposit.resource_a
		else:
			electronics += deposit.resource_b
	_check(materials == 3000 and electronics == 1280, "Alpine stockpiles changed")
	var balances = []
	for side in sides:
		var workers = _units(side, "Worker")
		_check(
			workers.size() == 4 and _units(side, "Tank").is_empty(), "Alpine Standard start changed"
		)
		for index in 2:
			var kind = "resource_a" if index == 0 else "resource_b"
			var deposits = get_nodes_in_group("resource_units").filter(
				func(unit): return kind in unit
			)
			deposits.sort_custom(
				func(a, b):
					return (
						a.position.distance_squared_to(workers[index].position)
						< b.position.distance_squared_to(workers[index].position)
					)
			)
			workers[index].issue_manual_order(harvest.new(deposits[0]))
		balances.append(Vector2(side.resource_a, side.resource_b))
	await _frames(3000)
	for index in 2:
		_check(
			(
				sides[index].resource_a > balances[index].x
				and sides[index].resource_b > balances[index].y
			),
			"Alpine home field fails material/electronics return"
		)
		for worker in _units(sides[index], "Worker"):
			worker.issue_manual_order(null)
	var outer_fields = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit and unit.resource_b == 400
	)
	var chosen = []
	balances = []
	for side in sides:
		var worker = _units(side, "Worker")[2]
		outer_fields.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(worker.position)
					< b.position.distance_squared_to(worker.position)
				)
		)
		chosen.append(outer_fields[0])
		worker.issue_manual_order(harvest.new(outer_fields[0]))
		balances.append(side.resource_b)
	await _frames(5400)
	for index in 2:
		_check(
			chosen[index].resource_b < 400 and sides[index].resource_b > balances[index],
			"Alpine outer electronics cannot be collected and returned"
		)
	for worker in _units(human, "Worker"):
		worker.issue_manual_order(null)
	root.get_node("MatchSignals").deselect_all_units.emit()
	_units(human, "Worker")[3].get_node("Selection").select()
	var handler = human.get_node("StructurePlacementHandler")
	handler._on_structure_placement_request(load("res://source/match/units/PowerPlant.tscn"))
	handler._active_blueprint_node.position = Vector3(26, 0, 30)
	_check(
		handler._calculate_blueprint_position_validity() == handler.BlueprintPositionValidity.VALID,
		"Alpine home build space rejects paid generator"
	)
	var before = human.resource_a
	handler._finish_structure_placement()
	_check(human.resource_a < before, "Alpine generator was not paid for")
	await _frames(2400)
	_check(human.has_completed_structure("PowerPlant"), "Alpine engineer did not finish generator")
	print("PASS: ", faction, " both home fields, both expansions and paid construction")
	game.queue_free()
	await _frames(5)
