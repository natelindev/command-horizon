extends "res://tests/headless/SaveRestoreEdges.gd"

const CONTACT_ARCHIVE = "res://tests/fixtures/contact-approach.json"
var contact_deadline = 0
var contact_phase = "approach"
var harvest_action


func _initialize():
	contact_deadline = Time.get_ticks_msec() + 240000
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
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
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


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
	var collected = -1.0
	var clearance = INF
	var gaps = {}
	var deepened = 0
	var started = game.simulation_time
	_check(cargo == 3, "Captured engineer cargo changed")
	paused = false
	for frame in 480:
		await physics_frame
		maximum_step = maxf(
			maximum_step, ((worker.position - previous) * Vector3(1, 0, 1)).length()
		)
		var movement = worker.get_node("Movement")
		if movement._hovering:
			_check(
				absf(worker.position.y - movement._hover_height(worker.position)) < .01,
				"Hover contact recovery left the authored surface height"
			)
		previous = worker.position
		# A harvest run ghosts through units. Once solid again (here: no HQ to
		# return to), a leftover overlap may only shrink; it must never deepen.
		var ghosted = worker.get_node("Movement").ghosted
		for other in get_nodes_in_group("units"):
			if (
				other != worker
				and other.movement_speed > 0
				and other.movement_domain == worker.movement_domain
			):
				var gap = (
					worker.global_position_yless.distance_to(other.global_position_yless)
					- worker.radius
					- other.radius
				)
				if not ghosted and gap < -0.08 and gap < gaps.get(other, INF) - 0.001:
					deepened += 1
				gaps[other] = gap
				if not ghosted:
					clearance = minf(clearance, gap)
		excursion = maxf(excursion, worker.position.distance_to(start))
		if worker.resource_a > cargo and collected < 0:
			collected = game.simulation_time - started
			_check(
				root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, deposit),
				"Collected outside contact range"
			)
	# The captured settled row used to force a 4 m detour and ~10 s of searching.
	# Harvest runs pass through it and start loading almost at once.
	_check(
		collected >= 0 and collected <= 3.0,
		"Captured engineer was held up by settled units for over three seconds"
	)
	_check(
		collected >= 0 and worker.resource_a == 4, "Captured engineer never completed its real work"
	)
	_check(
		stock - deposit.resource_a == worker.resource_a - cargo,
		"Contact recovery lost finite resource stock"
	)
	_check(
		maximum_step <= worker.movement_speed / Engine.physics_ticks_per_second + 0.002,
		"Contact recovery teleported the engineer"
	)
	_check(deepened == 0, "Solid engineer pushed deeper into another unit's footprint")
	print(
		"CAPTURED CONTACT ",
		repetition,
		" excursion=",
		excursion,
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
	var worker = restore.entities["unit-0"]
	for frame in 240:
		if _contact_phase_matches(worker):
			return worker
		await physics_frame
	_check(false, "Captured contact did not reach its %s phase" % contact_phase)
	game.queue_free()
	await _frames(5)
	return null


func _contact_phase_matches(worker):
	var action = worker.action
	if action == null or action.get_script() != harvest_action:
		return false
	var child = action._sub_action
	match contact_phase:
		"approach":
			return (
				action._state == harvest_action.State.MOVING_TO_RESOURCE
				and worker.resource_a == 3
				and is_instance_valid(child)
				and child.get_script().resource_path.ends_with("MovingToUnit.gd")
			)
		"loading":
			# Sample a running timer after part of the cycle has elapsed.
			return (
				action._state == harvest_action.State.COLLECTING
				and worker.resource_a == 3
				and is_instance_valid(child)
				and child.get_script().resource_path.ends_with("CollectingResourcesWhileInRange.gd")
				and is_instance_valid(child._timer)
				and child._timer.time_left > 0
				and child._timer.time_left < child._timer.wait_time * 0.75
			)
		"waiting":
			return (
				action._state == harvest_action.State.WAITING
				and action._waiting_reason == harvest_action.Wait.HQ
				and worker.resource_a == 4
				and child == null
			)
	return false


func _detour_archive():
	var worker = await _load_detour()
	if worker == null:
		return
	paused = true
	var position = worker.position
	var cargo = worker.resource_a
	var ghosted = contact_phase != "waiting"
	_check(_contact_phase_matches(worker), "Archive missed its %s phase" % contact_phase)
	_check(worker.get_node("Movement").ghosted == ghosted, "Contact phase has wrong ghosting")
	var snapshotter = Snapshot.new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Contact phase capture failed: " + snapshotter.error)
	if snapshot == null:
		game.queue_free()
		await _frames(5)
		return
	var id = snapshotter._reference(worker)
	var action_record = snapshotter._action(worker.action)
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
	var restored_snapshotter = Snapshot.new()
	var restored_snapshot = restored_snapshotter.capture(game)
	_check(restored_snapshot != null, "Restored contact phase could not be captured")
	_check(
		restored_snapshotter._action(worker.action) == action_record,
		"Contact action state, destination, timers or references changed in archive"
	)
	_check(_contact_phase_matches(worker), "Restored archive changed contact phase")
	_check(
		worker.get_node("Movement").ghosted == ghosted,
		"Restored contact phase changed its ghosting"
	)
	paused = false
	await _frames(600)
	_check(worker.resource_a == 4, "Restored detour did not complete harvesting")
	print(
		(
			"CHECKED: %s disk archive preserves paused position, cargo and full action; real work resumes"
			% contact_phase
		)
	)
	game.queue_free()
	await _frames(5)


func _manual_replacement():
	var worker = await _load_detour()
	if worker == null:
		return
	var start = worker.position
	var cargo = worker.resource_a
	var goal = start + Vector3(4, 0, 0)
	worker.manual_orders.submit({"kind": "move", "point": goal})
	await _frames(300)
	_check(worker.position.distance_to(goal) < 0.4, "Detour overrode replacement move")
	_check(worker.resource_a == cargo, "Cancelled detour kept collecting")
	_check(not worker.get_node("Movement").ghosted, "Manual move kept harvest ghosting")
	print("CHECKED: manual replacement during %s retains cargo" % contact_phase)
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
		# A full Flux Skimmer phases home from the field. Use a partial load
		# here to exercise ordinary crowded ground contact for both factions.
		var delivery_load = 3 if faction == "helix" else 4
		if role == "CommandCenter":
			worker.resource_b = delivery_load
			worker.issue_manual_order(harvest_action.new(target))
		else:
			worker.issue_manual_order(
				load("res://source/match/units/actions/Constructing.gd").new(target)
			)
		var first_work = -1.0
		var started = game.simulation_time
		var contact_seen = false
		for frame in 1800:
			await physics_frame
			var at_contact = root.get_node("Utils").Match.Unit.Movement.units_adhere(worker, target)
			contact_seen = contact_seen or at_contact
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
					contact_seen if faction == "helix" and role == "PowerPlant" else at_contact,
					(
						"%s %s work started beyond contact range: worker=%s target=%s"
						% [faction, role, worker.global_position, target.global_position]
					)
				)
		_check(first_work >= 0, "%s %s never reached building contact" % [faction, role])
		if role == "CommandCenter":
			_check(
				worker.resource_b == 0 and human.resource_b == before + delivery_load,
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
		"CHECKED: ",
		human.faction,
		" occupied work faces retain destination; removed target cancels"
	)


func _contact_actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
