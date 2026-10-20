extends "res://tests/rendered/PreviewFixture.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(9)
	camera.set_position_safely(Vector3(11, 0, 26))
	await _frames(50)
	var human = _game._get_human_player()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	camera.set_size_safely(16)
	camera.set_position_safely(Vector3(20, 0, 24))
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	for tank in tanks:
		tank.get_node("Selection").select()
	_game.hud._toggle_pause()
	root.get_node("MatchSignals").terrain_targeted.emit(Vector3(21, 0, 26))
	var held_key = InputMap.action_get_events("shift_selecting")[0].duplicate()
	held_key.keycode = held_key.physical_keycode
	held_key.pressed = true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	root.get_node("MatchSignals").terrain_targeted.emit(Vector3(24, 0, 29))
	# Actual Shift + F/left-click input queues an attack-move behind the two moves.
	_game.hud._arm_attack()
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = camera.unproject_position(Vector3(28, 0, 27))
	event.pressed = true
	event.shift_pressed = true
	_game.hud._unhandled_input(event)
	event.pressed = false
	_game.hud._unhandled_input(event)
	held_key = held_key.duplicate()
	held_key.pressed = false
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	for tank in tanks:
		_check(tank.manual_orders.pending.size() == 3, "Shift attack-move replaced queue")
		_check(tank.manual_orders.pending[2].kind == "attack_move", "Wrong queued attack order")
	await _frames(20)
	var menu = _game.find_child("UnitMenus")
	await _capture("orders-paused-720p")
	_check(menu.get_global_rect().position.y >= 0, "Queue panel exceeds 720p height")
	_check(menu.get_global_rect().end.x <= 1280, "Queue panel exceeds 720p width")
	_game.hud._toggle_pause()
	await _frames(90)
	await _capture("orders-active-720p")
	menu._orders_panel._clear.pressed.emit()
	_check(
		tanks.all(func(unit): return unit.manual_orders.pending.is_empty()), "Clear waiting failed"
	)
	_check(
		tanks.all(func(unit): return not unit.manual_orders.current.is_empty()),
		"Clear waiting stopped active order"
	)
	menu._stop_orders()
	await _frames(20)
	_check(
		tanks.all(func(unit): return not unit.manual_orders._engaged),
		"Stop left manual orders running"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	var workers = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Worker"
	)
	var worker = workers[0]
	worker.get_node("Selection").select()
	await _frames(5)
	await _capture("orders-worker-720p")
	_check(menu.get_global_rect().position.y >= 0, "Worker build/queue panel exceeds 720p height")
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: rendered Shift move/attack-move, paused routes, clear/Stop controls; "
				+ "group and worker 720p layout"
			)
		)
	quit(0 if _errors.is_empty() else 1)
