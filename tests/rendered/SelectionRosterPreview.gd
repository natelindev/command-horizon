extends "res://tests/headless/SelectionRosterRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Selection roster preview timed out")
		quit(1)
	return false


func _run():
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
	for faction in ["bastion", "helix", "frontier"]:
		await _selection_roster(faction)
	saves.autosaves_enabled = autosaves
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered selection roster: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _activate_control(button, keyboard = false):
	var menus = game.find_child("UnitMenus")
	menus._info_scroll.ensure_control_visible(button)
	await _frames(3)
	if keyboard:
		button.grab_focus()
		await _frames(2)
		for down in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = down
			root.push_input(key, false)
			await _frames(2)
	else:
		var diagnostic = [0]
		button.pressed.connect(func(): diagnostic[0] += 1)
		var point = root.get_final_transform() * button.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, false)

		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.pressed = down
			root.push_input(event, false)
		_check(diagnostic[0] == 1, "Mouse did not activate exactly one roster control")
	await _frames(3)


func _inspect_layout(player, roster, label):
	var menus = game.find_child("UnitMenus")
	menus._scroll.scroll_vertical = 0
	menus._info_scroll.scroll_vertical = 0
	await _frames(5)
	var viewport = root.get_visible_rect()
	var minimap = game.find_child("Minimap", true, false).get_global_rect()
	var deck = menus.get_global_rect()
	_check(absf(deck.position.x - minimap.end.x) < .5, "Bottom console/minimap mismatch: " + label)
	_check(
		absf(deck.position.y - minimap.position.y) < .5,
		"Bottom console top is not aligned with the minimap"
	)
	_check(
		absf(deck.end.x - viewport.end.x) < .5 and absf(deck.end.y - minimap.end.y) < .5,
		"Bottom console does not span the remaining bottom edge"
	)
	_check(viewport.encloses(menus.get_global_rect()), "Selection menu escaped viewport: " + label)
	_check(menus.position.y >= 0, "Selection menu has negative offset")
	_check(
		menus._scroll.get_h_scroll_bar().max_value <= menus._scroll.size.x,
		"Selection roster needs horizontal scrolling: " + label
	)
	for entry in roster._tiles:
		_check(
			menus.get_global_rect().encloses(entry.button.get_global_rect()),
			"Health tile escaped visible selection: " + label
		)
		_check(
			entry.button.size.y >= entry.button.get_child(0).get_combined_minimum_size().y,
			"Health tile contents exceed the button height"
		)
	if label == "full":
		roster._next.grab_focus()
		await _frames(3)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Selection capture resolution changed")
	frame.save_png("res://art/skirmish/selection-roster-%s-%s.png" % [player.faction, label])
	print("SELECTION CAPTURE ", player.faction, " ", label)


func _destroy_target(roster, victim):
	var button = roster._tiles[-1].button
	game.find_child("UnitMenus")._info_scroll.ensure_control_visible(button)
	await _frames(3)
	var point = root.get_final_transform() * button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	_mouse_at(point, true)
	print(
		"DEATH press ",
		button.is_pressed(),
		" hover=",
		root.gui_get_hovered_control(),
		" selected=",
		_own_selected().size()
	)
	await _frames(2)
	victim.hp = 0
	await _frames(5)
	print(
		"DEATH before release point=",
		point,
		" hover=",
		root.gui_get_hovered_control(),
		" selected=",
		_own_selected().size()
	)
	# An unrelated accept key must not transfer ownership of the pending mouse release.
	for down in [true, false]:
		var key = InputEventKey.new()
		key.physical_keycode = KEY_ENTER
		key.keycode = KEY_ENTER
		key.pressed = down
		root.push_input(key, false)
	_mouse_at(point, false)
	print("DEATH after release selected=", _own_selected().size())
	await _frames(3)
	var fresh = game.find_child("SelectionRoster", true, false)
	await _activate_control(fresh._next)
	_check(fresh._page == 1, "Death cancellation swallowed the next deliberate click")
	await _activate_control(fresh._previous)
	_check(fresh._page == 0, "Previous-page mouse control failed")


func _mouse_at(point, down):
	var event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event, false)
