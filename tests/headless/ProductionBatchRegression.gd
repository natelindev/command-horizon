extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		await _batch(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Production batches: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _batch(faction):
	var player = game._get_human_player()
	var factory = _units(player, "VehicleFactory")[0]
	var menus = game.find_child("UnitMenus")
	var factions = load("res://source/match/FactionCatalog.gd")
	var cost = factions.production_cost(player, "Tank")
	var batch = factions.batch_size(faction, "Tank")
	var shift_jobs = floori(5.0 / batch)
	var tank = load("res://source/match/units/Tank.tscn")
	factory.production_queue.cancel_all()
	player.resource_a = 5000
	player.resource_b = 5000
	game.hud.select_units([factory])
	await _frames(6)
	var button = menus._buttons.filter(func(entry): return entry.type == "Tank")[0].button
	_check(button.is_visible_in_tree(), faction + ": production needs another menu")
	var funds = Vector2i(player.resource_a, player.resource_b)
	var price = Vector2i(cost.resource_a, cost.resource_b)
	var clock = game.simulation_time
	await _click(button, true)
	_check(
		factory.production_queue.size() == shift_jobs and shift_jobs * batch <= 5,
		faction + ": Shift-click exceeded the five-unit limit or lost a whole batch"
	)
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds - price * shift_jobs,
		faction + ": batch charged incorrect costs"
	)
	await _click(button, false)
	_check(
		factory.production_queue.size() == shift_jobs + 1,
		faction + ": plain click retained the batch modifier"
	)
	_check(
		paused and game.simulation_time == clock, faction + ": clicking advanced the paused match"
	)
	_check(get_nodes_in_group("selected_units") == [factory], faction + ": batch changed selection")
	# A batch fills only the two available queue slots and pays for those two jobs.
	factory.production_queue.cancel_all()
	var limit = root.get_node("Constants").Match.Units.PRODUCTION_QUEUE_LIMIT
	for index in limit - 2:
		factory.production_queue.produce(tank)
	menus._refresh_buttons()
	funds = Vector2i(player.resource_a, player.resource_b)
	await _click(button, true)
	_check(factory.production_queue.size() == limit, faction + ": batch exceeded queue capacity")
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds - price * 2,
		faction + ": full queue charged for unqueued jobs"
	)
	# Insufficient funds permit a partial batch without charging refused jobs.
	factory.production_queue.cancel_all()
	player.resource_a = cost.resource_a * 2
	player.resource_b = cost.resource_b * 2
	menus._refresh_buttons()
	await _click(button, true)
	_check(factory.production_queue.size() == 2, faction + ": batch ignored available resources")
	_check(
		player.resource_a == 0 and player.resource_b == 0,
		faction + ": partial batch charged wrong costs"
	)
	factory.production_queue.cancel_all()
	player.resource_a = 5000
	player.resource_b = 5000
	var second = load("res://source/match/units/VehicleFactory.tscn").instantiate()
	game._setup_and_spawn_unit(second, Transform3D(Basis(), Vector3(35, 0, 25)), player, false)
	game.hud.select_units([factory, second])
	await _frames(6)
	button = menus._buttons.filter(func(entry): return entry.type == "Tank")[0].button
	await _click(button, true)
	var counts = [factory.production_queue.size(), second.production_queue.size()]
	counts.sort()
	_check(
		counts[0] + counts[1] == shift_jobs and counts[1] - counts[0] <= 1,
		faction + ": selected factories did not share the allowed jobs"
	)
	factory.production_queue.cancel_all()
	second.production_queue.cancel_all()


func _click(control, shift):
	var point = control.get_global_rect().get_center()
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.shift_pressed = shift
		event.pressed = down
		root.push_input(event, true)
		await _frames(3)
