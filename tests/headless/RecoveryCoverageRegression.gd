extends "res://tests/headless/RecoveryOrdersRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _coverage(faction)
	for error in errors:
		push_error(error)
	print("Recovery coverage: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _coverage(faction):
	await _recovery_fixture(faction)
	var tank = _units(owner, "Tank")[0]
	var robot = _units(owner, "RepairRobot")[0]
	var drone = _spawn_role(owner, "Drone", Vector3(30, 0, 24))
	var healthy = _units(owner, "Infantry")[1]
	var wounded = [patient, tank, robot, drone]
	for unit in wounded:
		unit.hp = unit.hp_max * .3
	healthy.hp = healthy.hp_max
	drone.manual_orders.submit(commands.Orders.point_order("move", Vector3(32, 0, 24)))
	healthy.manual_orders.submit(commands.Orders.point_order("move", healthy.position))
	var drone_orders = drone.manual_orders.pending.duplicate(true)
	var healthy_orders = healthy.manual_orders.pending.duplicate(true)
	await _select_units(wounded + [healthy])
	var menus = game.find_child("UnitMenus")
	menus._refresh_buttons()
	var state = commands.recovery_state()
	var factions = load("res://source/match/FactionCatalog.gd")
	var flight_title = factions.title(faction, "AircraftFactory")
	_check(
		"3/4" in menus._recover_health.text, faction + ": partial support is invisible on button"
	)
	_check(
		flight_title + ": 1 unit" in state.description,
		faction + ": missing flight facility unnamed"
	)
	_check(
		"keep their orders" in state.description, faction + ": omitted units' authority unexplained"
	)
	_check(state.orders.size() == 3 and state.unavailable == 1, "Wrong supported cohort")
	await _review_coverage(faction + "-partial", menus)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var clock = game.simulation_time
	await _activate_coverage(faction, menus._recover_health)
	_check(drone.manual_orders.pending == drone_orders, "Unsupported scout lost its orders")
	_check(healthy.manual_orders.pending == healthy_orders, "Healthy member lost its orders")
	for unit in [patient, tank, robot]:
		_check(
			unit.manual_orders.pending[0].kind == "recover", "Supported unit lacks recovery order"
		)
	_check(Vector2i(owner.resource_a, owner.resource_b) == funds, "Recovery spent funds")
	_check(game.simulation_time == clock, "Paused recovery advanced time")
	var depot = _units(owner, "RepairDepot")[0]
	depot._construction_progress = .5
	menus._refresh_buttons()
	state = commands.recovery_state()
	_check("1/4" in menus._recover_health.text, "Unfinished depot still counted as support")
	_check(
		factions.title(faction, "RepairDepot") + ": 2 units" in state.description,
		"Missing ground count"
	)
	await _review_coverage(faction + "-missing-ground", menus)
	service._construction_progress = .5
	menus._refresh_buttons()
	_check(
		menus._recover_health.disabled and "0/4" in menus._recover_health.text,
		"No-service state unclear"
	)
	await _review_coverage(faction + "-unsupported", menus)
	depot._construction_progress = 1.0
	service._construction_progress = 1.0
	_spawn_role(owner, "AircraftFactory", Vector3(32, 0, 30))
	menus._refresh_buttons()
	_check(menus._recover_health.text == "Recover health", "Full support kept partial label")
	_check(commands.recovery_state().unavailable == 0, "Completed flight facility not recognized")
	await _review_coverage(faction + "-supported", menus)
	for unit in wounded:
		unit.hp = unit.hp_max
	menus._refresh_buttons()
	_check(menus._recover_health.disabled, "Healthy group can recover")
	_check("full health" in menus._recover_health.tooltip_text, "Healthy explanation missing")
	paused = false
	game.queue_free()
	await _frames(5)


func _activate_coverage(_faction, button):
	button.pressed.emit()
	await _frames(5)


func _review_coverage(_label, _menus):
	pass
