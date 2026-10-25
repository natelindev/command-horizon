extends "res://tests/headless/StructureActivityRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		await _repair_activity()
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Repair activity: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _repair_activity():
	var depot = _spawn("RepairDepot", Vector3(45, 0, 35))
	var worker = _spawn("Worker", Vector3(45, 0, 35.25))
	await _frames(30)
	depot.process_mode = Node.PROCESS_MODE_INHERIT
	depot.set_process(false)
	var activity = depot.get_node("StructureActivity")
	var visuals = depot.get_node("BastionVisuals")
	activity.set_process(false)
	visuals.set_process(false)
	worker.global_position = depot.service_point(worker)
	worker.get_node("Movement").stop()
	worker.hp = worker.hp_max * .5
	var original = depot.global_transform
	game.battlefield.invalidate()
	var hp = worker.hp
	game.repair_service.service(.25)
	activity.refresh(.25)
	_check(worker.hp > hp and depot.get_meta("service_used", 0) == 1, "Depot is not repairing")
	_check(activity.state == "repair", "Repair has no activity state")
	_check(not visuals._tools.is_empty(), human.faction + ": repair arms missing")
	_check(visuals._is_working(), "Repair arms do not recognize service")
	visuals._update_work(.25, false)
	visuals._update_parts(.25)
	var poses = visuals._tools.map(func(tool): return tool.rotation)
	var head = activity._work_head.position
	visuals._update_work(.25, false)
	visuals._update_parts(.25)
	activity.refresh(.25)
	_check(visuals._tools.map(func(tool): return tool.rotation) != poses, "Repair arms stay still")
	_check(activity._work_head.position != head, "Repair carriage stays still")
	_check(activity._light_level > 0, "Repair work lights stay dark")
	_check(depot.global_transform == original, "Repair moved the building foundation")
	await _review_repair(depot, worker, activity, visuals)
	activity.set_process(true)
	visuals.set_process(true)
	game.repair_service.set_physics_process(true)
	paused = true
	poses = visuals._tools.map(func(tool): return tool.rotation)
	head = activity._work_head.position
	hp = worker.hp
	await _frames(20)
	_check(worker.hp == hp, "Pause advanced repair")
	_check(visuals._tools.map(func(tool): return tool.rotation) == poses, "Pause moved repair arms")
	_check(activity._work_head.position == head, "Pause moved repair carriage")
	paused = false
	activity.set_process(false)
	visuals.set_process(false)
	game.repair_service.set_physics_process(false)
	for end in ["healed", "left", "disabled"]:
		worker.hp = worker.hp_max * .5
		worker.position = depot.service_point(worker)
		depot.process_mode = Node.PROCESS_MODE_INHERIT
		game.battlefield.invalidate()
		game.repair_service.service(.25)
		if end == "healed":
			worker.hp = worker.hp_max
		elif end == "left":
			worker.position += Vector3(8, 0, 0)
		else:
			depot.process_mode = Node.PROCESS_MODE_DISABLED
		game.battlefield.invalidate()
		game.repair_service.service(.25)
		activity.refresh(1.0)
		visuals._update_work(1.0, false)
		visuals._update_parts(1.0)
		_check(depot.get_meta("service_used", 0) == 0, "Stale service after " + end)
		_check(activity.state == "idle" and activity._light_level == 0, "Lights busy after " + end)
		_check(not visuals._is_working() and visuals._work == 0, "Arms busy after " + end)
	for unit in [worker, depot]:
		unit.queue_free()
	await _frames(5)


func _review_repair(_depot, _worker, _activity, _visuals):
	pass
