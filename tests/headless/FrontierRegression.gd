extends "res://tests/headless/AlpineRegression.gd"

const FRONTIER = "res://source/match/maps/DesertFrontier.tscn"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = root.size
		await _frontier_menu()
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, FRONTIER)
		var human = game._get_human_player()
		_enemy().set_process(false)
		await _frames(100)
		_check(await _frontier_routes(human) == true, "Frontier route suite did not finish")
		paused = false
		game.queue_free()
		await _frames(5)
		await _frontier_economy(faction)
	print("Desert Frontier: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _enemy():
	return get_nodes_in_group("players").filter(func(p): return p != game._get_human_player())[0]


func _frontier_routes(human):
	var failures_before = errors.size()
	var ground = root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	var air = root.get_node("Constants").Match.Navigation.Domain.AIR
	for z in [14, 48, 82]:
		var route = _route(ground, Vector3(36, 0, z), Vector3(92, 0, z))
		_check(route.size() >= 2 and _length(route) < 62, "A desert approach is blocked")
	var crossing = _route(ground, Vector3(28, 0, 26), Vector3(100, 0, 70))
	var seconds = _length(crossing) / 2.6
	_check(seconds >= 30 and seconds <= 45, "Desert base traversal outside target")
	var blocked = _route(ground, Vector3(43, 0, 31), Vector3(77, 0, 31))
	var flight = _route(air, Vector3(43, 1.5, 31), Vector3(77, 1.5, 31))
	_check(_length(blocked) > _length(flight) + 2, "Shelf does not change ground approach")
	print(
		(
			"Frontier base path %.1fs; shelf ground %.1fm / air %.1fm"
			% [seconds, _length(blocked), _length(flight)]
		)
	)
	var army = []
	for z in [14, 48, 82]:
		for index in 16:
			var unit = _spawn_alpine(
				"Tank", human, Vector3(36 - (index / 4) * 2.5, 0, z - 3 + (index % 4) * 2)
			)
			army.append(unit)
	await _frames(10)
	for index in army.size():
		var row = index % 16
		var z = [14, 48, 82][index / 16]
		army[index].issue_manual_order(
			moving.new(Vector3(90 + (row / 4) * 2.5, 0, z - 3 + (row % 4) * 2))
		)
	await _frames(600)
	paused = true
	var deposits_before = get_nodes_in_group("resource_units").size()
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Frontier snapshot failed: " + builder.error)
	if snapshot == null:
		return false
	var ids = army.map(func(unit): return builder._reference(unit))
	var file = FileStore.new()
	var archive = "user://frontier-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Frontier archive write failed")
	var reader = Restore.new()
	var restored = await reader.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(restored.ok, "Frontier restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return false
	game = restored.game
	human = game._get_human_player()
	_enemy().set_process(false)
	army = ids.map(func(id): return reader.entities[id])
	_check(
		game.map.size == Vector2(128, 96) and game.settings.map_path == FRONTIER,
		"Restored original desert instead of revision"
	)
	_check(
		get_nodes_in_group("resource_units").size() == deposits_before, "Restore duplicated fields"
	)
	game.hud._toggle_pause()
	await _frames(1800)
	_check(
		army.all(func(unit): return unit.position.x > 87),
		"A 16-tank group stuck on a desert approach"
	)
	await _frontier_capture("frontier-overview-%s" % human.faction, Vector3(64, 0, 48), 102)
	await _frontier_capture("frontier-staging-%s" % human.faction, Vector3(64, 0, 48), 34)
	for index in army.size():
		var row = index % 16
		var z = [14, 48, 82][index / 16]
		army[index].issue_manual_order(
			moving.new(Vector3(36 - (row / 4) * 2.5, 0, z - 3 + (row % 4) * 2))
		)
	await _frames(2300)
	for unit in army:
		if unit.position.x >= 40:
			print(
				"Desert retreat stalled: ",
				unit.position,
				" order ",
				unit.manual_orders.current,
				" pending ",
				unit.manual_orders.pending,
				" action ",
				unit.action,
				" active ",
				unit.get_node("Movement")._has_destination,
				" target ",
				unit.get_node("Movement").target_position,
				" path ",
				unit.get_node("Movement").get_current_navigation_path(),
				" index ",
				unit.get_node("Movement").get_current_navigation_path_index(),
				" velocity ",
				unit.get_node("Movement").velocity
			)
	_check(army.all(func(unit): return unit.position.x < 40), "Desert retreat route stranded tanks")
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(ground)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(54, 0, 31), 2.0, [], nav)
			== placement.NOT_NAVIGABLE
		),
		"Build placement accepted sandstone shelf"
	)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(64, 0, 48), 2.0, [], nav)
			== placement.VALID
		),
		"Central staging ground cannot support expansion"
	)
	print(
		(
			"%s: %s three 16-tank approaches/retreats, moving archive, staging/shelf placement"
			% ["PASS" if errors.size() == failures_before else "FAIL", human.faction]
		)
	)
	return true


