extends "res://tests/headless/EngineerReassignmentRegression.gd"

var guarded_path = "res://tests/playtest/reference/GuardedReassignmentPolicy.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	if "--original-policy" in OS.get_cmdline_user_args():
		guarded_path = "res://tests/playtest/reference/EngineerReassignmentPolicy.gd"
	for faction in ["bastion", "helix", "frontier"]:
		await _cargo_fixture(faction)
		await _guarded_case(faction)
		await _clear_fixture()
	for message in errors:
		push_error(message)
	print("Guarded reassignment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _guarded_case(faction):
	var policy = load(guarded_path).new()
	var original = load("res://tests/playtest/reference/EngineerReassignmentPolicy.gd").new()
	var hq = _units(owner, "CommandCenter")[0]
	var choices = get_nodes_in_group("resource_units").filter(
		func(node):
			return (
				"resource_a" in node
				and node.position.distance_to(hq.position) > policy.economy.HOME_RADIUS
			)
	)
	choices.sort_custom(
		func(a, b): return a.position.distance_to(hq.position) < b.position.distance_to(hq.position)
	)
	var remote = choices[0]
	var state = {"target": weakref(remote), "kind": "gather", "record": {}}
	carrier.resource_a = 0
	carrier.resource_b = 0
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var before = carrier.action
	var unguarded = original._resume_target(game, carrier, state, hq, [])
	_check(
		unguarded.ready and unguarded.target == remote,
		"Original policy did not expose the remote reassignment"
	)
	var work = policy._resume_target(game, carrier, state, hq, [])
	_check(
		work.ready and work.target.position.distance_to(hq.position) <= policy.economy.HOME_RADIUS,
		faction + ": unguarded remote task displaced safe home work"
	)
	# A cleared local economy isolates the expansion gate from target scoring.
	for node in get_nodes_in_group("resource_units"):
		if node.position.distance_to(hq.position) <= policy.economy.HOME_RADIUS:
			node.set("resource_a" if "resource_a" in node else "resource_b", 0)
	work = policy._resume_target(game, carrier, state, hq, [])
	_check(not work.ready, faction + ": depleted home economy launched an unguarded worker")
	var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var foreign = _spawn_role(enemy, "Tank", remote.position + Vector3(0, 0, 7))
	foreign.process_mode = Node.PROCESS_MODE_DISABLED
	var air = _spawn_role(owner, "Helicopter", remote.position + Vector3(0, 2, 6))
	air.process_mode = Node.PROCESS_MODE_DISABLED
	_check(
		not policy._resume_target(game, carrier, state, hq, []).ready,
		"Foreign or air unit admitted expansion"
	)
	var guard = _spawn_role(owner, "Tank", remote.position + Vector3(0, 0, 7))
	guard.process_mode = Node.PROCESS_MODE_DISABLED
	guard.hp = guard.hp_max * .49
	_check(
		not policy._resume_target(game, carrier, state, hq, []).ready,
		"Wounded guard admitted expansion"
	)
	guard.hp = guard.hp_max
	guard.position += Vector3(20, 0, 0)
	_check(
		not policy._resume_target(game, carrier, state, hq, []).ready,
		"Distant guard admitted expansion"
	)
	guard.position = remote.position + Vector3(0, 0, 7)
	work = policy._resume_target(game, carrier, state, hq, [foreign])
	_check(not work.ready or work.target != remote, "Guard ignored an observed unsafe resource")
	# Hidden contacts do not enter the observed-contact argument. Guarding
	# authorizes ordinary harvesting, without granting sight or free cargo.
	foreign.queue_free()
	air.queue_free()
	await _frames(3)
	work = policy._resume_target(game, carrier, state, hq, [])
	_check(
		work.ready and work.target == remote, "Arrived healthy ground guard failed to admit work"
	)
	_check(
		carrier.action == before and Vector2i(owner.resource_a, owner.resource_b) == funds,
		"Planning mutated orders or funds"
	)
	var total = _materials_total()
	carrier.manual_orders.submit(policy.orders.target_order("gather", remote))
	game.hud._toggle_pause()
	await _frames(120)
	await _guarded_reload()
	print("TRIP START ", faction, " worker=", carrier.position, " action=", carrier.action, " remote=", remote.position if is_instance_valid(remote) else "restored", " funds=", funds)
	var started = game.simulation_time
	var collected = false
	var delivered = false
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		collected = collected or carrier.resource_a > 0
		if collected and carrier.resource_a == 0 and owner.resource_a >= funds.x + 4:
			delivered = true
			break
	print("TRIP END ", faction, " worker=", carrier.position, " action=", carrier.action, " cargo=", carrier.resource_a, " funds=", owner.resource_a, " collected=", collected)
	_check(
		collected and delivered, faction + ": guarded worker did not collect and deliver real cargo"
	)
	_check(_materials_total() == total, faction + ": guarded trip changed finite material total")
	print(
		"GUARDED WORK ",
		faction,
		" delivered=",
		delivered,
		" seconds=",
		game.simulation_time - started
	)


func _guarded_reload():
	game.hud.pause_after_load()
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var id = builder._reference(carrier)
	var position = carrier.position
	var cargo = carrier.resource_a
	var action = str(carrier.action)
	var file = "user://guarded-worker-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, snapshot), "Guarded trip snapshot could not write")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Guarded trip failed to restore")
	game = loaded.game
	carrier = restore.entities[id]
	owner = carrier.player
	_freeze_other_actors()
	await _frames(20)
	_check(
		paused and game.simulation_time == snapshot.simulation_time, "Guarded reload advanced clock"
	)
	_check(
		(
			carrier.position == position
			and carrier.resource_a == cargo
			and str(carrier.action) == action
		),
		"Guarded reload changed assignment or cargo"
	)


func _materials_total():
	var total = owner.resource_a + carrier.resource_a
	for node in get_nodes_in_group("resource_units"):
		if "resource_a" in node:
			total += node.resource_a
	return total
