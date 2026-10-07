extends "res://tests/headless/SaveRestoreEdges.gd"

const CONTACT_ARCHIVE = "res://docs/playtests/2026-10-04/ai-coordination-stall.json"
var contact_deadline = 0


func _initialize():
	contact_deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > contact_deadline:
		push_error("Contact approach wall-clock timeout")
		quit(1)
	return false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for repetition in 3:
		await _captured_approach(repetition)
	await _detour_archive()
	await _manual_replacement()
	for faction in ["bastion", "helix"]:
		await _building_contacts(faction)
	for error in errors:
		push_error(error)
	print("Contact approach: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _captured_approach(repetition):
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(CONTACT_ARCHIVE))
	_check(loaded.ok, "Could not restore the captured approach")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var worker = restore.entities["unit-0"]
	var deposit = restore.entities["resource-2"]
	var start = worker.position
	var cargo = worker.resource_a
	var stock = deposit.resource_a
	var maximum_step = 0.0
	var previous = start
	var excursion = 0.0
	var progress_at_four = 0.0
	var collected = -1.0
	var clearance = INF
	var started = game.simulation_time
	_check(cargo == 3, "Captured engineer cargo changed")
	paused = false
	for frame in 480:
		await physics_frame
		maximum_step = maxf(maximum_step, worker.position.distance_to(previous))
		previous = worker.position
		for other in get_nodes_in_group("units"):
			if (
				other != worker
				and other.movement_speed > 0
				and other.movement_domain == worker.movement_domain
			):
				clearance = minf(
					clearance,
					(
						worker.global_position_yless.distance_to(other.global_position_yless)
						- worker.radius
						- other.radius
					)
				)
		excursion = maxf(excursion, worker.position.distance_to(start))
		if frame == 239:
			progress_at_four = excursion
		if worker.resource_a > cargo and collected < 0:
			collected = game.simulation_time - started
			_check(
				root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, deposit),
				"Collected outside contact range"
			)
	_check(
		progress_at_four > 0.3,
		"Captured engineer failed to leave the blocked approach within four seconds"
	)
	_check(
		collected >= 0 and worker.resource_a == 4, "Captured engineer never completed its real work"
	)
	_check(
		stock - deposit.resource_a == worker.resource_a - cargo,
		"Contact recovery lost finite resource stock"
	)
	_check(
		maximum_step <= worker.movement_speed / 60.0 + 0.002,
		"Contact recovery teleported the engineer"
	)
	_check(clearance >= -0.08, "Contact recovery crossed another unit's footprint")
	print(
		"CAPTURED CONTACT ",
		repetition,
		" excursion_at_four=",
		progress_at_four,
		" collected=",
		collected,
		" max_step=",
		maximum_step,
		" clearance=",
		clearance
	)
	game.queue_free()
	await _frames(5)


func _load_detour():
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(CONTACT_ARCHIVE))
	_check(loaded.ok, "Detour fixture failed to restore")
	if not loaded.ok:
		return null
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	paused = false
	await _frames(150)
	return restore.entities["unit-0"]


func _detour_archive():
	var worker = await _load_detour()
	if worker == null:
		return
	paused = true
	var action = worker.action._sub_action
	var destination = action._target_position
	var position = worker.position
	var cargo = worker.resource_a
	_check(
		cargo == 3 and action.get_script().resource_path.ends_with("MovingToUnit.gd"),
		"Archive missed active detour"
	)
	var snapshotter = Snapshot.new()
	var snapshot = snapshotter.capture(game)
	var id = snapshotter._reference(worker)
	var disk = "user://contact-approach-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(disk, snapshot), "Detour disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, FileStore.new().read_file(disk))
	DirAccess.remove_absolute(disk)
	_check(result.ok, "Detour disk restore failed")
	if not result.ok:
		return
	game = result.game
	worker = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(30)
	_check(
		worker.position == position and worker.resource_a == cargo,
		"Paused detour changed position/cargo"
	)
	_check(
		worker.action._sub_action._target_position.is_equal_approx(destination),
		"Detour destination lost in archive"
	)
	paused = false
	await _frames(600)
	_check(worker.resource_a == 4, "Restored detour did not complete harvesting")
	print(
		"PASS: detour disk archive preserves paused position, cargo and destination; real work resumes"
	)
	game.queue_free()
	await _frames(5)


