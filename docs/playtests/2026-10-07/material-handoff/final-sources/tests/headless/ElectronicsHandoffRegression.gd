extends "res://tests/headless/HQCountdownRegression.gd"

var policy
var plan
var harvest
var orders
var labor
var owner
var workers
var carrier
var original_policy = false


func _run():
	policy = load("res://tests/playtest/reference/ElectronicsHandoffPolicy.gd").new()
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
		await _load_materials()
		await _boundaries()
		await _safety_targets()
		await _handoff_trip(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Electronics handoff: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _load_materials():
	var fields = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_a" in unit
	)
	var hq = _units(owner, "CommandCenter")[0]
	fields.sort_custom(
		func(a, b): return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
	)
	for index in workers.size():
		workers[index].issue_manual_order(harvest.new(fields[index % 3]))
	game.hud._toggle_pause()
	carrier = null
	for frame in 7200:
		await _frames(1)
		var returning = workers.filter(func(worker): return labor.handoff_ready(worker))
		if not returning.is_empty():
			carrier = returning[0]
			break
	game.hud.pause_after_load()
	_check(carrier != null, "No engineer completed real materials collection")


func _update(protected):
	return 0 if original_policy else policy.update(game, owner, plan.owned_units(owner), protected)


func _boundaries():
	var action = carrier.action
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var cargo = Vector2i(carrier.resource_a, carrier.resource_b)
	_check(_update(workers) == 0, "Handoff replaced protected withdrawal")
	carrier.manual_orders.submit(
		orders.point_order("move", carrier.position + Vector3(2, 0, 0)), true
	)
	var queued = carrier.manual_orders.pending.duplicate(true)
	_check(
		_update(workers.filter(func(worker): return worker != carrier)) == 0,
		"Handoff replaced manual queue"
	)
	_check(carrier.manual_orders.pending == queued, "Existing queue changed")
	carrier.manual_orders.clear_waiting()
	var electronics = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit
	)
	for field in electronics:
		field.remove_from_group("resource_units")
	_check(_update([]) == 0, "No available electronics handoff accepted")
	for field in electronics:
		field.add_to_group("resource_units")
	_check(
		(
			carrier.action == action
			and Vector2i(carrier.resource_a, carrier.resource_b) == cargo
			and Vector2i(owner.resource_a, owner.resource_b) == funds
		),
		"Handoff planning changed current delivery"
	)


func _handoff_trip(faction):
	var action = carrier.action
	var cargo = carrier.resource_a
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var issued = _update(workers.filter(func(worker): return worker != carrier))
	_check(issued == 1, faction + ": busy materials economy never restored electronics")
	if issued != 1:
		return
	_check(
		carrier.action == action and carrier.resource_a == cargo,
		"Queued handoff interrupted loaded return"
	)
	var target = labor.queued_target(carrier)
	_check(target != null and "resource_b" in target, "Handoff queued wrong resource")
	_check(
		(
			_update(workers.filter(func(worker): return worker != carrier)) == 0
			and carrier.manual_orders.pending.size() == 1
		),
		"Handoff duplicated queued route"
	)
	for worker in workers:
		if worker != carrier:
			worker.issue_manual_order(null)
	var clock = game.simulation_time
	await _disk()
	_check(
		carrier.resource_a == cargo and labor.queued_target(carrier) != null,
		"Reload lost delivery or pending electronics route"
	)
	_check(
		game.simulation_time == clock and Vector2i(owner.resource_a, owner.resource_b) == funds,
		"Paused handoff advanced clock or funds"
	)
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		if owner.resource_b >= funds.y + 4:
			break
	game.hud.pause_after_load()
	_check(
		owner.resource_a == funds.x + cargo,
		"Queued transition lost or duplicated material delivery"
	)
	_check(owner.resource_b == funds.y + 4, "Queued electronics route produced no real delivery")
	print(
		"ELECTRONICS TRIP ",
		faction,
		" materials=",
		owner.resource_a - funds.x,
		" electronics=",
		owner.resource_b - funds.y,
		" seconds=",
		game.simulation_time - clock
	)


func _disk():
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(carrier)
	var path = "user://electronics-handoff-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(path, data), "Handoff disk write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Handoff restore failed")
	game = loaded.game
	carrier = restore.entities[id]
	owner = carrier.player
	workers = _units(owner, "Worker")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(10)


func _safety_targets():
	var hq = _units(owner, "CommandCenter")[0]
	var deposits = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit
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
	_check(not remote.is_empty(), "No reachable remote electronics fixture")
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
	_check(_update(protected) == 1, "Safe guarded remote electronics handoff rejected")
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
	var other = protected[0]
	other.issue_manual_order(harvest.new(deposits[0]))
	_check(_update(protected) == 0, "Opening quota requested excess electronics engineer")
	other.issue_manual_order(null)
