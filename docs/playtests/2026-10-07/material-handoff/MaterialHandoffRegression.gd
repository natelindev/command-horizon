extends "res://tests/headless/ElectronicsHandoffRegression.gd"

var demand = Vector2i.ZERO


func _run():
	policy = load("res://tests/playtest/reference/MaterialHandoffPolicy.gd").new()
	plan = load("res://source/match/SkirmishPlan.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	labor = load("res://source/match/players/skirmish-ai/SkirmishLabor.gd")
	original_policy = "--original-policy" in OS.get_cmdline_user_args()
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _mirror(faction)
		owner = game._get_human_player()
		workers = _units(owner, "Worker")
		await _load_electronics()
		if carrier != null:
			demand = Vector2i(owner.resource_a + 10, owner.resource_b)
			_check(
				policy.update(game, owner, plan.owned_units(owner), []) == 0,
				"Preceding electronics policy unexpectedly corrected the surplus"
			)
			await _material_boundaries()
			await _material_safety()
			await _material_trip(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Material handoff: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _load_electronics():
	var fields = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit
	)
	var hq = _units(owner, "CommandCenter")[0]
	fields.sort_custom(
		func(a, b): return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
	)
	for worker in workers:
		worker.issue_manual_order(harvest.new(fields[0]))
	game.hud._toggle_pause()
	carrier = null
	for frame in 7200:
		await _frames(1)
		var returning = workers.filter(func(worker): return labor.handoff_ready(worker))
		if not returning.is_empty():
			carrier = returning[0]
			break
	game.hud.pause_after_load()
	_check(carrier != null, "No engineer completed real electronics collection")


func _update(protected):
	return (
		0
		if original_policy
		else policy.restore_materials(game, owner, plan.owned_units(owner), protected, demand)
	)


func _material_boundaries():
	var action = carrier.action
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var cargo = Vector2i(carrier.resource_a, carrier.resource_b)
	_check(_update(workers) == 0, "Reverse handoff replaced protected withdrawal")
	carrier.manual_orders.submit(
		orders.point_order("move", carrier.position + Vector3(2, 0, 0)), true
	)
	var queued = carrier.manual_orders.pending.duplicate(true)
	_check(_update([]) == 0, "Reverse handoff replaced manual queue")
	_check(carrier.manual_orders.pending == queued, "Existing queue changed")
	carrier.manual_orders.clear_waiting()
	var planned = demand
	demand = Vector2i(funds.x, funds.y)
	_check(_update([]) == 0, "Reverse handoff changed an already funded plan")
	demand = Vector2i(funds.x + 10, funds.y + 1)
	_check(_update([]) == 0, "Reverse handoff reduced unfunded electronics income")
	demand = planned
	var materials = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	for field in materials:
		field.remove_from_group("resource_units")
	_check(_update([]) == 0, "Reverse handoff queued a missing material field")
	for field in materials:
		field.add_to_group("resource_units")
	# Only one active electronics worker remains: preserve the opening floor.
	for worker in workers:
		if worker != carrier:
			worker.issue_manual_order(harvest.new(materials[0]))
	_check(_update([]) == 0, "Reverse handoff removed the last electronics assignment")
	var electronics = get_nodes_in_group("resource_units").filter(func(unit): return "resource_b" in unit)[0]
	for worker in workers:
		if worker != carrier:
			worker.issue_manual_order(harvest.new(electronics))
	_check(
		(
			carrier.action == action
			and Vector2i(carrier.resource_a, carrier.resource_b) == cargo
			and Vector2i(owner.resource_a, owner.resource_b) == funds
		),
		"Planning changed the loaded return"
	)


func _material_trip(faction):
	var action = carrier.action
	var cargo = carrier.resource_b
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var protected = workers.filter(func(worker): return worker != carrier)
	var issued = _update(protected)
	_check(issued == 1, faction + ": loaded electronics surplus never returned to materials")
	if issued != 1:
		return
	_check(
		carrier.action == action and carrier.resource_b == cargo,
		"Reverse handoff interrupted cargo"
	)
	var target = labor.queued_target(carrier)
	_check(target != null and "resource_a" in target, "Reverse handoff queued wrong resource")
	_check(
		_update(protected) == 0 and carrier.manual_orders.pending.size() == 1,
		"Duplicate reverse handoff"
	)
	_check(
		policy.update(game, owner, plan.owned_units(owner), protected) == 0,
		"Opposing helpers oscillated"
	)
	for worker in protected:
		worker.issue_manual_order(null)
	var clock = game.simulation_time
	await _disk()
	_check(
		carrier.resource_b == cargo and labor.queued_target(carrier) != null,
		"Reload lost reverse handoff"
	)
	_check(
		game.simulation_time == clock and Vector2i(owner.resource_a, owner.resource_b) == funds,
		"Paused reverse handoff advanced"
	)
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		if owner.resource_a >= funds.x + 4:
			break
	game.hud.pause_after_load()
	_check(owner.resource_b == funds.y + cargo, "Reverse handoff lost or duplicated electronics")
	_check(owner.resource_a == funds.x + 4, "Reverse handoff produced no material delivery")
	print(
		"MATERIAL TRIP ",
		faction,
		" materials=",
		owner.resource_a - funds.x,
		" electronics=",
		owner.resource_b - funds.y,
		" seconds=",
		game.simulation_time - clock
	)


func _material_safety():
	var hq = _units(owner, "CommandCenter")[0]
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	var remote = deposits.filter(
		func(unit):
			return (
				unit.position.distance_to(hq.position) > 30
				and policy.routes._safe_route(carrier, unit, [])
			)
	)
	remote.sort_custom(
		func(a, b): return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
	)
	_check(not remote.is_empty(), "No reachable remote materials fixture")
	if remote.is_empty():
		return
	var target = remote[0]
	for deposit in deposits:
		if deposit != target:
			deposit.remove_from_group("resource_units")
	var protected = workers.filter(func(worker): return worker != carrier)
	_check(_update(protected) == 0, "Remote handoff accepted without ground guard")
	var tank_scene = load("res://source/match/units/Tank.tscn")
	var guard = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		guard, Transform3D(Basis(), target.position + Vector3(0, 0, 4)), owner, false
	)
	await _frames(5)
	_check(_update(protected) == 1, "Safe guarded remote materials handoff rejected")
	carrier.manual_orders.clear_waiting()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var raider = tank_scene.instantiate()
	game._setup_and_spawn_unit(
		raider, Transform3D(Basis(), target.position + Vector3(3, 0, 0)), enemy, false
	)
	await _frames(5)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(owner, raider), "Remote danger fixture not observed")
	_check(_update(protected) == 0, "Handoff entered observed danger despite guard")
	raider.queue_free()
	guard.queue_free()
	for deposit in deposits:
		if deposit != target:
			deposit.add_to_group("resource_units")
	await _frames(5)
	game.battlefield.invalidate()
