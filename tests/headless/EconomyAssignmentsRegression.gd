extends "res://tests/headless/EconomySupplyRegression.gd"

var assignments
var supply_rules
var orders
var owner
var workers
var carrier
var material
var electronic
var bar
var faction_ids = ["bastion", "helix", "frontier"]


func _run():
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	plan = load("res://source/match/SkirmishPlan.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	assignments = load("res://source/match/EconomyAssignments.gd")
	supply_rules = load("res://source/match/EconomySupply.gd")
	orders = load("res://source/match/orders/ManualOrders.gd")
	for faction in faction_ids:
		await _case(faction)
	manager.autosaves_enabled = autosaves
	for message in errors:
		push_error(message)
	print("Economy assignments: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _case(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	owner = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud.pause_after_load()
	_bind()
	material = _deposit(workers[0], "resource_a")
	electronic = _deposit(workers[0], "resource_b")
	for worker in workers:
		worker.issue_manual_order(harvest.new(material))
	game.hud._toggle_pause()
	carrier = null
	for frame in 7200:
		await _frames(1)
		for worker in workers:
			if (
				is_instance_of(worker.action, harvest)
				and worker.action._state == harvest.State.MOVING_TO_CC
				and worker.resource_a > 0
			):
				carrier = worker
				break
		if carrier != null:
			break
	game.hud.pause_after_load()
	_check(carrier != null, "Assignment fixture never collected real cargo")
	if carrier != null:
		owner.resource_b = 0
		_check(_advice() == "supply_electronics", "Missing stream fixture has no supply advice")
		await _queued_contracts()
		carrier.manual_orders.submit(orders.target_order("gather", electronic), true)
		_check(
			_advice() != "supply_electronics",
			faction + ": queued electronics still reported missing"
		)
		await _controls(faction + "-queued")
		await _delivery(faction)
	paused = false
	game.queue_free()
	await _frames(5)


func _bind():
	workers = _units(owner, "Worker")
	bar = game.find_child("ResourcesBar")
	_check(bar.player == owner, "Fixture selected another player's resource bar")


func _advice():
	return supply_rules.next_step(owner, plan.owned_units(owner)).get("id", "")


func _count(kind):
	return assignments.workers(owner.get_children(), kind).size()


func _queued_contracts():
	var action = carrier.action
	var cargo = carrier.resource_a
	carrier.manual_orders.submit(orders.target_order("gather", electronic), true)
	_check(_count(1) == 3 and _count(2) == 1, "Queued handoff double-counted current field")
	carrier.manual_orders.submit(
		orders.point_order("move", carrier.position + Vector3(2, 0, 0)), true
	)
	_check(_count(2) == 1, "Later manual order hid immediate gathering job")
	carrier.manual_orders.clear_waiting()
	carrier.manual_orders.submit(
		orders.point_order("move", carrier.position + Vector3(2, 0, 0)), true
	)
	carrier.manual_orders.submit(orders.target_order("gather", electronic), true)
	_check(_count(1) == 3 and _count(2) == 0, "Non-immediate gathering job counted as assigned")
	_check(
		_advice() == "supply_electronics",
		"Distant queued gather suppressed missing-income guidance"
	)
	carrier.manual_orders.clear_waiting()
	carrier.manual_orders.submit(
		orders.target_order("gather", _units(owner, "CommandCenter")[0]), true
	)
	_check(_count(1) == 3 and _count(2) == 0, "HQ cargo drop-off counted as a resource field")
	carrier.manual_orders.clear_waiting()
	var alternatives = get_nodes_in_group("resource_units").filter(
		func(unit): return "resource_b" in unit and unit != electronic
	)
	var other = alternatives[-1]
	carrier.manual_orders.submit(orders.target_order("gather", other), true)
	other.queue_free()
	_check(_count(2) == 0, "Dying deposit retained planned assignment")
	await _frames(3)
	_check(_count(2) == 0, "Freed deposit retained planned assignment")
	carrier.manual_orders.clear_waiting()
	_check(
		carrier.action == action and carrier.resource_a == cargo,
		"Read-only accounting interrupted cargo"
	)
	var waiting_worker = workers.filter(func(worker): return worker != carrier)[0]
	var waiting = harvest.new(null)
	waiting.restoring = true
	waiting._kind = 1
	waiting._field_origin = material.global_position_yless
	waiting._state = harvest.State.WAITING
	waiting._waiting_reason = harvest.Wait.DEPLETED
	waiting_worker.issue_manual_order(waiting)
	_check(_count(1) == 3, "Depleted assignment counted as working")
	waiting._waiting_reason = harvest.Wait.SLOT
	_check(_count(1) == 4, "Work-slot wait lost its assignment")
	waiting_worker.issue_manual_order(harvest.new(electronic))
	_check(_count(1) == 3 and _count(2) == 1, "Current electronics assignment missing")
	waiting_worker.manual_orders.submit(orders.target_order("gather", material), true)
	_check(
		_count(1) == 4 and _count(2) == 0, "Queued materials did not replace electronics assignment"
	)
	_check(
		_advice() == "supply_electronics", "Departing electronics engineer masked a missing stream"
	)
	waiting_worker.issue_manual_order(harvest.new(material))


func _controls(label):
	_check("_assignment_buttons" in bar, "Resource bar omits assigned-engineer controls")
	if not "_assignment_buttons" in bar:
		return
	bar._refresh()
	for kind in [1, 2]:
		var expected = assignments.workers(owner.get_children(), kind)
		var button = bar._assignment_buttons[kind]
		_check(
			button.text.begins_with(str(expected.size()) + " engineer"),
			"Displayed allocation differs from orders"
		)
		_check(button.disabled == expected.is_empty(), "Empty allocation shortcut remains active")
		if expected.is_empty():
			continue
		var previous = workers.map(
			func(worker):
				return [
					worker.action,
					worker.manual_orders.pending.duplicate(true),
					worker.resource_a,
					worker.resource_b
				]
		)
		var clock = game.simulation_time
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		await _activate(kind, button)
		var selected = get_nodes_in_group("selected_units")
		_check(
			(
				selected.size() == expected.size()
				and expected.all(func(worker): return worker in selected)
			),
			"Allocation shortcut selected the wrong engineers"
		)
		for index in workers.size():
			var worker = workers[index]
			_check(
				(
					previous[index]
					== [
						worker.action,
						worker.manual_orders.pending,
						worker.resource_a,
						worker.resource_b
					]
				),
				"Allocation selection changed orders or cargo"
			)
		_check(
			game.simulation_time == clock and funds == Vector2i(owner.resource_a, owner.resource_b),
			"Paused allocation selection advanced economy"
		)
		await _review_assignments(label + "-" + str(kind))
	# Empty and foreign bars cannot replace an owned selection.
	var selected = get_nodes_in_group("selected_units").duplicate()
	var enemy_bar = game.find_child("ResourcesBar2")
	enemy_bar._select_assignments(1)
	_check(
		get_nodes_in_group("selected_units") == selected,
		"Foreign resource bar selected enemy engineers"
	)
	game.hud._overlay = Control.new()
	var overlay = game.hud._overlay
	bar._select_assignments(1)
	_check(
		get_nodes_in_group("selected_units") == selected,
		"Resource shortcut bypassed modal ownership"
	)
	game.hud._overlay = null
	overlay.free()


func _activate(kind, _button):
	bar._select_assignments(kind)
	await _frames(2)


func _review_assignments(_label):
	pass


func _delivery(faction):
	for worker in workers:
		if worker != carrier:
			worker.issue_manual_order(null)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var cargo = carrier.resource_a
	var clock = game.simulation_time
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(carrier)
	var path = "user://economy-assignments-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(path, data), "Assignment archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Assignment archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	owner = game._get_human_player()
	carrier = restore.entities[id]
	_bind()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(5)
	_check(
		game.simulation_time == clock and carrier.resource_a == cargo,
		"Paused restore changed queued cargo"
	)
	_check(
		_count(1) == 0 and _count(2) == 1 and _advice() != "supply_electronics",
		"Reloaded allocation counts or guidance ignored the queued job"
	)
	await _controls(faction + "-restored")
	var factory = _units(owner, "VehicleFactory")[0]
	factory.production_queue.fit_chips = true
	var price = factions.cost(owner, "Tank").duplicate()
	price.resource_b += factions.chip_cost(faction)
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		if owner.resource_b >= price.resource_b:
			break
	game.hud.pause_after_load()
	_check(
		owner.resource_a == funds.x + cargo, "Queued gathering lost or duplicated original cargo"
	)
	_check(
		owner.resource_b >= price.resource_b,
		"Queued gathering produced no usable electronics income"
	)
	_check(_count(2) == 1, "Completed handoff disappeared from assignment count")
	var before = Vector2i(owner.resource_a, owner.resource_b)
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null, "Queued gathering income could not pay for fitted armor")
	if job != null:
		_check(
			(
				Vector2i(owner.resource_a, owner.resource_b)
				== before - Vector2i(price.resource_a, price.resource_b)
			),
			"Fitted armor payment changed"
		)
		var count = _units(owner, "Tank").size()
		game.hud._toggle_pause()
		await _frames(1800)
		game.hud.pause_after_load()
		_check(
			(
				_units(owner, "Tank").size() == count + 1
				and _units(owner, "Tank")[-1].program.installed
			),
			"Paid fitted reinforcement did not finish"
		)
	print(
		"ASSIGNMENT DELIVERY ",
		faction,
		" original_cargo=",
		cargo,
		" electronics=",
		before.y - funds.y,
		" elapsed=",
		game.simulation_time - clock
	)
	carrier.hp = 0
	await _frames(3)
	_check(_count(2) == 0, "Dead engineer remained assigned")
	if "_assignment_buttons" in bar:
		root.get_node("MatchSignals").deselect_all_units.emit()
		var tank = _units(owner, "Tank")[0]
		tank.get_node("Selection").select()
		bar._select_assignments(2)
		_check(
			get_nodes_in_group("selected_units") == [tank],
			"Empty allocation shortcut replaced selection"
		)
		bar._refresh()
		_check(
			bar._assignment_buttons[2].disabled, "Dead engineer left allocation shortcut enabled"
		)