func _frontier_economy(faction):
	await _skirmish(faction, FRONTIER, false)
	var human = game._get_human_player()
	_enemy().set_process(false)
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	# Authored salvage caches (MapLandmarks) sit outside the paired fields.
	var piles = get_nodes_in_group("resource_units").filter(
		func(unit): return not unit.has_meta("salvage_cache")
	)
	var totals = []
	for kind in ["resource_a", "resource_b"]:
		var total = 0
		for deposit in piles:
			if kind in deposit:
				total += deposit.get(kind)
		totals.append(total)
	# Two home fields of 5 x 400 M / 2 x 720 E and two expansions of 5 x 600 M / 2 x 1,200 E.
	_check(totals == [10000, 7680], "Paired field amounts changed")
	var balances = []
	for side in [human, _enemy()]:
		var workers = _units(side, "Worker")
		_check(workers.size() == 4 and _units(side, "Tank").is_empty(), "Incorrect Standard army")
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
		var side = [human, _enemy()][index]
		_check(
			side.resource_a > balances[index].x and side.resource_b > balances[index].y,
			"A starting side cannot return home resources"
		)
	# Isolate outer electronics income so a working home harvester cannot mask a stuck expansion.
	for side in [human, _enemy()]:
		for worker in _units(side, "Worker"):
			worker.issue_manual_order(null)
	var outer_fields = piles.filter(
		func(unit): return "resource_b" in unit and unit.position.z < 10
	)
	var outer = outer_fields[0]
	# Harvesting may move on to the field's neighbouring electronics pile.
	var outer_piles = piles.filter(
		func(unit): return "resource_b" in unit and unit.position.distance_to(outer.position) < 4
	)
	var field_stock = func():
		return outer_piles.reduce(
			func(sum, unit): return sum + (unit.resource_b if is_instance_valid(unit) else 0), 0
		)
	var stock_before = field_stock.call()
	var worker = _units(human, "Worker")[2]
	worker.issue_manual_order(harvest.new(outer))
	var before = human.resource_b
	await _frames(5000)
	_check(
		field_stock.call() < stock_before and human.resource_b > before,
		"Outer electronics cannot be collected and returned"
	)
	print("PASS: %s both home economies, outer electronics return and paired stockpiles" % faction)
	game.queue_free()
	await _frames(5)


func _frontier_capture(title, point, zoom):
	if DisplayServer.get_name() == "headless":
		return
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 150
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _frontier_menu():
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(menu)
	await _frames(5)
	# Keyboard selection exercises the actual map selector regardless of saved preference.
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = menu._map_list.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await _frames(2)
	for code in [KEY_HOME, KEY_ENTER]:
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = code
			event.window_id = menu._map_list.get_popup().get_window_id()
			event.pressed = pressed
			menu._map_list.get_popup().push_input(event, true)
			await _frames(2)
	await _frames(5)
	_check(not menu._map_list.get_popup().visible, "Map choice did not close its popup")
	_check(menu._get_selected_map_path() == FRONTIER, "Menu did not select revised Frontier")
	_check(
		menu._preview.rocks.size() == 4 and menu._preview.deposits.size() == 4,
		"Frontier preview omitted terrain or fields"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/frontier-menu-720p.png")
	menu.queue_free()
	await _frames(3)
