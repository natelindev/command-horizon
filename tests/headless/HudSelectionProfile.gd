extends "res://tests/headless/MechanicsRegression.gd"

var _cpu


## CPU-only diagnosis of normal HUD refresh paths; not an end-to-end frame gate.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_cpu = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _cpu == null or _cpu.cpu_sample()[0] != 1:
		push_error("HUD CPU diagnostic requires available native caller-thread CPU clocks")
		await root.get_node("Globals").quit_game(1)
		return
	await _open("bastion")
	var units = []
	for index in 200:
		var unit = _spawn("Tank", _human, Vector3(8 + index % 20 * 3.0, 0, 8 + index / 20 * 3.0))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		units.append(unit)
	_game.hud.select_units(units)
	await _frames(5)
	_check(
		get_nodes_in_group("selected_units").size() == 200,
		"HUD profile lost its 200-body selection"
	)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			units.all(func(unit): return unit._native_state != null),
			"HUD profile skipped native state"
		)
	var menus = _game.find_child("UnitMenus")
	var direct = _game.hud.direct_orders
	var tray = _game.hud.ability_tray
	for wounded in [0, 100, 200]:
		for index in units.size():
			units[index].hp = units[index].hp_max * (.2 if index < wounded else 1.0)
		for coordinated in [false, true]:
			_human.coordination_unlocked = coordinated
			var results = {}
			results.buttons = _measure(menus._refresh_buttons)
			results.recovery = _measure(direct.recovery_state)
			results.health = _measure(menus._refresh_health)
			results.abilities = _measure(tray._refresh.bind(.1))
			results.eligible_move = _measure(direct.eligible.bind("move"))
			if wounded == 0 and coordinated:
				var card = menus._command_card
				results.card_clear = _measure_prepared(
					card._clear_slots, card.update_layout.bind(menus._selection, direct)
				)
				results.card_setup_abilities = _measure_prepared(
					card._setup_abilities, card._clear_slots
				)
				results.card_refresh_abilities = _measure(card._refresh_abilities)
			if wounded == 100 and coordinated:
				results.command_card = _measure(
					menus._command_card.update_layout.bind(menus._selection, direct)
				)
				for member in [
					"_selection_roster",
					"_signature_panel",
					"_weapon_modes",
					"_orders_panel",
					"_behavior_panel"
				]:
					var panel = menus.get(member)
					if is_instance_valid(panel):
						results[member] = _measure(panel.refresh)
			print(
				"HUD SELECTION CPU ",
				JSON.stringify(
					{
						"selected": 200,
						"wounded": wounded,
						"coordination": coordinated,
						"samples": 40,
						"milliseconds": results
					}
				)
			)
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _measure(action: Callable) -> Dictionary:
	return _measure_prepared(action, Callable())


func _measure_prepared(action: Callable, prepare: Callable) -> Dictionary:
	var wall = []
	var thread = []
	var process = []
	for index in 40:
		if prepare.is_valid():
			prepare.call()
		var before = _cpu.cpu_sample()
		var started = Time.get_ticks_usec()
		action.call()
		wall.append((Time.get_ticks_usec() - started) / 1000.0)
		var after = _cpu.cpu_sample()
		process.append((after[1] - before[1]) / 1000.0)
		thread.append((after[2] - before[2]) / 1000.0)
	return {
		"wall": _percentiles(wall), "thread": _percentiles(thread), "process": _percentiles(process)
	}


func _percentiles(values: Array) -> Dictionary:
	values.sort()
	return {"median": values[20], "p95": values[38], "max": values[39]}
