extends "res://tests/headless/SettingsRegression.gd"

const Keys = preload("res://source/input/KeyBindings.gd")

var _chord_modifiers = {}


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://key-settings-%d.tres" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	_storage_keys()
	for faction in ["bastion", "helix"]:
		preferences.restore({"screen": 1, "edge_scrolling": false})
		_bind("pause_battle", KEY_U)
		_bind("attack_move", KEY_K | KEY_MASK_CTRL)
		await _setup(faction)
		await _capture_and_rollback()
		await _queue_shortcuts()
		await _commands()
		await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	for message in errors:
		push_error(message)
	print("Key bindings: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _bind(action, code):
	var record = preferences.key_bindings.duplicate(true)
	var error = Keys.problem(action, code, record.keys)
	_check(error.is_empty(), "Fixture rejected " + action + ": " + error)
	record.keys[action] = code
	preferences.key_bindings = record
	preferences.apply()
	_check(preferences.key_bindings.keys[action] == code, "Binding reset unexpectedly: " + action)


func _storage_keys():
	var expected = Keys.defaults()
	_check(preferences.key_bindings == expected, "Legacy options lack default keys")
	_check(Keys.normalize(expected) == expected, "Default profile invalid")
	var legacy = expected.duplicate(true)
	legacy.version = 4
	legacy.keys.erase("commander_support")
	legacy.keys.pause_battle = KEY_F6
	var upgraded = Keys.normalize(legacy)
	_check(
		upgraded.keys.pause_battle == KEY_F6 and upgraded.keys.commander_support == KEY_F7,
		"New commander shortcut erased an existing binding"
	)
	var crowded = legacy.duplicate(true)
	var remaps = {
		"pause_battle": KEY_F6,
		"attack_move": KEY_F7,
		"move_order": KEY_F8,
		"attack_target": KEY_F10,
		"force_attack": KEY_F11,
	}
	for action in remaps:
		crowded.keys[action] = remaps[action]
	var retained = Keys.normalize(crowded)
	_check(
		(retained.keys.commander_support & Keys.MODIFIERS) != 0,
		"Crowded profile did not receive a free commander chord"
	)
	for action in crowded.keys:
		_check(
			retained.keys[action] == crowded.keys[action], "Occupied function keys reset " + action
		)
	_check(
		(
			Keys
			. problem("commander_support", retained.keys.commander_support, retained.keys)
			. is_empty()
		),
		"Commander migration introduced a conflict"
	)
	for malformed in [
		null,
		{"version": "1", "keys": expected.keys},
		{"version": 99, "keys": expected.keys},
		{"version": 1, "keys": {}}
	]:
		_check(Keys.normalize(malformed) == expected, "Malformed key profile accepted")
	for invalid in [
		-1,
		INF,
		"K",
		999999999,
		KEY_SHIFT,
		KEY_TAB,
		KEY_ESCAPE,
		KEY_Q | KEY_MASK_META,
		KEY_F4 | KEY_MASK_ALT
	]:
		var bad = expected.duplicate(true)
		bad.keys.attack_move = invalid
		_check(Keys.normalize(bad) == expected, "Invalid/reserved key accepted: " + str(invalid))
	var duplicate = expected.duplicate(true)
	duplicate.keys.attack_move = KEY_SPACE
	_check(Keys.normalize(duplicate) == expected, "Duplicate binding was partially applied")
	_bind("pause_battle", KEY_U)
	_bind("attack_move", KEY_K | KEY_MASK_CTRL)
	var before = preferences.capture()
	before.key_bindings.keys.pause_battle = KEY_Z
	_check(
		preferences.key_bindings.keys.pause_battle == KEY_U, "Capture aliases live key dictionary"
	)
	_check(preferences.persist(archive) == OK, "Key profile failed to persist")
	var stored = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(stored.key_bindings == preferences.key_bindings, "Disk lost key profile")
	preferences.restore({"screen": 1, "edge_scrolling": false})
	preferences.restore(stored.capture())
	_check(Keys.label("pause_battle") == "U", "Stored profile failed to apply")
	print("PASS versioned key persistence, legacy defaults, corrupt/conflicting/reserved rejection")


func _capture_and_rollback():
	var globals = root.get_node("Globals")
	var before = preferences.capture()
	var dialog = globals.open_settings()
	dialog.save_path = archive
	dialog._tabs.current_tab = dialog._tabs.get_tab_idx_from_control(dialog.key_panel)
	await _frames(3)
	var panel = dialog.key_panel
	panel.begin_capture("pause_battle")
	await _press(KEY_Y)
	_check(Keys.label("pause_battle") == "Y", "Key capture did not preview pause")
	_check("[Y]" in game.hud._pause_button.tooltip_text, "Pause hint did not follow preview")
	_check(game.hud._pause_button.badge == "Y", "Pause badge did not follow preview")
	panel.begin_capture("pause_battle")
	await _press(KEY_R)
	_check(
		Keys.label("pause_battle") == "Y" and "Already used" in panel._message.text,
		"Conflict silently replaced building rotation"
	)
	await _press(KEY_ESCAPE | KEY_MASK_SHIFT)
	_check(
		is_instance_valid(globals.settings_dialog) and panel._capture_action.is_empty(),
		"Esc capture cancellation closed settings"
	)
	panel.begin_capture("shift_selecting")
	await _press(KEY_ALT)
	_check(
		preferences.key_bindings.keys.shift_selecting == KEY_ALT,
		"Modifier-only hold capture failed"
	)
	panel.begin_capture("quicksave_battle")
	await _press(KEY_F7)
	_check(
		preferences.key_bindings.keys.quicksave_battle == KEY_F7,
		"Capture triggered save instead of binding"
	)
	panel._reset("quicksave_battle")
	_check(
		preferences.key_bindings.keys.quicksave_battle == KEY_F5, "Per-action default reset failed"
	)
	var clock = game.simulation_time
	await _frames(10)
	_check(game.simulation_time == clock and paused, "Editing keys advanced battle")
	dialog._finish(false)
	await _frames(3)
	_check(
		preferences.capture() == before and not paused,
		"Cancel did not restore nested bindings/pause"
	)
	_check("[U]" in game.hud._pause_button.tooltip_text, "Cancel left stale pause hint")
	# Rebinding a held camera action cannot leave its old press latched.
	Input.action_press("move_map_up")
	_bind("move_map_up", KEY_I)
	_check(not Input.is_action_pressed("move_map_up"), "Remapping left old key held")
	print(
		"PASS live capture, conflict, modifier hold, Esc/per-action reset, rollback and held-key release"
	)


func _queue_shortcuts():
	_release_focus()
	var human = game._get_human_player()
	var tanks = _units(human, "Tank")
	var tank = tanks[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	_bind("attack_move", KEY_F)
	_bind("shift_selecting", KEY_SHIFT)
	await _press(KEY_1 | KEY_MASK_CTRL)
	root.get_node("MatchSignals").deselect_all_units.emit()
	var worker = _units(human, "Worker")[0]
	worker.get_node("Selection").select()
	await _down(KEY_SHIFT)
	await _press(KEY_1 | KEY_MASK_SHIFT)
	_check(
		tank.is_in_group("selected_units") and worker.is_in_group("selected_units"),
		"Shift+group recall failed to add to existing selection"
	)
	worker.get_node("Selection").deselect()
	var camera = game.get_node("IsometricCamera3D")
	for point in [Vector3(31, 0, 30), Vector3(35, 0, 30)]:
		await _press(KEY_F | KEY_MASK_SHIFT)
		_check(game.hud._attack_armed, "Shift+F did not arm attack move")
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = camera.unproject_position(point)
		click.pressed = true
		click.shift_pressed = true
		game.hud._unhandled_input(click)
	var orders = tank.manual_orders
	# An idle queue starts its first order immediately, even between physics ticks.
	_check(
		(
			orders.current.get("kind") == "attack_move"
			and orders.current.point.distance_to(Vector3(31, 0, 30)) < 0.1
			and orders.pending.size() == 1
			and orders.pending[0].kind == "attack_move"
			and orders.pending[0].point.distance_to(Vector3(35, 0, 30)) < 0.1
		),
		"Shift+F replaced queued attack orders"
	)
	await _up(KEY_SHIFT)
	tank.manual_orders.cancel()
	_bind("pause_battle", KEY_F | KEY_MASK_SHIFT)
	await _down(KEY_SHIFT)
	await _press(KEY_F | KEY_MASK_SHIFT)
	_check(paused and not game.hud._attack_armed, "Explicit Shift+F lost to queue fallback")
	await _press(KEY_F | KEY_MASK_SHIFT)
	await _up(KEY_SHIFT)
	_bind("pause_battle", KEY_U)
	_bind("shift_selecting", KEY_ALT)
	_bind("attack_move", KEY_K | KEY_MASK_CTRL)
	await _down(KEY_ALT)
	await _press(KEY_K | KEY_MASK_CTRL | KEY_MASK_ALT)
	_check(game.hud._attack_armed, "Remapped modifier hold prevented attack chord")
	await _up(KEY_ALT)
	game.hud._arm_attack()
	print("PASS real Shift+F queue, Shift+group, explicit chord priority and Alt+Ctrl+K")


func _commands():
	_bind("move_order", KEY_M | KEY_MASK_ALT)
	_bind("attack_target", KEY_T | KEY_MASK_ALT)
	_bind("pause_battle", KEY_U)
	_bind("attack_move", KEY_K | KEY_MASK_CTRL)
	_bind("toggle_match_menu", KEY_M)
	_bind("rotate_structure", KEY_T)
	_bind("shift_selecting", KEY_G)
	_bind("move_map_right", KEY_K)
	_bind("rotate_map_clockwise", KEY_O)
	_bind("unit_groups_set_1", KEY_B | KEY_MASK_CTRL)
	_bind("unit_groups_access_1", KEY_B)
	_bind("quicksave_battle", KEY_F7)
	_bind("quickload_battle", KEY_F10)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	_bind("pause_battle", KEY_SPACE)
	game.hud._attack_button.grab_focus()
	await _press(KEY_SPACE)
	_check(paused and not game.hud._attack_armed, "Focused HUD button stole Space pause")
	await _press(KEY_SPACE)
	_bind("attack_move", KEY_RIGHT)
	game.hud._pause_button.grab_focus()
	await _press(KEY_RIGHT)
	_check(game.hud._attack_armed, "Focused HUD button stole arrow attack")
	game.hud._arm_attack()
	_bind("attack_move", KEY_K | KEY_MASK_CTRL)
	_bind("pause_battle", KEY_U)
	_release_focus()
	await _press(KEY_SPACE)
	_check(not paused, "Old pause key still active")
	await _press(KEY_U)
	_check(paused and "[U]" in game.hud._pause_button.tooltip_text, "Remapped pause failed")
	await _press(KEY_U)
	_check(not paused, "Remapped resume failed")
	await _press(KEY_F)
	_check(not game.hud._attack_armed, "Old attack key still active")
	await _down(KEY_K | KEY_MASK_CTRL)
	_check(game.hud._attack_armed, "Remapped attack shortcut failed")
	_check(
		camera._calculate_screen_move_vector() == Vector2.ZERO,
		"Ctrl+K also activated K camera movement"
	)
	await _up(KEY_K | KEY_MASK_CTRL)
	game.hud._arm_attack()
	await _down(KEY_K)
	_check(
		camera._calculate_screen_move_vector() == Vector2.RIGHT and not game.hud._attack_armed,
		"Plain camera key also activated modified attack"
	)
	await _down(KEY_CTRL)
	_check(
		camera._calculate_screen_move_vector() == Vector2.ZERO,
		"Pressing Ctrl after K left plain camera movement active"
	)
	await _up(KEY_CTRL)
	_check(
		camera._calculate_screen_move_vector() == Vector2.RIGHT,
		"Releasing Ctrl while K held did not restore camera movement"
	)
	await _up(KEY_K)
	var angle = camera.rotation.y
	await _down(KEY_O)
	camera._try_handling_arrowkey_rotation(.1)
	_check(camera.rotation.y != angle, "Remapped camera rotation failed")
	await _up(KEY_O)
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	await _press(KEY_U)
	game.hud._attack_button.grab_focus()
	await _press(KEY_B | KEY_MASK_CTRL)
	_check(tank.is_in_group("unit_group_1"), "Remapped group assignment failed")
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _press(KEY_B)
	_check(tank.is_in_group("selected_units"), "Remapped group recall failed")
	camera.set_position_safely(Vector3(55, 0, 55))
	var groups = game.find_child("UnitGroupSelectionHandler")
	groups._last_access_time = Time.get_ticks_msec()
	await _press(KEY_B)
	_check(
		camera.global_position.is_equal_approx(
			camera._target_position_to_camera_position(tank.global_position)
		),
		"Double group recall did not center the camera"
	)
	await _press(KEY_U)
	_release_focus()
	# Queue attack-move with a non-Shift hold binding through the actual HUD handler.
	await _down(KEY_G)
	await _press(KEY_K | KEY_MASK_CTRL)
	_check(game.hud._attack_armed, "Held G prevented attack shortcut")
	var point = camera.unproject_position(Vector3(31, 0, 30))
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	game.hud._unhandled_input(click)
	await _press(KEY_K | KEY_MASK_CTRL)
	_check(game.hud._attack_armed, "Held G prevented second attack shortcut")
	click.position = camera.unproject_position(Vector3(35, 0, 30))
	game.hud._unhandled_input(click)
	_check(tank.manual_orders.pending.size() == 2, "Attack-move ignored remapped queue hold")
	await _up(KEY_G)
	tank.manual_orders.cancel()
	var handler = human.get_node("StructurePlacementHandler")
	root.get_node("MatchSignals").deselect_all_units.emit()
	_units(human, "Worker")[0].get_node("Selection").select()
	handler._on_structure_placement_request(load("res://source/match/units/PowerPlant.tscn"))
	var previous = handler._active_blueprint_node.rotation.y
	_bind("move_map_left", KEY_J)
	_bind("rotate_structure", KEY_LEFT)
	game.hud._attack_button.grab_focus()
	await _press(KEY_LEFT)
	_check(
		handler._active_blueprint_node.rotation.y != previous, "Remapped structure rotation failed"
	)
	handler._cancel_structure_placement()
	_release_focus()
	await _press(KEY_M)
	_check(game.hud._overlay != null and paused, "Remapped menu failed")
	_check(
		game.hud._overlay.find_children("*", "Button", true, false).all(
			func(button): return button.text != "Controls"
		),
		"Pause menu still includes the redundant Controls item"
	)
	await _press(KEY_B | KEY_MASK_CTRL)
	_check(tank.is_in_group("unit_group_1"), "Menu input changed group assignment")
	game.hud._close_menu()
	_release_focus()
	await _save_keys()
	print(
		(
			"PASS %s remapped pause/attack/camera/rotation/groups/queue/menu/quicksave/load"
			% human.faction
		)
	)


func _save_keys():
	var manager = root.get_node("SaveManager")
	var directory = manager.slots.directory
	manager.slots.directory = "user://key-slots-%d" % OS.get_process_id()
	var target = manager.slots.path_for("quick")
	await _press(KEY_F5)
	_check(not FileAccess.file_exists(target), "Old quicksave key still active")
	await _press(KEY_F7)
	for frame in 180:
		if not manager.busy:
			break
		await process_frame
	_check(FileAccess.file_exists(target), "Remapped quicksave did not write battle")
	await _press(KEY_F9)
	_check(not is_instance_valid(manager.dialog), "Old quickload key still active")
	await _press(KEY_F10)
	await _frames(12)
	_check(is_instance_valid(manager.dialog), "Remapped quickload failed to open")
	if is_instance_valid(manager.dialog):
		manager.dialog._back()
		await _frames(5)
	_bind("quicksave_battle", KEY_N)
	var edit = LineEdit.new()
	game.hud.add_child(edit)
	edit.grab_focus()
	await _frames(3)
	var before = game.simulation_time
	var archive_before = FileAccess.get_file_as_bytes(target)
	await _press(KEY_N)
	_check(
		not manager.busy and not paused and game.simulation_time > before,
		"Text entry triggered quicksave"
	)
	_check(FileAccess.get_file_as_bytes(target) == archive_before, "Typing rewrote quicksave")
	_check(edit.text.to_upper() == "N", "Text field did not receive remapped key")
	var group_before = get_nodes_in_group("unit_group_1").duplicate()
	await _press(KEY_B | KEY_MASK_CTRL)
	_check(get_nodes_in_group("unit_group_1") == group_before, "Text entry reassigned group")
	await _press(KEY_K | KEY_MASK_CTRL)
	_check(not game.hud._attack_armed, "Text entry armed attack move")
	edit.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(manager.slots.directory)
	manager.slots.directory = directory


func _release_focus():
	var focus = root.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _down(code):
	var added = []
	for pair in [
		[KEY_CTRL, KEY_MASK_CTRL],
		[KEY_SHIFT, KEY_MASK_SHIFT],
		[KEY_ALT, KEY_MASK_ALT],
		[KEY_META, KEY_MASK_META]
	]:
		if code & pair[1] and not Input.is_physical_key_pressed(pair[0]):
			var modifier = Keys.event_for(pair[0])
			modifier.keycode = pair[0]
			modifier.pressed = true
			Input.parse_input_event(modifier)
			added.append(pair[0])
	_chord_modifiers[code] = added
	var event = Keys.event_for(code)
	event.keycode = event.physical_keycode
	event.unicode = event.keycode if event.keycode < 127 else 0
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)


func _up(code):
	var event = Keys.event_for(code)
	event.keycode = event.physical_keycode
	event.pressed = false
	Input.parse_input_event(event)
	for key in _chord_modifiers.get(code, []):
		var modifier = Keys.event_for(key)
		modifier.keycode = key
		modifier.pressed = false
		Input.parse_input_event(modifier)
	_chord_modifiers.erase(code)
	await _frames(3)


func _press(code):
	await _down(code)
	await _up(code)
