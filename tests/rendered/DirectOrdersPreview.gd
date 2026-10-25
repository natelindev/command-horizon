extends "res://tests/headless/DirectOrdersRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Direct commands preview timed out")
		quit(1)
	return false


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	_migration(load("res://source/input/KeyBindings.gd"))
	for faction in ["bastion", "helix"]:
		await _direct_orders(faction)
	await _campaign_commands()
	saves.autosaves_enabled = autosaves
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered direct orders: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_controls(player, tank, target):
	await _select_units([tank])
	var commands = game.hud.direct_orders
	commands.cancel()
	tank.issue_manual_order(null)
	game.get_node("IsometricCamera3D").set_position_safely(Vector3(32, 0, 33))
	game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(target)
	await _frames(8)
	var menus = game.find_child("UnitMenus")
	await _frames(3)
	for button in menus._command_buttons.values():
		_check(
			root.get_visible_rect().encloses(button.get_global_rect()),
			"Direct command escaped viewport"
		)
	var clock = game.simulation_time
	await _click_control(menus._command_buttons.move)
	_check(commands.kind == "move", "Mouse failed to arm Move")
	await _capture(player, "move")
	await _map_click(Vector3(30, 0, 38))
	_check(
		tank.manual_orders.pending.size() == 1 and tank.manual_orders.pending[0].kind == "move",
		"Move map click issued the wrong command"
	)
	_check(tank.is_in_group("selected_units"), "Move click release lost selection")
	await _queue_modifier(true)
	await _key_action("attack_target")
	_check(commands.kind == "attack", "Shift+Attack target shortcut did not arm")
	await _capture(player, "attack")
	await _map_click(target.global_position + Vector3.UP * 0.3)
	_check(
		tank.manual_orders.pending.map(func(order): return order.kind) == ["move", "attack"],
		"Shift+Attack target map click did not append an attack"
	)
	await _queue_modifier(false)
	menus._command_buttons.attack_move.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	_check(commands.kind == "attack_move", "Enter did not activate attack-move button")
	await _map_click(Vector3(30, 0, 38))
	_check(
		tank.manual_orders.pending[0].kind == "attack_move", "Attack-move became ordinary movement"
	)
	var original = root.get_node("Globals").options.capture()
	var keys = original.key_bindings.duplicate(true)
	keys.keys.move_order = KEY_J
	root.get_node("Globals").options.key_bindings = keys
	root.get_node("Globals").options.apply()
	menus._refresh_buttons()
	_check(menus._command_buttons.move.text.contains("[J]"), "Move button ignored remapped key")
	await _key_action("move_order")
	_check(commands.kind == "move", "Remapped Move did not arm")
	keys.keys.toggle_match_menu = KEY_L
	root.get_node("Globals").options.key_bindings = keys
	root.get_node("Globals").options.apply()
	_check(
		game.hud._assignment_hint.text.contains("L / right-click"),
		"Armed cancellation hint ignored remapping"
	)
	await _key_action("toggle_match_menu")
	_check(
		commands.kind.is_empty() and game.hud._overlay == null, "Cancel shortcut opened the menu"
	)
	root.get_node("Globals").options.restore(original)
	menus._refresh_buttons()
	await _key_action("attack_target")
	var before = tank.manual_orders.pending.duplicate(true)
	await _map_click(Vector3(30, 0, 38))
	_check(
		commands.kind == "attack" and tank.manual_orders.pending == before,
		"Empty attack target changed orders or silently became movement"
	)
	await _map_click(Vector3(30, 0, 38), MOUSE_BUTTON_RIGHT)
	_check(
		commands.kind.is_empty() and tank.manual_orders.pending == before,
		"Right-click cancellation leaked a contextual command"
	)
	_check(paused and game.simulation_time == clock, "Rendered command flow advanced pause")
	await _select_units([tank, _units(player, "Worker")[0]])
	await _capture(player, "mixed")
	await _held_command_death(tank, _units(player, "Worker")[0])


func _click_control(button):
	await _frames(3)
	await _click(
		root.get_final_transform() * button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT
	)


func _held_command_death(tank, worker):
	var button = game.find_child("UnitMenus")._command_buttons.move
	await _frames(3)
	var point = root.get_final_transform() * button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	var held = [0]
	button.button_down.connect(func(): held[0] += 1)
	var event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, false)
	_check(held[0] == 1, "Held-command death fixture did not press the button")
	print("COMMAND DEATH button_down=", held[0])
	worker.hp = 0
	await _frames(5)
	event.pressed = false
	root.push_input(event, false)
	await _frames(3)
	_check(
		tank.is_in_group("selected_units") and get_nodes_in_group("selected_units").size() == 1,
		"Held command button death changed the surviving selection"
	)
	_check(game.hud.direct_orders.kind.is_empty(), "A removed command button armed a map order")


func _map_click(point, button = MOUSE_BUTTON_LEFT):
	var screen = game.get_node("IsometricCamera3D").unproject_position(point)
	if game.hud.direct_orders.kind == "attack":
		var hit = game.hud._pick_unit(screen)
		print(
			"TARGET PICK point=",
			point,
			" screen=",
			screen,
			" hit=",
			hit,
			" role=",
			hit.type if hit != null else "none"
		)
	await _click(root.get_final_transform() * screen, button)


func _click(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = down
		event.shift_pressed = Input.is_physical_key_pressed(KEY_SHIFT)
		root.push_input(event, false)
	await _frames(3)


func _key_action(action):
	var event = InputMap.action_get_events(action)[0]
	await _key(event.physical_keycode)


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		event.shift_pressed = Input.is_physical_key_pressed(KEY_SHIFT)
		root.push_input(event, false)
		await _frames(2)


func _capture(player, label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Direct command preview resolution changed")
	frame.save_png("res://art/skirmish/direct-orders-%s-%s.png" % [player.faction, label])
	print("DIRECT COMMAND CAPTURE ", player.faction, " ", label)


func _campaign_commands():
	path = "user://direct-orders-campaign-%d.json" % OS.get_process_id()
	await _make_match()
	game.hud._toggle_pause()
	var player = game._get_human_player()
	var tank = _units(player, "Tank")[0]
	await _select_units([tank])
	game.get_node("IsometricCamera3D").set_position_safely(tank.global_position)
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	await _click_control(menus._command_buttons.move)
	_check(game.hud.direct_orders.kind == "move", "Campaign Move button did not arm")
	var point = tank.global_position + Vector3(0, 0, 3)
	await _map_click(point)
	_check(
		tank.manual_orders.pending.size() == 1 and tank.manual_orders.pending[0].kind == "move",
		"Campaign Move failed"
	)
	await _key_action("attack_move")
	await _map_click(point)
	_check(
		(
			tank.manual_orders.pending.size() == 1
			and tank.manual_orders.pending[0].kind == "attack_move"
		),
		"Campaign attack-move failed"
	)
	await _capture(player, "campaign")
	paused = false
	game.queue_free()
	await _frames(5)
	game = null
	DirAccess.remove_absolute(path)


func _queue_modifier(down):
	var event = InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.pressed = down
	event.shift_pressed = down
	Input.parse_input_event(event)
	await _frames(2)
