extends "res://tests/headless/RallyRetargetRegression.gd"

var menus
var _checked = 0


func _run():
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in factions:
		case_label = faction
		await _mirror(faction)
		_bind()
		menus = game.find_child("UnitMenus")
		await _controls_case()
		await _producer_scope()
		await _dispose()
	manager.autosaves_enabled = autosaves
	_check(_checked == factions.size() * 2, "Not every rally control case completed")
	for error in errors:
		push_error(error)
	print("Rally controls: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _controls_case():
	# Selection rebuilds the command deck on the deferred frame.
	await _frames(2)
	menus._refresh_buttons()
	_check(
		menus._stop_button.text == "Clear rally" and menus._stop_button.disabled,
		"Unassigned producer has no disabled Clear rally"
	)
	_check(
		"Rally · At producer" in menus._stop_button.tooltip_text, "Unassigned rally status missing"
	)
	_check(not menus._stop_button.visible, "Unassigned rally shows an unusable Clear rally")
	var field = get_nodes_in_group("resource_units").filter(func(node): return "resource_b" in node)
	field.sort_custom(
		func(a, b): return hq.position.distance_to(a.position) < hq.position.distance_to(b.position)
	)
	current_target = field[0]
	await _target(current_target)
	menus._refresh_buttons()
	_check("Rally · Electronics" in menus._stop_button.tooltip_text, "Resource rally not described")
	_check(not menus._stop_button.disabled, "Assigned rally cannot be cleared")
	_check(menus._stop_button.visible, "Assigned rally hides Clear rally")
	await _review("assigned")
	var worker = _units(owner, "Worker")[0]
	worker.manual_orders.submit(
		load("res://source/match/orders/ManualOrders.gd").target_order("gather", current_target)
	)
	var action = worker.action
	var orders = worker.manual_orders.pending.duplicate(true)
	var job = hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
	_check(job != null, "Rally control could not queue paid engineer")
	if job == null:
		return
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var left = job.time_left
	await _clear()
	_check(
		rally.target_unit == null and rally.position == Vector3.ZERO,
		"Clear rally left resource assignment"
	)
	_check(
		worker.action == action and worker.manual_orders.pending == orders,
		"Clearing producer overrode existing engineer"
	)
	_check(
		hq.production_queue.size() == 1 and job.time_left == left,
		"Clear rally changed paid production"
	)
	_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "Clear rally changed funds")
	await _review("cleared")
	# Resource work is stopped explicitly, independently of the producer control.
	worker.issue_manual_order(null)
	await _point(hq.position + Vector3(6, 0, 5))
	menus._refresh_buttons()
	_check(
		"Rally · Map destination" in menus._stop_button.tooltip_text, "Point rally not described"
	)
	await _clear()
	_check(
		rally.position == Vector3.ZERO and rally.target_unit == null,
		"Clear rally left point destination"
	)
	await _target(worker)
	menus._refresh_buttons()
	var title = load("res://source/match/FactionCatalog.gd").title(owner.faction, "Worker")
	_check(
		("Rally · " + title) in menus._stop_button.tooltip_text, "Friendly rally lost faction name"
	)
	await _clear()
	worker.hp = 0
	await _frames(5)
	_check(
		rally.position == Vector3.ZERO and rally.target_unit == null,
		"Cleared target death changed rally"
	)
	await _cleared_archive()
	await _review("restored")
	var before_workers = _units(owner, "Worker")
	var seconds = game.simulation_time
	game.hud._toggle_pause()
	await _frames(900)
	game.hud.pause_after_load()
	var created = _units(owner, "Worker").filter(func(unit): return unit not in before_workers)
	_check(
		created.size() == 1 and hq.production_queue.size() == 0,
		"Cleared rally cancelled paid production"
	)
	if created.size() == 1:
		_check(
			created[0].action == null and created[0].position.distance_to(hq.position) < 6,
			"Cleared rally still ordered new engineer"
		)
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == funds,
		"Cleared rally caused resource delivery"
	)
	print("RALLY CLEAR PRODUCTION ", case_label, " seconds=", game.simulation_time - seconds)
	await _review("spawned")
	_checked += 1


func _clear():
	menus._stop_button.pressed.emit()
	await _frames(2)
	menus._refresh_buttons()


func _producer_scope():
	# The shared control is available on every completed producer.
	for role in ["Barracks", "VehicleFactory", "AircraftFactory"]:
		var building = load("res://source/match/units/%s.tscn" % role).instantiate()
		game._setup_and_spawn_unit(building, Transform3D(Basis(), Vector3(40, 0, 25)), owner, false)
		root.get_node("MatchSignals").deselect_all_units.emit()
		building.get_node("Selection").select()
		await _frames(2)
		var point = building.get_node("RallyPoint")
		point.position = Vector3(5, 0, 0)
		menus._refresh_buttons()
		_check(
			menus._stop_button.text == "Clear rally" and not menus._stop_button.disabled,
			"Producer lacks Clear rally: " + role
		)
		menus._stop_button.pressed.emit()
		_check(point.position == Vector3.ZERO, "Producer did not clear rally: " + role)
		building.queue_free()
		await _frames(3)
	# Mixed Stop retains its existing scope; it is not a bulk rally-clear command.
	var worker = _units(owner, "Worker")[0]
	rally.position = Vector3(5, 0, 0)
	worker.manual_orders.submit({"kind": "move", "point": worker.position + Vector3(4, 0, 0)})
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in [hq, worker]:
		unit.get_node("Selection").select()
	await _frames(2)
	menus._refresh_buttons()
	_check(menus._stop_button.text == "Stop current orders", "Mixed Stop changed meaning")
	menus._stop_button.pressed.emit()
	_check(
		worker.action == null and worker.manual_orders.pending.is_empty(),
		"Mixed Stop left worker orders"
	)
	_check(rally.position == Vector3(5, 0, 0), "Mixed Stop silently cleared producer rally")
	_checked += 1


func _cleared_archive():
	var data = Snapshot.new().capture(game)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var left = hq.production_queue.get_elements()[0].time_left
	var file = "user://rally-controls-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Cleared rally archive write failed")
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Cleared rally restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	_bind()
	menus = game.find_child("UnitMenus")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(5)
	menus._refresh_buttons()
	_check(
		paused and game.simulation_time == data.simulation_time, "Cleared archive advanced clock"
	)
	_check(
		rally.target_unit == null and rally.position == Vector3.ZERO,
		"Cleared archive restored old rally"
	)
	_check(
		(
			hq.production_queue.get_elements()[0].time_left == left
			and Vector2i(owner.resource_a, owner.resource_b) == funds
		),
		"Cleared archive changed paid production"
	)
	_check(
		menus._stop_button.disabled and "Rally · At producer" in menus._stop_button.tooltip_text,
		"Loaded producer shows stale rally controls"
	)
