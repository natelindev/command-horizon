extends "res://tests/headless/HorizonControlRegression.gd"

var original_options = {}


func _prepare_display():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)


func _restore_display():
	root.get_node("Globals").options.restore(original_options)


func _review(label):
	var was_paused = paused
	if not paused:
		game.hud._toggle_pause()
	root.size = Vector2i(1280, 720)
	game.get_node("IsometricCamera3D").set_position_safely(game.map.DEPLOYMENT)
	await _frames(6)
	var panel = game.hud.objective_panel.get_global_rect()
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Horizon status panel covers minimap"
	)
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel), "Horizon status panel clips")
	for item in [game.hud._zone, game.hud._waves, game.hud._route]:
		_check(panel.encloses(item.get_global_rect()), "Horizon text clips panel")
	if label in ["infantry-needed", "guard-absent"]:
		var hover = InputEventMouseMotion.new()
		hover.position = game.hud._zone.get_global_rect().get_center()
		root.push_input(hover, true)
		await create_timer(1).timeout
		_check(
			_tooltip_visible(root, game.hud._zone.tooltip_text),
			"Deployment tooltip invisible on hover"
		)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Horizon feedback frame dimensions changed")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Horizon capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
	if not was_paused:
		game.hud._toggle_pause()


func _recover():
	returns += 1
	var funds = [game._get_human_player().resource_a, game._get_human_player().resource_b]
	await _activate("Infantry", false)
	_check(actor.is_in_group("selected_units"), "Infantry shortcut failed to select capturer")
	_check(
		(
			paused
			and funds == [game._get_human_player().resource_a, game._get_human_player().resource_b]
		),
		"Selection changed pause/funds"
	)
	await _activate("Deployment", true)
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	var point = game.map.DEPLOYMENT + Vector3(-1.6, .6, 0)
	await _mouse(game.get_node("IsometricCamera3D").unproject_position(point), MOUSE_BUTTON_RIGHT)
	_check(
		not actor.manual_orders.pending.is_empty(), "Paused right-click did not queue capture move"
	)
	print("HORIZON CONTROL right-click ", point)
	await _review("ordered-%d" % returns)


func _activate(title, keyboard):
	var buttons = game.hud.find_children("*", "Button", true, false)
	var button = buttons.filter(func(item): return item.text == title)[0]
	var pressed = [false]
	button.pressed.connect(func(): pressed[0] = true, CONNECT_ONE_SHOT)
	if keyboard:
		button.grab_focus()
		for down in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event, true)
			await _frames(2)
	else:
		await _mouse(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(pressed[0], "Horizon shortcut input failed")
	print("HORIZON CONTROL ", title)


func _mouse(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)
		await _frames(2)


func _tooltip_visible(node, text):
	if (
		node is Label
		and node.text == text
		and node.is_visible_in_tree()
		and node.get_window().visible
	):
		_check(node.get_window().size.x <= root.size.x, "Deployment tooltip exceeds viewport width")
		_check(
			node.get_window().size.y <= root.size.y, "Deployment tooltip exceeds viewport height"
		)
		return true
	for child in node.get_children(true):
		if _tooltip_visible(child, text):
			return true
	return false
