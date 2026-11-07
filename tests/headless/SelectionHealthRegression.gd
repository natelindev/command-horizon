extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("helix")
	var units := []
	for index in 100:
		var unit = _spawn("Tank", 0, Vector3(30, 0, 20))
		units.append(unit)
		unit.get_node("Selection").select()
	await _frames(8)
	var menus = _game.find_child("UnitMenus")
	var before_hp: float = menus._health.value
	var before_shields: float = menus._shields.value
	var changes := [0]
	menus._health.value_changed.connect(func(_value): changes[0] += 1)
	for round_index in 3:
		for unit in units:
			unit.hp -= 1.0
			unit.shields -= 1.0
	_check(changes[0] == 0, "Selection summary refreshed inside the same-tick damage burst")
	await _frames(2)
	_check(changes[0] == 1, "A damage burst did not produce one displayed health update")
	_check(is_equal_approx(menus._health.value, before_hp - 300), "Aggregate hull total is stale")
	_check(
		is_equal_approx(menus._shields.value, before_shields - 300),
		"Aggregate shield total is stale"
	)
	var maximum = menus._health.max_value
	units[0].hp_max += 7.0
	menus._refresh_buttons()
	_check(
		is_equal_approx(menus._health.max_value, maximum + 7.0),
		"Maximum-health change did not invalidate the aggregate"
	)
	_check(not menus._health_dirty, "Button refresh left dirty health pending")
	paused = true
	units[0].hp -= 2.0
	await _frames(2)
	_check(is_equal_approx(menus._health.value, before_hp - 302), "Paused health summary is stale")
	root.get_node("MatchSignals").deselect_all_units.emit()
	var replacement = _spawn("Infantry", 0, Vector3(35, 0, 20))
	replacement.get_node("Selection").select()
	units[0].hp -= 1.0
	await _frames(4)
	_check(
		menus._selection == [replacement] and menus._health.value == replacement.hp,
		"Old selection notifications changed the replacement summary"
	)
	paused = false
	await _close()
	for message in _errors:
		push_error(message)
	print("Selection health regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
