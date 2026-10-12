extends "res://tests/headless/PointOfInterestRegression.gd"

const CAPTURES = "res://tmp/point-of-interest-preview"
var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Point of interest rendered verification timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	# Native fullscreen transitions settle in wall time, including fixed-fps runs.
	var display_ready = Time.get_ticks_msec() + 5500
	while Time.get_ticks_msec() < display_ready:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		await _open_sites("bastion")
		await _controls(locale)
		paused = false
		await _clear()
		_game.queue_free()
		await _frames(5)
		print("SITE UI locale=", locale, " cumulative_failures=", _errors.size())
	options.restore(original)
	saves.autosaves_enabled = autosaves
	for message in _errors:
		push_error(message)
	print("Rendered facility controls: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _controls(locale):
	var camp = _game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")[0]
	var soldier = _spawn("Infantry", _human, camp.position + Vector3(3.8, 0, 0))
	soldier.sight_range = 0
	soldier.issue_manual_order(null)
	soldier.add_to_group("selected_units")
	_game.settings.visibility = 2
	_game.fog_of_war.reveal()
	await _frames(10)
	print(
		"SITE DISPLAY locale=",
		locale,
		" window=",
		root.size,
		" viewport=",
		root.get_visible_rect(),
		" factor=",
		root.content_scale_factor,
		" texture=",
		root.get_texture().get_size()
	)
	var before = soldier.manual_orders.pending.duplicate(true)
	_game.hud.direct_orders.arm("attack_move")
	_check(_game.hud.direct_orders.kind == "attack_move", "UI leak fixture did not arm order")
	var sites_button = _game.hud.find_child("OpenSites", true, false)
	_check(
		root.get_visible_rect().encloses(sites_button.get_global_rect()), "Sites button offscreen"
	)
	await _click_control(sites_button)
	_check(_game.hud._overlay != null and paused, "Sites click failed to open paused overview")
	_check(_game.hud.direct_orders.kind.is_empty(), "Sites overlay retained an armed map order")
	var overview = _game.hud._overlay.find_child("PointOfInterestOverview", true, false)
	var scroll = overview.get_children().filter(func(child): return child is ScrollContainer)[0]
	var back = _back()
	_check(root.gui_get_focus_owner() == back, "Sites overlay did not focus Back")
	_check(overview._rows.size() == 6, "Overview lacks six facility cards")
	_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Facility cards lack scrolling")
	var camp_row = overview._rows.filter(func(row): return row.site == camp)[0]
	_check(camp_row.hires.all(func(hire): return hire.button.disabled), "Neutral hire enabled")
	_check(camp_row.cancel.disabled, "Neutral cancellation enabled")
	await _cards_in_view(overview, scroll)
	await _capture(locale + "-neutral")
	var initial_scroll = scroll.scroll_vertical
	await _click(
		root.get_final_transform() * scroll.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP
	)
	_check(scroll.scroll_vertical != initial_scroll, "Engine mouse wheel did not scroll cards")
	var balance = Vector2i(_human.resource_a, _human.resource_b)
	await _click_control(camp_row.hires[0].button, scroll)
	_check(
		camp.jobs.is_empty() and balance == Vector2i(_human.resource_a, _human.resource_b),
		"Disabled neutral hire changed funds/queue"
	)
	await _action_key("attack_move")
	_check(_game.hud.direct_orders.kind.is_empty(), "Modal keyboard leaked an attack-move order")
	back.grab_focus()
	await _key(KEY_ENTER)
	_check(
		_game.hud._overlay == null and not paused, "Keyboard Back failed to restore running state"
	)
	_check(
		soldier.manual_orders.pending == before and soldier.is_in_group("selected_units"),
		"Neutral card controls changed selected infantry orders"
	)
	# Let a real infantry unit hold the actual capture ring for ten simulation seconds.
	camp.set_physics_process(true)
	soldier.process_mode = Node.PROCESS_MODE_INHERIT
	_game.battlefield.invalidate()
	for frame in 720:
		await physics_frame
		if camp.captured_by == _human:
			break
	_check(camp.captured_by == _human, "Live infantry never captured the mercenary camp")
	await _click_control(sites_button)
	overview = _game.hud._overlay.find_child("PointOfInterestOverview", true, false)
	scroll = overview.get_children().filter(func(child): return child is ScrollContainer)[0]
	camp_row = overview._rows.filter(func(row): return row.site == camp)[0]
	_check(not camp_row.hires[0].button.disabled, "Owned affordable hire remains disabled")
	balance = Vector2i(_human.resource_a, _human.resource_b)
	var cost = camp_row.hires[0].cost
	await _click_control(camp_row.hires[0].button, scroll)
	_check(camp.jobs.size() == 1, "Engine hire click did not queue infantry")
	_check(
		(
			Vector2i(_human.resource_a, _human.resource_b)
			== balance - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Engine hire click did not debit its displayed price"
	)
	_check(not camp_row.cancel.disabled, "Pending recruitment lacks enabled cancel")
	await _capture(locale + "-paid")
	await _click_control(camp_row.cancel, scroll)
	_check(
		camp.jobs.is_empty() and balance == Vector2i(_human.resource_a, _human.resource_b),
		"Engine cancellation did not refund exact cost"
	)
	_check(camp_row.cancel.disabled, "Empty queue retains enabled cancel")
	await _click_control(camp_row.hires[0].button, scroll)
	var infantry_count = _infantry_count()
	var view = _view_button(camp_row)
	await _click_control(view, scroll)
	_check(
		_game.hud._overlay == null and not paused, "View failed to resume previous running state"
	)
	var camera = _game.get_node("IsometricCamera3D")
	_check(
		(
			camera.unproject_position(camp.global_position).distance_to(
				root.get_visible_rect().get_center()
			)
			< 2
		),
		"View did not center the camera on the camp"
	)
	for frame in 900:
		await physics_frame
		if camp.jobs.is_empty() and _infantry_count() == infantry_count + 1:
			break
	_check(
		camp.jobs.is_empty() and _infantry_count() == infantry_count + 1,
		"UI-paid infantry never exited actual camp"
	)
	await _capture(locale + "-camp")
	paused = true
	var clock = _game.simulation_time
	await _click_control(sites_button)
	overview = _game.hud._overlay.find_child("PointOfInterestOverview", true, false)
	scroll = overview.get_children().filter(func(child): return child is ScrollContainer)[0]
	camp_row = overview._rows.filter(func(row): return row.site == camp)[0]
	await _cards_in_view(overview, scroll)
	if locale == "zh_CN":
		_check(
			tr("Capturable facilities") != "Capturable facilities",
			"Chinese overview title lacks translation"
		)
		_check(
			camp_row.hires[0].button.text.begins_with("招募"),
			"Chinese hiring caption remains English"
		)
	view = _view_button(camp_row)
	await _click_control(view, scroll)
	await _frames(15)
	_check(
		_game.hud._overlay == null and paused and _game.simulation_time == clock,
		"View discarded previous pause or advanced simulation"
	)
	await _click_control(sites_button)
	_check(root.gui_get_focus_owner() == _back(), "Reopened paused overview lost Back focus")
	await _key(KEY_ENTER)
	_check(_game.hud._overlay == null and paused, "Keyboard Back discarded prior pause")
	_check(
		soldier.manual_orders.pending == before and _game.hud.direct_orders.kind.is_empty(),
		"Facility controls leaked orders onto selected infantry"
	)


func _infantry_count():
	return (
		_human
		. get_children()
		. filter(func(unit): return "type" in unit and unit.type == "Infantry")
		. size()
	)


func _back():
	for button in _game.hud._overlay.find_children("*", "Button", true, false):
		if button.text == "Back to battle":
			return button
	return null


func _view_button(row):
	for child in row.status.get_parent().get_child(0).get_children():
		if child is Button:
			return child
	return null


func _cards_in_view(overview, scroll):
	for row in overview._rows:
		var card = row.status.get_parent()
		scroll.ensure_control_visible(card)
		await _frames(3)
		for control in card.find_children("*", "Control", true, false):
			if control is Button or control is Label:
				_check(
					root.get_visible_rect().encloses(control.get_global_rect()),
					"Facility card label/button outside viewport: " + control.text
				)
	_check(root.get_visible_rect().encloses(_back().get_global_rect()), "Back button offscreen")


func _click_control(control, scroll = null):
	if scroll != null:
		scroll.ensure_control_visible(control)
	await _frames(3)
	await _click(
		root.get_final_transform() * control.get_global_rect().get_center(), MOUSE_BUTTON_LEFT
	)


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
		root.push_input(event, false)
	await _frames(3)


func _action_key(action):
	await _key(InputMap.action_get_events(action)[0].physical_keycode)


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event, false)
		await _frames(2)


func _capture(label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "Facility preview resolution changed")
	image.save_png(CAPTURES.path_join(label + ".png"))
