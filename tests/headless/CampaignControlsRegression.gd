extends "res://tests/headless/SplitSignalRegression.gd"


func _run():
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://campaign-controls-%d.json" % OS.get_process_id()
	await _make_match()
	var hud = game.hud
	_check(
		hud.find_child("OpenRelays", true, false) == null,
		"Skirmish relays duplicate mission controls"
	)
	hud._hint_left = 0.001
	await _frames(10)
	var baseline = hud._relay_buttons[1].get_global_rect()
	var count = [0]
	hud._relay_buttons[1].pressed.connect(func(): count[0] += 1)
	for notice in [
		"Checkpoint saved",
		"A two-line notice.\nKeep the relay controls still.",
		"Long feedback.\n".repeat(12),
		""
	]:
		var point = baseline.get_center()
		_mouse(point, true)
		if notice.is_empty():
			hud._hint_left = 0.001
		else:
			hud.show_notice(notice)
		await _frames(8)
		_check(hud._relay_buttons[1].get_global_rect() == baseline, "Notice moved relay controls")
		_mouse(point, false)
		await _frames(2)
	_check(count[0] == 4, "A notice interrupted a held relay click")
	_check(
		hud.objective_panel.get_global_rect().end.y < 500, "Notices push objectives over minimap"
	)
	hud.show_notice("Long feedback.\n".repeat(12))
	await _frames(5)
	_check(hud._notice_slot.get_v_scroll_bar().visible, "Long feedback is inaccessible")
	_check(
		hud._notice_slot.get_v_scroll_bar().focus_mode == Control.FOCUS_ALL,
		"Long feedback cannot receive keyboard focus"
	)
	var bar = hud._notice_slot.get_v_scroll_bar()
	bar.grab_focus()
	var before = bar.value
	for pressed in [true, false]:
		var key = InputEventKey.new()
		key.keycode = KEY_DOWN
		key.physical_keycode = KEY_DOWN
		key.pressed = pressed
		root.push_input(key, true)
	_check(bar.value > before, "Arrow key did not scroll long feedback")
	hud._notice_slot.scroll_vertical = 100
	hud.show_notice("New notice")
	_check(hud._notice_slot.scroll_vertical == 0, "New notice starts scrolled out of view")
	hud.arm_program_assignment("anchor", [_units(game._get_human_player(), "Tank")[0]])
	await _frames(5)
	_check(hud._relay_buttons[1].get_global_rect() == baseline, "Assignment moved relay controls")
	_check(hud._assignment_hint.visible, "Assignment instructions missing")
	hud.show_notice("Queued notice")
	_check(
		hud._assignment_hint.text.contains("guard point"),
		"Notice displaced assignment instructions"
	)
	hud.cancel_map_assignment()
	await _frames(5)
	_check(hud._assignment_hint.text == "Queued notice", "Queued notice lost after cancellation")
	_check(hud._relay_buttons[1].get_global_rect() == baseline, "Cancellation moved relay controls")
	await _cleanup()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign controls: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _mouse(point, pressed):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
