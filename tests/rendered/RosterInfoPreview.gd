extends "res://tests/headless/RosterInfoRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Roster preview timed out")
		quit(1)
	return false


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _roster(faction)
	saves.autosaves_enabled = autosaves
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered roster information: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_roster(player, label):
	var menus = game.find_child("UnitMenus")
	await _frames(5)
	if label == "available":
		await _keyboard_purchase(player, menus)
	var role = "PowerPlant" if label == "construction" else "Tank"
	if label in ["available", "missing-lab"]:
		role = "AdvancedTank"
	var button = _entry(menus, role).button
	await _frames(5)
	var before = Vector2i(player.resource_a, player.resource_b)
	var clock = game.simulation_time
	await _hover(button)
	var tooltip = _tooltip(root, button.tooltip_text)
	_check(tooltip != null, "Actual hover did not show roster information: " + label)
	if tooltip != null:
		var rect = tooltip.get_global_rect()
		var window = tooltip.get_window()
		_check(window.get_visible_rect().encloses(rect), "Tooltip escaped its window: " + label)
		if window != root and window.is_embedded():
			_check(
				root.get_visible_rect().encloses(Rect2(window.position, window.size)),
				"Tooltip escaped the game window: " + label
			)
		print("ROSTER TOOLTIP ", label, " ", rect, " window=", window.name, " size=", window.size)
	_check(Vector2i(player.resource_a, player.resource_b) == before, "Hover spent resources")
	_check(game.simulation_time == clock, "Hover advanced paused gameplay")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Roster preview resolution changed")
	frame.save_png("res://art/skirmish/roster-info-%s-%s.png" % [player.faction, label])
	print("ROSTER CAPTURE ", player.faction, " ", label)
	await _move(Vector2(640, 400))
	return true


func _keyboard_purchase(player, menus):
	var factory = _units(player, "VehicleFactory")[0]
	var button = _entry(menus, "Tank").button
	var before = Vector2i(player.resource_a, player.resource_b)
	var cost = _entry(menus, "Tank").cost
	button.grab_focus()
	await _frames(3)
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)
	_check(factory.production_queue.size() == 1, "Enter did not buy exactly one roster choice")
	_check(
		(
			Vector2i(player.resource_a, player.resource_b)
			== before - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Keyboard purchase charged the wrong price"
	)
	await _frames(5)
	var queue_ui = menus._queue
	var refund = queue_ui._queue_elements.get_child(0)
	await _click(refund)
	_check(factory.production_queue.size() == 0, "Mouse refund did not cancel the queued choice")
	_check(Vector2i(player.resource_a, player.resource_b) == before, "Mouse refund changed funds")


func _hover(control):
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	await _move(Vector2(640, 400))
	await _move(point)
	await create_timer(0.9, true).timeout
	if _tooltip(root, control.tooltip_text) == null:
		print(
			"HOVER RETRY point=",
			point,
			" actual=",
			root.get_mouse_position(),
			" focused=",
			root.has_focus()
		)
		await _move(Vector2(640, 400))
		await _move(point)
		await create_timer(0.9, true).timeout


func _move(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await _frames(2)


func _click(control):
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, false)
	await _frames(3)


func _tooltip(node, content):
	if node.get_meta("roster_tooltip", "") == content:
		return node
	for child in node.get_children(true):
		var found = _tooltip(child, content)
		if found != null:
			return found
	return null
