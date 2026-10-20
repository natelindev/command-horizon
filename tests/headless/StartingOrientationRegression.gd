extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		for advanced in [false, true]:
			await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", advanced)
			_check_starting_fronts()
			await _production_exits()
			await _archive_orientation()
			await _close_orientation()
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	for mission in catalog.operations():
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.mission_id = mission
		settings.map_path = catalog.operations()[mission].map
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = "bastion" if index == 0 else "helix"
			settings.players.append(side)
		game = load(catalog.operations()[mission].scene).instantiate()
		game.settings = settings
		game.map = load(settings.map_path).instantiate()
		game.progress_path = "user://orientation-campaign-%d.json" % OS.get_process_id()
		root.add_child(game)
		current_scene = game
		await _frames(45)
		_check_starting_fronts()
		print("STARTING FRONTS mission=", mission)
		await _close_orientation()
	for message in errors:
		push_error(message)
	print("Starting orientation: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check_starting_fronts():
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		# Runways are oriented per site for room and approach, not toward the camera.
		if not unit.has_method("is_constructed") or unit.is_in_group("footprinted_structures"):
			continue
		var front = -unit.global_basis.z
		_check(front.dot(Vector3.BACK) > .999, "Starting structure faces away from the bottom")
		var center = camera.unproject_position(unit.global_position)
		var facing = camera.unproject_position(unit.global_position + front)
		_check(facing.y > center.y, "Starting front projects toward the top of the screen")
		if unit.production_queue != null:
			var activity = unit.get_node("StructureActivity")
			var portal = unit.to_global(activity.portal)
			_check(
				portal.z > unit.global_position.z,
				"Starting portal did not rotate with its building"
			)


func _production_exits():
	# Clear the idle starting troops from production approaches, then use the
	# actual queues and paid durations. Other starting structures stay in place.
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.position = Vector3(60 + unit.get_index() % 10, 0, 80)
	await _frames(30)
	for side in get_nodes_in_group("players"):
		for pair in [
			["CommandCenter", "Worker"], ["Barracks", "Infantry"], ["VehicleFactory", "Tank"]
		]:
			var producers = _units(side, pair[0])
			if producers.is_empty():
				continue
			var producer = producers[0]
			var queue = producer.production_queue
			var job = queue.produce(load("res://source/match/units/%s.tscn" % pair[1]))
			_check(job != null, "Starting producer could not purchase " + pair[1])
			if job == null:
				continue
			var before = _units(side, pair[1]).size()
			for tick in 120:
				queue._process(1.0)
				if queue.size() == 0:
					break
			_check(queue.size() == 0, "Bottom-facing starting exit is blocked: " + pair[0])
			var produced = _units(side, pair[1])
			_check(produced.size() == before + 1, "Starting exit lost paid output")
			if produced.size() == before + 1:
				_check(
					produced[-1].position.z > producer.position.z,
					"Production emerged toward the top"
				)
				produced[-1].queue_free()
			await _frames(3)


func _archive_orientation():
	# Loading an archive must preserve its orientation, including old upward
	# layouts and a player's later placement, rather than applying start defaults.
	var hq = _units(game._get_human_player(), "CommandCenter")[0]
	hq.rotation.y = .35
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Orientation archive capture failed")
	if data == null:
		return
	var id = snapshot._reference(hq)
	var restore = Restore.new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Orientation restore failed")
	if result.ok:
		game = result.game
		_check(
			is_equal_approx(restore.entities[id].rotation.y, .35),
			"Load overwrote saved orientation"
		)
		_check(paused, "Orientation restore did not stay paused")


func _close_orientation():
	paused = false
	game.queue_free()
	await _frames(5)