func _manual_replacement():
	var worker = await _load_detour()
	if worker == null:
		return
	var start = worker.position
	var goal = start + Vector3(4, 0, 0)
	worker.manual_orders.submit({"kind": "move", "point": goal})
	await _frames(300)
	_check(worker.position.distance_to(goal) < 0.4, "Detour overrode replacement move")
	_check(worker.resource_a == 3, "Cancelled detour kept collecting")
	print("PASS: manual replacement ends recovery and retains cargo")
	game.queue_free()
	await _frames(5)


func _building_contacts(faction):
	await _skirmish(faction, "res://source/match/maps/BastionDesert.tscn", false)
	var human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(5)
	for role in ["CommandCenter", "PowerPlant"]:
		var target = load("res://source/match/units/%s.tscn" % role).instantiate()
		game._setup_and_spawn_unit(
			target, Transform3D(Basis(), Vector3(32, 0, 25)), human, role == "PowerPlant"
		)
		var worker = _contact_actor("Worker", human, Vector3(32 + target.radius + 1.25, 0, 25))
		var blockers = []
		for sign in [-1, 1]:
			blockers.append(
				_contact_actor(
					"Worker", human, target.position + Vector3(target.radius + 0.95, 0, sign * 1.3)
				)
			)
		await _frames(120)
		var before = human.resource_b
		if role == "CommandCenter":
			worker.resource_b = 4
			worker.issue_manual_order(
				load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(
					target
				)
			)
		else:
			worker.issue_manual_order(
				load("res://source/match/units/actions/Constructing.gd").new(target)
			)
		var first_work = -1.0
		var started = game.simulation_time
		for frame in 1800:
			await physics_frame
			if (
				first_work < 0
				and (
					worker.resource_b == 0
					if role == "CommandCenter"
					else target._construction_progress > 0
				)
			):
				first_work = game.simulation_time - started
				_check(
					root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, target),
					"Building work started beyond contact range"
				)
		_check(first_work >= 0, "%s %s never reached building contact" % [faction, role])
		if role == "CommandCenter":
			_check(
				worker.resource_b == 0 and human.resource_b == before + 4,
				"Crowded delivery lost/duplicated cargo"
			)
		else:
			_check(target.is_constructed(), "Crowded construction failed to complete")
		print("BUILDING CONTACT ", faction, " ", role, " first_work=", first_work)
		worker.queue_free()
		target.queue_free()
		for blocker in blockers:
			blocker.queue_free()
		await _frames(90)
	await _blocked_contact(human)
	game.queue_free()
	await _frames(5)


func _blocked_contact(human):
	var target = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
	target.position = Vector3(32, 0, 25)
	game.map.get_node("Resources").add_child(target)
	var worker = _contact_actor("Worker", human, target.position + Vector3(4, 0, 0))
	for index in 6:
		var radial = Vector3(cos(index * TAU / 6), 0, sin(index * TAU / 6))
		_contact_actor("Worker", human, target.position + radial * 1.65)
	await _frames(120)
	var action = load("res://source/match/units/actions/MovingToUnit.gd").new(target)
	worker.issue_manual_order(action)
	await _frames(1)
	paused = true
	var goal = action._target_position
	var revision = worker.get_node("Movement")._command_revision
	for attempt in 3:
		action._try_open_approach()
	_check(
		action._target_position == goal,
		"Fully occupied contact selected an overlapping destination"
	)
	_check(
		worker.get_node("Movement")._command_revision == revision,
		"Fully occupied contact churned movement commands"
	)
	target.queue_free()
	await _frames(5)
	_check(worker.action == null, "Removed contact target left a dangling action")
	paused = false
	print(
		"PASS: ", human.faction, " occupied work faces retain destination; removed target cancels"
	)


func _contact_actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
