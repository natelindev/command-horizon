extends "res://tests/headless/SaveRestoreEdges.gd"

const Keys = preload("res://source/input/KeyBindings.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_bindings()
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	await _subgroups()
	await _rallies()
	await _patrol()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Micro controls: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _bindings():
	var profile = Keys.defaults()
	_check(profile.keys.patrol_order == KEY_P, "Patrol has no default P binding")
	_check(profile.keys.cycle_subgroup == KEY_TAB, "Subgroup has no Tab binding")
	var old = profile.duplicate(true)
	old.version = 2
	_check(Keys.normalize(old) == profile, "Previous development profile did not reset")
	Keys.apply(profile)


func _subgroups():
	var player = game._get_human_player()
	var tanks = _units(player, "Tank").slice(0, 2)
	var workers = _units(player, "Worker").slice(0, 2)
	var all_units = tanks + workers
	_select(all_units)
	await _frames(3)
	var clock = game.simulation_time
	var orders = tanks[0].manual_orders.pending.duplicate(true)
	var seen = []
	for cycle in 3:
		await _key(KEY_TAB)
		var chosen = _selected()
		seen.append(chosen.map(func(unit): return unit.type))
		_check(not chosen.is_empty(), "Tab discarded the selection")
	_check(seen[0].all(func(role): return role == seen[0][0]), "First Tab did not isolate a class")
	_check(seen[1].all(func(role): return role == seen[1][0]), "Second Tab did not isolate a class")
	_check(seen[0][0] != seen[1][0], "Tab stayed on the same class")
	_check(_selected().size() == all_units.size(), "Tab did not return to the full army")
	_check(tanks[0].manual_orders.pending == orders, "Tab changed manual orders")
	_check(paused and game.simulation_time == clock, "Tab advanced tactical pause")
	await _key(KEY_TAB)
	_select([tanks[0]])
	await _key(KEY_TAB)
	_check(_selected() == [tanks[0]], "Ordinary selection restored an obsolete army")
	_select(all_units)
	var edit = LineEdit.new()
	game.hud.add_child(edit)
	edit.grab_focus()
	await _key(KEY_TAB)
	_check(_selected().size() == all_units.size(), "Text-field Tab changed selection")
	edit.queue_free()
	await _frames(2)
	game.hud._open_menu()
	await _key(KEY_TAB)
	_check(_selected().size() == all_units.size(), "Menu Tab changed selection")
	game.hud._close_menu()
	var focus = root.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	# Deleting a member must preserve the rest of the cycle pool.
	await _key(KEY_TAB)
	var groups = game.find_child("UnitGroupSelectionHandler")
	var victim = tanks[1]
	victim.hp = 0
	await _frames(3)
	_check(groups.subgroups._live_pool().size() == 3, "Death discarded the subgroup pool")
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check(_selected().size() == 3, "Cycle did not restore surviving full selection")
	print("PASS Tab classes/full selection, pause, menu/text focus and deaths")


func _rallies():
	var player = game._get_human_player()
	var controller = player.get_node("UnitActionsController")
	var factory = _units(player, "VehicleFactory")[0]
	var rally = factory.get_node("RallyPoint")
	var worker = _units(player, "Worker")[0]
	var leader = _units(player, "Worker")[1]
	var tank = _units(player, "Tank")[0]
	var deposit = get_nodes_in_group("resource_units")[0]
	rally.target_unit = deposit
	controller._on_navigate_unit_to_rally_point(worker, rally)
	_check(
		worker.manual_orders.pending[0].kind == "gather",
		"Resource rally did not dispatch harvester"
	)
	controller._on_navigate_unit_to_rally_point(tank, rally)
	_check(
		tank.manual_orders.pending[0].kind == "move", "Non-harvester resource rally lost movement"
	)
	rally.target_unit = leader
	controller._on_navigate_unit_to_rally_point(worker, rally)
	_check(
		worker.manual_orders.pending[0].kind == "follow",
		"Friendly rally chose a contextual worker task"
	)
	_check(worker.stance == worker.Stance.DEFENSIVE, "Friendly rally did not set defensive escort")
	var fallback = rally.global_position
	leader.hp = 0
	await _frames(3)
	_check(
		rally.target_unit == null and rally.global_position == fallback,
		"Lost leader erased safe fallback"
	)
	controller._on_navigate_unit_to_rally_point(tank, rally)
	_check(tank.manual_orders.pending[0].kind == "move", "Lost target rally failed to move")
	_check(
		tank.manual_orders.pending[0].point == fallback, "Lost target rally moved somewhere else"
	)
	rally.clear_assignment()
	_check(not rally.is_assigned(), "Explicit Clear rally retained the fallback")
	print("PASS gather/follow rallies, incompatible class fallback, target loss and clear")


func _patrol():
	var player = game._get_human_player()
	var tank = _units(player, "Tank")[0]
	var worker = _units(player, "Worker")[0]
	_select([tank, worker])
	await _frames(3)
	await _key(KEY_P)
	var commands = game.hud.direct_orders
	_check(commands.kind == "patrol", "P did not arm patrol")
	_check(commands.commit(Vector3(30, 0, 38), null, false), "Patrol rejected a mixed army")
	_check(worker.manual_orders.pending[0].kind == "patrol", "Unarmed patrol became one-way move")
	var orders = load("res://source/match/orders/ManualOrders.gd")
	tank.manual_orders._start_next()
	worker.manual_orders._start_next()
	_check(
		tank.action.get_script().resource_path.ends_with("Patrolling.gd"),
		"Patrol action did not start"
	)
	var origin = tank.action.origin
	var endpoint = tank.action.endpoint
	tank.action._arrived()
	_check(tank.action.destination == origin, "Patrol did not turn home")
	tank.action._arrived()
	_check(tank.action.destination == endpoint, "Patrol did not repeat outbound leg")
	tank.manual_orders.submit(orders.point_order("move", Vector3(42, 0, 35)), true)
	_check(tank.manual_orders.pending.size() == 1, "Patrol cannot retain a queued follow-up")
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Patrol capture failed: " + builder.error)
	if snapshot == null:
		return
	var id = builder._reference(tank)
	var worker_id = builder._reference(worker)
	var archive = "user://patrol-%d.json" % OS.get_process_id()
	var file = FileStore.new()
	_check(file.write_file(archive, snapshot), "Patrol disk archive failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Patrol restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	tank = restore.entities[id]
	worker = restore.entities[worker_id]
	_check(
		tank.action.origin == origin and tank.action.endpoint == endpoint,
		"Patrol archive lost route"
	)
	_check(
		worker.action.get_script().resource_path.ends_with("Patrolling.gd"),
		"Archive lost unarmed patrol"
	)
	_check(
		tank.manual_orders.current.kind == "patrol" and tank.manual_orders.pending.size() == 1,
		"Archive lost patrol queue"
	)
	tank.manual_orders.skip()
	tank.manual_orders._start_next()
	_check(tank.manual_orders.current.kind == "move", "Skip did not advance past patrol")
	worker.manual_orders.submit(orders.point_order("move", Vector3(40, 0, 40)))
	_check(worker.manual_orders.pending[0].kind == "move", "Manual override did not replace patrol")
	# Exercise actual navigation across multiple legs on a clear corridor.
	tank.position = Vector3(30, 0, 30)
	tank.manual_orders.submit(orders.point_order("patrol", Vector3(30, 0, 36)))
	tank.manual_orders._start_next()
	var turns = 0
	var previous = tank.action.destination
	paused = false
	for frame in 1200:
		await physics_frame
		if not is_instance_valid(tank.action) or not "origin" in tank.action:
			break
		if tank.action.destination != previous:
			turns += 1
			previous = tank.action.destination
		if turns >= 3:
			break
	_check(turns >= 3, "Patrol did not traverse three legs through live navigation")
	paused = true
	print("PASS patrol shortcut, mixed units, loops, disk restore, queue/skip and override")


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()


func _selected():
	return get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)


func _key(code):
	for down in [true, false]:
		var event = Keys.event_for(code)
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)
