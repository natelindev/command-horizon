extends "res://tests/headless/LowHealthSelectionRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	await _earned_support()
	for faction in ["bastion", "helix", "frontier"]:
		await _opening_support(faction)
	for error in errors:
		push_error(error)
	print("Support discovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _support_button():
	return game.hud.battle_plan.find_child("SelectRepairSupport", true, false)


func _earned_support():
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(EARNED))
	_check(loaded.ok, "Earned wounded defense failed to restore")
	if not loaded.ok:
		return
	game = loaded.game
	var owner = game._get_human_player()
	game.hud.battle_plan.refresh()
	var button = _support_button()
	_check(button != null and button.visible, "Earned defense hides missing repair support")
	if button != null:
		await _select_support(button, owner, "earned")
	paused = false
	game.queue_free()
	await _frames(5)


func _opening_support(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud.pause_after_load()
	var owner = game._get_human_player()
	for unit in plan_rules.owned_units(owner):
		if unit.type in ["RepairDepot", "RepairRobot", "CommandLab"]:
			unit.queue_free()
	await _frames(5)
	var tank = _units(owner, "Tank")[0]
	tank.hp = tank.hp_max * .3
	var worker = _units(owner, "Worker")[0]
	var deposits = get_nodes_in_group("resource_units").filter(
		func(node): return node.can_harvest(worker)
	)
	worker.issue_manual_order(plan_rules.Harvest.new(deposits[0]))
	var queued_worker = _units(owner, "Worker")[1]
	queued_worker.manual_orders.submit({"kind": "move", "point": Vector3(38, 0, 25)})
	_check(
		plan_rules.next_step(owner).id == "CommandLab",
		"Fixture did not retain programming progression"
	)
	game.hud.battle_plan.refresh()
	var button = _support_button()
	_check(button != null and button.visible, faction + ": opening hides missing repair support")
	if button != null:
		var factions = load("res://source/match/FactionCatalog.gd")
		var title = factions.title(faction, "RepairDepot")
		var cost = factions.cost(owner, "RepairDepot", true)
		_check(title in button.tooltip_text, "Missing faction service name")
		_check(
			"%d M / %d E" % [cost.resource_a, cost.resource_b] in button.text,
			"Missing exact service cost"
		)
		await _select_support(button, owner, faction)
		owner.resource_a = 0
		owner.resource_b = 0
		game.hud.battle_plan.refresh()
		_check(
			"need" in button.text and "Gather" in button.tooltip_text,
			"Unaffordable support lacks funding feedback"
		)
		await _review_support(faction + "-funds")
		var depot = _spawn_for_plan("RepairDepot", owner, Vector3(44, 0, 27))
		depot.mark_as_under_construction()
		game.hud.battle_plan.refresh()
		_check(
			"Finish" in button.text and "already paid" in button.tooltip_text,
			"Paid foundation asks for another purchase"
		)
		await _review_support(faction + "-foundation")
		# Becoming supported between refresh and activation must keep selection/orders.
		depot._construction_progress = 1.0
		var selected = get_nodes_in_group("selected_units").duplicate()
		button.pressed.emit()
		_check(
			get_nodes_in_group("selected_units") == selected,
			"Stale support activation changed selection"
		)
		game.hud.battle_plan.refresh()
		_check(not button.visible, "Completed support leaves a redundant shortcut")
		depot.queue_free()
		await _frames(5)
		var robot = _spawn_for_plan("RepairRobot", owner, Vector3(40, 0, 26))
		game.hud.battle_plan.refresh()
		_check(not button.visible, "Mobile repair support was ignored")
		robot.queue_free()
		for unit in _units(owner, "VehicleFactory"):
			unit.queue_free()
		await _frames(5)
		game.hud.battle_plan.refresh()
		var support = plan_rules.support_step(owner)
		_check(support.id == "fund_VehicleFactory", "Missing prerequisite route")
		_check(
			not button.visible and plan_rules.next_step(owner).id == support.id,
			"Primary prerequisite advice was duplicated"
		)
		await _review_support(faction + "-prerequisite")
		tank.hp = tank.hp_max
		game.hud.battle_plan.refresh()
		_check(not button.visible, "Healthy army retains support advice")
	paused = false
	game.queue_free()
	await _frames(5)


func _select_support(button, owner, label):
	var before = plan_rules.next_step(owner)
	var clock = game.simulation_time
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var units = plan_rules.owned_units(owner)
	var actions = units.map(func(unit): return unit.action)
	var queues = _queue_snapshot(units)
	await _activate_support(button, label)
	var selected = get_nodes_in_group("selected_units")
	_check(
		selected.size() == 1 and selected[0].type == "Worker",
		"Support shortcut did not select an engineer"
	)
	_check(actions == units.map(func(unit): return unit.action), "Support shortcut issued orders")
	_check(queues == _queue_snapshot(units), "Support shortcut replaced queued work")
	_check(funds == Vector2i(owner.resource_a, owner.resource_b), "Support shortcut spent funds")
	_check(game.simulation_time == clock, "Paused support selection advanced the match")
	_check(plan_rules.next_step(owner).id == before.id, "Support shortcut replaced primary advice")


func _activate_support(button, _label):
	button.pressed.emit()
	await _frames(8)


func _review_support(_label):
	pass


func _queue_snapshot(units):
	var result = []
	for unit in units:
		result.append(
			unit.manual_orders.pending.duplicate(true) if unit.manual_orders != null else []
		)
	return result
