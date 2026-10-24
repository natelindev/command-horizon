extends "res://tests/rendered/HudConsolePreview.gd"

# Reuse the battle-console capture and geometry checks for the paid queue.
# Run without --headless; every purchase/cancellation uses ordinary GUI key input.
var _queue_cases = 0


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Research queue preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix", "frontier"]:
		for language in ["en", "zh_CN"]:
			await _configure(preferences, Vector2i(1280, 720), 1.5, language)
			await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
			await _queue_interface(faction, language)
			paused = false
			game.queue_free()
			await _frames(5)
	_check(_queue_cases == 6, "Research queue interface matrix did not complete")
	preferences.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Research queue interface: %d failures over %d cases" % [errors.size(), _queue_cases])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _queue_interface(faction, language):
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var hud = game.hud
	var human = game._get_human_player()
	var lab = _units(human, "CommandLab")[0]
	var tank = _units(human, "Tank")[0]
	var worker = _units(human, "Worker")[0]
	var label = "research-queue-%s-%s-720p-150" % [faction, language]
	game.get_node("IsometricCamera3D").set_position_safely(lab.global_position)
	await _select([tank, worker])
	await _activate(hud._technology_button)
	_check(paused and hud.technology_panel != null, "Tech did not pause running battle")
	await _key(KEY_ESCAPE)
	_check(not paused and hud.technology_panel == null, "Tech did not restore running battle")
	hud._toggle_pause()
	await _key(KEY_ESCAPE)
	_check(paused and hud._overlay != null, "Battle menu did not preserve tactical pause")
	await _key(KEY_ESCAPE)
	_check(paused and hud._overlay == null, "Closing battle menu lost tactical pause")
	await _activate(hud._technology_button)
	var panel = hud.technology_panel
	_check(is_instance_valid(panel), "Tech did not reopen from paused battle")
	if not is_instance_valid(panel):
		return
	human.resource_a = 1000
	human.resource_b = 1000
	panel.refresh()
	var funds = Vector2i(human.resource_a, human.resource_b)
	for button in [
		panel._branches.weapons.button,
		panel._start,
		panel._branches.weapons.button,
		panel._branches.armor.button,
		panel._branches.armor.button,
		panel._branches.service.button,
		panel._branches.doctrine.button,
		panel._branches.dual_purpose_aa.button,
	]:
		await _activate(button)
	_check(human.technology.active == "weapons_1", "Queue changed its active project")
	_check(panel._queue_rows.size() == 7, "Full paid queue is not visible")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(320, 215),
		"Keyboard queue purchase charged wrong prices"
	)
	if panel._queue_rows.size() != 7:
		return
	for row in panel._queue_rows:
		_check(
			row.cancel.text == ("取消" if language == "zh_CN" else "Cancel"),
			"Queued cancellation label did not follow the selected language"
		)
		_check(
			row.cancel.accessibility_name.begins_with(
				"取消队列中的" if language == "zh_CN" else "Cancel queued "
			),
			"Queued cancellation accessible name did not follow the selected language"
		)
	var last = panel._queue_rows[-1].cancel
	panel._queue_rows[-2].cancel.grab_focus()
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == last, "Tab did not reach the final queued project")
	_check(get_nodes_in_group("selected_units").size() == 2, "Queue Tab changed army subgroups")
	var before = human.technology.capture()
	var clock_before = game.simulation_time
	await _frames(20)
	_check(root.gui_get_focus_owner() == last, "Queue refresh stole keyboard focus")
	_check(human.technology.capture() == before, "Paused queue advanced during GUI input")
	_check(game.simulation_time == clock_before, "Queue controls resumed simulation")
	_overlay_inside(hud, last, label)
	await _shot(label + "-full")
	await _key(KEY_ESCAPE)
	_check(paused and hud.technology_panel == null, "Closing queue lost prior pause state")
	hud.research_status.refresh()
	var status = str(TranslationServer.translate(hud.research_status._button.text))
	_check(
		"7项排队中" in status if language == "zh_CN" else "7 queued" in status,
		"Queue count did not follow the selected language: " + status
	)
	await _select([lab])
	var menus = game.find_child("UnitMenus")
	var lab_panel = menus._research_panel
	_check(is_instance_valid(lab_panel), "Selected lab omitted research queue")
	if is_instance_valid(lab_panel):
		lab_panel._queue_rows[-1].cancel.grab_focus()
		await _frames(8)
		_check(
			menus._scroll.get_global_rect().encloses(
				lab_panel._queue_rows[-1].cancel.get_global_rect()
			),
			"Selected lab queue does not scroll to keyboard focus"
		)
		await _shot(label + "-lab")
	await _activate(hud._technology_button)
	panel = hud.technology_panel
	await _activate(panel._queue_rows[0].cancel)
	_check(
		(
			human.technology.queued.map(func(entry): return entry.id)
			== ["armor_1", "service", "dual_purpose_aa"]
		),
		"Keyboard prerequisite cancellation did not cascade in order"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(135, 90),
		"Keyboard cascade lost prepaid resources"
	)
	_check(root.gui_get_focus_owner() == panel._queue_rows[0].cancel, "Cascade lost focus")
	_overlay_inside(hud, panel._queue_rows[0].cancel, label)
	await _shot(label + "-cascade")
	await _activate(panel._cancel)
	_check(
		(
			human.technology.active == "armor_1"
			and human.technology.queued.map(func(entry): return entry.id) == ["service"]
		),
		"Active keyboard cancellation did not preserve independent queued work"
	)
	await _activate(panel._cancel)
	_check(human.technology.active == "service", "Independent queue did not advance")
	await _activate(panel._cancel)
	_check(
		human.technology.active == "" and human.technology.queued.is_empty(),
		"Keyboard cancellation retained work"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "GUI refunds did not conserve funds"
	)
	await _key(KEY_ESCAPE)
	_check(paused, "Final close resumed a tactically paused battle")
	_queue_cases += 1
	print("PASS ", label, " keyboard FIFO purchases, focus, cascade refunds and pause authority")


func _overlay_inside(hud, focused, label):
	var scroll = hud._technology_scroll
	var surface = scroll.get_parent()
	while surface != null and not surface is PanelContainer:
		surface = surface.get_parent()
	_check(surface != null, "Technology overlay lacks a panel")
	if surface != null:
		_check(
			root.get_visible_rect().encloses(surface.get_global_rect()),
			"Research queue overlay exceeds the viewport: " + label
		)
	_check(
		scroll.get_global_rect().encloses(focused.get_global_rect()),
		"Queued keyboard focus is clipped: " + label
	)
	_check(root.size == Vector2i(1280, 720), "Research queue review lost 720p resolution")
	_check(
		root.get_node("Globals").options.interface_scale == 1.5,
		"Research queue review lost 150% UI scale"
	)


func _activate(button):
	_check(
		is_instance_valid(button) and not button.disabled, "Requested research control is disabled"
	)
	if not is_instance_valid(button) or button.disabled:
		return
	button.grab_focus()
	await _frames(3)
	_check(root.gui_get_focus_owner() == button, "Research control did not take keyboard focus")
	await _key(KEY_ENTER)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
