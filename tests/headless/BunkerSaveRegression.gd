extends "res://tests/headless/GameplayDepthSaveRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	_orders = load("res://source/match/orders/ManualOrders.gd")
	_restore = load("res://source/match/saves/MatchRestore.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion", "PlainAndSimple")
	var player = _players[0]
	var bunker = _game.engineering._spawn_emplacement(
		player, "bunker", Vector3(25, 0, 25), 0.0, _game.engineering._allocate_id("bunker")
	)
	var passengers = []
	for index in 6:
		var unit = _spawn("Infantry", 0, bunker.global_position + Vector3(2.4, 0, index * .12))
		unit.process_mode = Node.PROCESS_MODE_INHERIT
		unit.manual_orders.submit(_orders.target_order("garrison", bunker))
		passengers.append(unit)
	await _frames(90)
	_check(bunker.occupants.size() == 6, "Bunker did not admit six infantry")
	for unit in passengers:
		_check(not unit.visible, "Bunker passenger remains visible")
	var objects = {"bunker": bunker}
	for index in passengers.size():
		objects["passenger%d" % index] = passengers[index]
	if await _round_trip(objects):
		bunker = _references.bunker
		_check(bunker.occupants.size() == 6, "Save lost bunker passengers")
		for index in 6:
			var unit = _references["passenger%d" % index]
			_check(
				not unit.visible and unit.get_meta("garrison_host") == bunker,
				"Restored bunker passenger was exposed or detached"
			)
		var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
		var data = snapshotter.capture(_game)
		data.engineering.entities[0].garrison.slots[5] = 6
		var validator = _restore.new()
		_check(not validator.prepare(data), "Save accepted a nonexistent seventh bunker slot")
		for unit in bunker.occupants.duplicate():
			unit.manual_orders.cancel()
			unit.action = null
		await _frames(3)
		_check(bunker.occupants.is_empty(), "Restored bunker did not unload")
		for index in 6:
			_check(
				_references["passenger%d" % index].visible,
				"Unloaded bunker passenger stayed hidden"
			)
	await _close_paused()
	for message in _errors:
		push_error(message)
	print("Bunker save/restore: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
