extends "res://tests/headless/SpeechRegression.gd"


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await _setup("bastion")
	_attach_voice()
	voice.set_process(false)
	_reset_speech()
	var signals = root.get_node("MatchSignals")
	var camera = game.get_node("IsometricCamera3D")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	for role in ["ResourceA", "ResourceB"]:
		var deposit = load("res://source/match/units/non-player/%s.tscn" % role).instantiate()
		game.add_child(deposit)
		signals.deselect_all_units.emit()
		deposit.input_event.emit(camera, click, deposit.global_position, Vector3.UP, 0)
		_check(deposit.is_in_group("selected_units"), role + " click failed to select")
		var commands = game.hud.direct_orders
		_check(not commands.has_eligible("move"), role + " exposed a movement command")
		_check(commands.cargo_return_state().orders.is_empty(), role + " exposed cargo return")
		_check(commands.recovery_state().orders.is_empty(), role + " exposed recovery")
		_check(voice.say_unit(deposit, "select") == false, role + " voice request was not rejected")
		signals.unit_order_issued.emit(deposit, "move")
		_check(heard.is_empty() and voice._pending.is_empty(), role + " generated unit speech")
		deposit.queue_free()
		await _frames(3)
	_check(voice.say_unit(null, "select") == false, "Null voice request was not rejected")
	var freed = Node.new()
	freed.free()
	_check(voice.say_unit(freed, "select") == false, "Freed voice request was not rejected")
	var enemy = _units(_sides()[1], "Tank")[0]
	enemy.get_node("Selection").select()
	signals.unit_order_issued.emit(enemy, "move")
	_check(heard.is_empty(), "Enemy selection/order leaked into speech")
	var tank = _units(game._get_human_player(), "Tank")[0]
	tank.get_node("Selection").select()
	_check(voice.current.get("event") == EVENTS.UNIT_HELLO, "Owned selection lost its voice")
	_reset_speech()
	signals.unit_order_issued.emit(tank, "attack_move")
	_check(voice.current.get("stream", "").contains("/Tank/attack_"), "Owned attack reply lost")
	await _clean_match()
	preferences.restore(original)
	print("Resource selection regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
