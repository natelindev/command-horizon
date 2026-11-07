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
	# Reassert the review size after the native scene/window transition settles.
	await create_timer(0.5, true).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _frames(12)
	var hud = game.hud
	var human = game._get_human_player()
	var lab = _units(human, "CommandLab")[0]
	var tank = _units(human, "Tank")[0]
	var worker = _units(human, "Worker")[0]
	var label = "research-queue-%s-%s-720p-150" % [faction, language]
	game.get_node("IsometricCamera3D").set_position_safely(lab.global_position)
	await _select([tank, worker])
	await _activate(hud._technology_button)
	_check(not paused and hud.technology_panel != null, "Tech changed running battle state")
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
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	var branches = catalog.FACTION_TECHNOLOGIES[faction]
	var pair = catalog.EXCLUSIVE_PAIRS[catalog.FACTION_TECHNOLOGIES.keys().find(faction)]
	var queued_ids = branches.filter(func(id): return id != pair[1])
	var spent = catalog.cost("coordination")
	await _activate(panel._start)
	for id in queued_ids:
		await _activate(panel._branches[id].button)
		spent += catalog.cost(id)
	_check(
		human.coordination_left > 0 and human.technology.active == "", "Coordination lost its slot"
	)
	_check(panel._queue_rows.size() == queued_ids.size(), "Full paid queue is not visible")
	_check(
		human.technology.queued.map(func(entry): return entry.id) == queued_ids,
		"FIFO order differs"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - spent,
		"Keyboard queue purchase charged wrong prices"
	)
	if panel._queue_rows.size() != queued_ids.size():
		return
	for row in panel._queue_rows:
		_check(
			row.cancel.portrait() != null and not row.cancel._title.is_visible_in_tree(),
			"Queued cancellation is not an icon"
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
		(
			(str(queued_ids.size()) + "项排队中") in status
			if language == "zh_CN"
			else (str(queued_ids.size()) + " queued") in status
		),
		"Queue count did not follow the selected language: " + status
	)
	await _select([lab])
	var menus = game.find_child("UnitMenus")
	var lab_panel = menus._research_panel
	_check(is_instance_valid(lab_panel), "Selected lab omitted research queue")
	if is_instance_valid(lab_panel):
		_check(
			lab_panel._queue_rows.size() == queued_ids.size(),
			"Bottom research queue omits paid projects"
		)
		_check(
			menus._command_bay.get_global_rect().encloses(lab_panel.get_global_rect()),
			"Selected lab research does not fit in the console"
		)
		await _shot(label + "-lab")
	panel = lab_panel
	# A cancelled reservation releases the rival immediately, before any completion.
	await _activate(panel._queue_rows[-1].cancel)
	_check(
		not panel._branches[pair[1]].button.disabled, "Cancelled doctrine kept its rival reserved"
	)
	await _activate(panel._branches[pair[0]].button)
	# An independent cancellation removes only its own prepaid project.
	await _activate(panel._queue_rows[0].cancel)
	spent -= catalog.cost(queued_ids[0])
	_check(
		human.technology.queued.map(func(entry): return entry.id) == queued_ids.slice(1),
		"Independent cancellation changed FIFO order"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds - spent, "Queued refund differs")
	_check(
		root.gui_get_focus_owner() == panel._queue_rows[0].cancel, "Queue cancellation lost focus"
	)
	_overlay_inside(hud, panel._queue_rows[0].cancel, label)
	# Coordination is the actual shared prerequisite in the current catalog.
	await _activate(panel._cancel)
	_check(
		human.coordination_left == -1 and human.technology.queued.is_empty(),
		"Cascade retained dependencies"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Prerequisite refunds differ")
	await _shot(label + "-cascade")
	human.coordination_unlocked = true
	panel.refresh()
	await _activate(panel._branches[branches[0]].button)
	await _activate(panel._branches[branches[1]].button)
	await _activate(panel._branches[pair[0]].button)
	await _activate(panel._cancel)
	_check(
		human.technology.active == branches[1] and human.technology.queued[0].id == pair[0],
		"Active cancellation failed to advance independent work"
	)
	await _activate(panel._queue_rows[0].cancel)
	_check(
		not panel._branches[pair[1]].button.disabled, "Queued doctrine refund did not release rival"
	)
	await _activate(panel._cancel)
	_check(
		human.technology.active == "" and human.technology.queued.is_empty(),
		"Cancellation retained work"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "GUI refunds did not conserve funds"
	)
	_check(paused, "Research controls resumed a tactically paused battle")
	_queue_cases += 1
	print("PASS ", label, " keyboard FIFO purchases, focus, cascade refunds and pause authority")


func _overlay_inside(hud, focused, label):
	var menus = game.find_child("UnitMenus")
	_check(hud._overlay == null, "Research created a floating window")
	_check(
		menus.get_global_rect().grow(1).encloses(focused.get_global_rect()),
		"Queued keyboard focus is clipped: " + label
	)
	_check(
		root.size == Vector2i(1280, 720),
		"Research queue review lost 720p resolution: %s %s" % [label, root.size]
	)
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
