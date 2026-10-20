extends "res://tests/headless/EngineerSafetyPolicyRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	if "--original-policy" not in OS.get_cmdline_user_args():
		safety_policy_path = "res://tests/playtest/reference/EngineerReassignmentPolicy.gd"
	for faction in ["bastion", "helix", "frontier"]:
		await _cargo_fixture(faction)
		await _safety_case(faction)
		await _clear_fixture()
		await _cargo_fixture(faction)
		await _spacing_case(faction)
		await _clear_fixture()
		await _cargo_fixture(faction)
		await _alternative_case(faction)
		await _clear_fixture()
	for error in errors:
		push_error(error)
	print("Engineer reassignment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _clear_fixture():
	paused = false
	game.queue_free()
	await _frames(5)


func _live_neighbors():
	var plan = load("res://tests/UnitQueries.gd")
	for unit in plan.owned_units(owner):
		unit.process_mode = Node.PROCESS_MODE_INHERIT
	return plan.owned_units(owner)


func _spacing_case(faction):
	safety = load(safety_policy_path).new()
	var units = _live_neighbors()
	var hq = _units(owner, "CommandCenter")[0]
	var workers = _units(owner, "Worker").slice(0, 3)
	for index in workers.size():
		workers[index].position = hq.position + Vector3(20, 0, index * 1.5)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var raider = _spawn_role(enemy, "Tank", carrier.position + Vector3(4, 0, 0))
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	game.battlefield.invalidate()
	safety.update(game, owner, units)
	_check(
		safety.states.size() >= 3, faction + ": spacing fixture failed to trigger three retreats"
	)
	for index in workers.size():
		if not safety.protected(workers[index]):
			continue
		var point = safety.states[workers[index].get_instance_id()].safe
		for other in workers.slice(index + 1):
			if safety.protected(other):
				var next = safety.states[other.get_instance_id()].safe
				_check(
					point.distance_to(next) >= workers[index].radius + other.radius + .6,
					faction + ": retreat destinations overlap"
				)
	print("SPACED RETREATS ", faction, " count=", safety.states.size())


func _alternative_case(faction):
	safety = load(safety_policy_path).new()
	var units = _live_neighbors()
	var hq = _units(owner, "CommandCenter")[0]
	var materials = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	materials.sort_custom(
		func(a, b): return a.position.distance_to(hq.position) > b.position.distance_to(hq.position)
	)
	var original = materials[0]
	carrier.position = hq.position + Vector3(20, 0, 0)
	carrier.issue_manual_order(harvest_rules.new(original))
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var raider = _spawn_role(enemy, "Tank", carrier.position + Vector3(4, 0, 0))
	raider.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	game.battlefield.invalidate()
	safety.update(game, owner, units)
	_check(safety.protected(carrier), faction + ": alternative fixture failed to withdraw")
	# Keep the original field visibly contested while allowing a real return
	# home. Friendly observation is explicit; hidden enemy telemetry is unused.
	raider.position = original.position + Vector3(0, 0, 3)
	var scout = _spawn_role(owner, "Drone", original.position + Vector3(0, 0, 6))
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(owner, raider), "Contested field is not observed")
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var stock = materials.reduce(func(total, node): return total + node.resource_a, 0)
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		if frame % 30 == 0:
			safety.update(game, owner, units)
		if not safety.protected(carrier) and owner.resource_a > funds.x + 3:
			break
	game.hud._toggle_pause()
	_check(safety.episodes.size() == 1, "Alternative work retriggered unsafe retreat")
	if safety.episodes.is_empty():
		return
	var episode = safety.episodes[0]
	_check(episode.get("alternative", false), faction + ": unsafe original field kept worker idle")
	_check(episode.get("delivered", false), faction + ": initial cargo not delivered")
	_check(
		(
			owner.resource_a > funds.x + 3
			and materials.reduce(func(total, node): return total + node.resource_a, 0) < stock
		),
		faction + ": alternative field produced no new income"
	)
	_check(owner.resource_b == funds.y + 1, "Alternative task altered cargo electronics")
	print(
		"ALTERNATIVE WORK ", faction, " income=", owner.resource_a - funds.x, " episode=", episode
	)
