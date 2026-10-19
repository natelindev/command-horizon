extends "res://tests/headless/SaveRestoreEdges.gd"

var harvest


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/RedrockDivide.tscn", false)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		await _two_workers(faction)
		game.queue_free()
		await _frames(5)
	await _relay_vision()
	for message in errors:
		push_error(message)
	print("Neutral polish: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _two_workers(faction):
	var deposits = game.map.get_node("Resources").get_children()
	var starts = game.map.get_node("SpawnPoints").get_children()
	for start in range(0, deposits.size(), 7):
		var field = deposits.slice(start, start + 7)
		for index in 7:
			_check(field[index].harvest_origin.is_finite(), "Arc lost field origin")
			for other in range(index + 1, 7):
				_check(
					field[index].position.distance_to(field[other].position) >= 2.99,
					"Arc crowded neighboring resource nodes"
				)
		_check(
			field[5].position.distance_to(field[6].position) < 18,
			"Resource arc is still excessively spread out"
		)
		if start / 7 < starts.size():
			for deposit in field:
				_check(
					absf(deposit.position.distance_to(starts[start / 7].position) - 18) < .01,
					"Opening resources are not equidistant from HQ"
				)
	# Both electronics ends still belong to the same field assignment.
	var candidates = get_nodes_in_group("units").filter(
		func(unit): return unit.type == "Worker" and unit.player == game._get_human_player()
	)
	var probe = candidates[0]
	probe.issue_manual_order(harvest.new(deposits[5]))
	_check(
		probe.action._field_deposits().size() == 2,
		"A resource row endpoint could not address its second electronics node"
	)
	probe.issue_manual_order(null)
	var deposit = deposits[2]
	for other in deposits:
		if other != deposit:
			other.queue_free()
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(10)
	var human = game._get_human_player()
	var headquarters = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandCenter"
	)
	var hq = headquarters[0]
	var direction = (hq.global_position - deposit.global_position).normalized()
	var tangent = Vector3(direction.z, 0, -direction.x)
	var workers = []
	for index in 2:
		var worker = load("res://source/match/units/Worker.tscn").instantiate()
		var point = deposit.global_position + direction * 6 + tangent * (index * 2 - 1)
		game._setup_and_spawn_unit(worker, Transform3D(Basis.IDENTITY, point), human, false)
		workers.append(worker)
	await _frames(30)
	var funds = human.resource_a
	for worker in workers:
		worker.issue_manual_order(harvest.new(deposit))
	var simultaneous = false
	var both_loaded = false
	for frame in 3600:
		await physics_frame
		simultaneous = (
			simultaneous
			or workers.all(func(worker): return worker.action._state == harvest.State.COLLECTING)
		)
		both_loaded = both_loaded or workers.all(func(worker): return worker.resource_a > 0)
		if simultaneous and both_loaded and human.resource_a >= funds + 8:
			break
	_check(
		simultaneous and both_loaded, faction + ": two workers did not mine together from one node"
	)
	_check(human.resource_a >= funds + 8, faction + ": both workers failed to deliver")
	print(
		"TWO WORKERS ",
		faction,
		" simultaneous=",
		simultaneous,
		" both_loaded=",
		both_loaded,
		" delivered=",
		human.resource_a - funds
	)


func _relay_vision():
	await _skirmish("bastion", "res://source/match/maps/ExpandedAlpineRelay.tscn", false)
	var relay = game.map.relays[0]
	_check(relay.sight_range == 27.0, "Relay does not provide expanded surveillance")
	_check(
		game.map.points_of_interest[0].sight_range == 9.0, "Non-relay facility gained relay sight"
	)
	relay.captured_by = game._get_human_player()
	relay._update_presentation()
	_check(relay.is_revealing(), "Owned relay does not reveal terrain")
	game.fog_of_war._physics_process(0)
	var circles = game.fog_of_war._unit_to_circles_mapping.get(relay, [])
	_check(circles.size() == 2, "Relay did not create fog and shroud vision")
	for circle in circles:
		_check(
			circle.radius == 27.0 * game.fog_of_war.texture_units_per_world_unit,
			"Relay reveal radius differs from actual fog radius"
		)
	game.queue_free()
	await _frames(5)
