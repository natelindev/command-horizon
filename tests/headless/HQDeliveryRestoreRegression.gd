extends "res://tests/headless/HQDeliveryRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest_script = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in factions.IDS:
		for advanced in [false, true]:
			await _roundtrip(faction, advanced)
	for message in _errors:
		push_error(message)
	print("HQ delivery restore: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _roundtrip(faction, advanced):
	var game = await _create_map("battlefields/DesertFrontierMap", faction, advanced)
	var human = game._get_human_player()
	var hq = _unit(human, "CommandCenter")
	var frozen = human.get_children().filter(
		func(unit): return unit.is_in_group("units") and unit.movement_speed > 0
	)
	for unit in frozen:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var worker = load(Catalog.scene_path("Worker")).instantiate()
	game._setup_and_spawn_unit(
		worker, Transform3D(Basis(), hq.position + Vector3(-2, 0, -5)), human, false
	)
	await _frames(45)
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	deposits.sort_custom(
		func(a, b):
			return (
				hq.position.distance_squared_to(a.position)
				< hq.position.distance_squared_to(b.position)
			)
	)
	worker.issue_manual_order(harvest_script.new(deposits[0]))
	var contact = (
		worker.radius
		+ hq.radius
		+ root.get_node("Utils").Match.Unit.Movement.adherence_margin(worker, hq)
	)
	var returning = false
	for frame in 3000:
		await physics_frame
		if worker.resource_a != 4 or worker.action == null or not "_sub_action" in worker.action:
			continue
		var leg = worker.action._sub_action
		if leg == null or not "_target_position" in leg:
			continue
		# Harvest runs ghost through units, so a return leg no longer needs an
		# outside waypoint around settled engineers; any HQ leg must survive.
		returning = (
			leg._target_unit == hq and worker.position.distance_to(hq.position) > contact + 1.0
		)
		if returning:
			break
	var label = "%s %s" % [faction, "advanced" if advanced else "standard"]
	_check(returning, "No HQ return leg for restore: " + label)
	if not returning:
		game.queue_free()
		await _frames(3)
		return
	paused = true
	var point = worker.position
	var waypoint = worker.action._sub_action._target_position
	var balance = human.resource_a
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(game)
	_check(data != null, "Mid-delivery capture failed: " + snapshot.error)
	if data == null:
		paused = false
		game.queue_free()
		await _frames(3)
		return
	var worker_id = snapshot._reference(worker)
	var frozen_ids = frozen.map(func(unit): return snapshot._reference(unit))
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var path = "user://hq-delivery-restore-%d.json" % OS.get_process_id()
	_check(file.write_file(path, data), "Mid-delivery archive write failed: " + file.error)
	var stored = file.read_file(path)
	DirAccess.remove_absolute(path)
	var restorer = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restorer.restore(self, stored)
	_check(loaded.ok, "Mid-delivery archive restore failed: " + loaded.get("error", ""))
	if loaded.ok:
		game = loaded.game
		human = game._get_human_player()
		worker = restorer.entities[worker_id]
		for id in frozen_ids:
			restorer.entities[id].process_mode = Node.PROCESS_MODE_DISABLED
		get_nodes_in_group("players").filter(func(side): return side != human)[0].process_mode = (
			Node.PROCESS_MODE_DISABLED
		)
		_check(
			paused and worker.position.distance_to(point) < .001,
			"Loading advanced a paused delivery: " + label
		)
		_check(
			worker.resource_a == 4 and human.resource_a == balance,
			"Loading lost or granted cargo: " + label
		)
		_check(
			(
				worker.action._sub_action._target_position == waypoint
				# Movement lifts its target onto raised ground; compare on the plane.
				and (
					worker.get_node("Movement").target_position * Vector3(1, 0, 1)
					== waypoint * Vector3(1, 0, 1)
				)
			),
			"Loading discarded the return destination: " + label
		)
		_check(worker.get_node("Movement").ghosted, "Loading lost harvest ghosting: " + label)
		_check(
			worker.action._sub_action._contact_progress == null,
			"Loading retained stale contact observations: " + label
		)
		await _frames(30)
		_check(
			(
				worker.resource_a == 4
				and human.resource_a == balance
				and worker.position.distance_to(point) < .001
			),
			"Paused archive progressed income: " + label
		)
		paused = false
		var maximum_step = 0.0
		for frame in 2700:
			var previous = worker.position
			await physics_frame
			maximum_step = maxf(maximum_step, previous.distance_to(worker.position))
			if human.resource_a >= balance + 4:
				break
		_check(
			human.resource_a == balance + 4 and worker.resource_a == 0,
			"Restored waypoint never delivered preserved cargo: " + label
		)
		_check(
			maximum_step <= worker.movement_speed / Engine.physics_ticks_per_second + .002,
			"Restored delivery bypassed movement speed: " + label
		)
		print(
			"DELIVERY RESTORE ",
			label,
			" waypoint=",
			waypoint,
			" delivered=",
			human.resource_a - balance
		)
	paused = false
	game.queue_free()
	await _frames(3)
