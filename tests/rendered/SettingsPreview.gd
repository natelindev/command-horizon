extends "res://tests/headless/SettingsRegression.gd"

var _deadline = 0


func _initialize():
	# OS transitions use wall time even when Godot is invoked with --fixed-fps.
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 90000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Settings UI exceeded its wall-time deadline")
		quit(1)
	return false


func _run():
	var manager = root.get_node("SaveManager")
	var original_directory = manager.slots.directory
	manager.slots.directory = "user://settings-ui-slots-%d" % OS.get_process_id()
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://settings-ui-%d.tres" % OS.get_process_id()
	var fixture = preferences.DEFAULTS.duplicate()
	fixture.screen = preferences.Screen.WINDOW
	preferences.restore(fixture)
	await _settle_window(DisplayServer.WINDOW_MODE_WINDOWED)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _main_menu()
	await _setup("helix")
	await _battle()
	await _clean_match()
	var quick_path = manager.slots.path_for("quick")
	if FileAccess.file_exists(quick_path):
		DirAccess.remove_absolute(quick_path)
	DirAccess.remove_absolute(manager.slots.directory)
	manager.slots.directory = original_directory
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	print("Settings UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _main_menu():
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	var option_button = _named_button(menu, "OPTIONS")
	await _click(option_button)
	var dialog = root.get_node("Globals").settings_dialog
	_check(is_instance_valid(dialog), "Main menu did not open Settings")
	if not is_instance_valid(dialog):
		return
	dialog.save_path = archive
	var before = preferences.master_volume
	dialog.controls.master_volume.grab_focus()
	await _key(KEY_LEFT)
	_check(preferences.master_volume < before, "Keyboard slider did not preview volume")
	await _click(dialog.controls.reduced_flashes)
	_check(preferences.reduced_flashes, "Reduced flashes mouse control failed")
	var sample = _named_button(dialog, "Test voice and subtitles")
	await _click(sample)
	_check(
		dialog._sample.playing and dialog._sample.bus == "Voice",
		"Voice preview did not play on voice bus"
	)
	await _capture(dialog, "settings-main-720p")
	await _click(dialog._save)
	_check(
		not paused and not is_instance_valid(root.get_node("Globals").settings_dialog),
		"Settings Save did not return to main menu"
	)
	_check(root.gui_get_focus_owner() == option_button, "Main menu focus was lost")
	var loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded != null and loaded.reduced_flashes, "Settings UI did not persist saved choice")
	menu.queue_free()
	await _frames(5)


func _battle():
	var human = game._get_human_player()
	var unit = _units(human, "Tank")[0]
	unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	unit.get_node("Selection").select()
	game.get_node("IsometricCamera3D").set_physics_process(true)
	game.hud._open_menu()
	await _frames(5)
	var settings_button = _named_button(game.hud._overlay, "Settings")
	await _click(settings_button)
	var dialog = root.get_node("Globals").settings_dialog
	_check(is_instance_valid(dialog), "Battle menu did not open Settings")
	if not is_instance_valid(dialog):
		return
	dialog.save_path = archive
	var before = preferences.capture()
	var clock = game.simulation_time
	var camera = game.get_node("IsometricCamera3D")
	var position = camera.position
	var action = unit.action
	await _click(dialog.controls.edge_scrolling)
	var held_key = InputMap.action_get_events("move_map_right")[0].duplicate()
	held_key.keycode = held_key.physical_keycode
	held_key.pressed = true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	await _key(KEY_W)
	await _key(KEY_F)
	await _key(KEY_F5)
	await _key(KEY_SPACE)
	await _frames(20)
	_check(
		(
			game.simulation_time == clock
			and unit.action == action
			and camera.position == position
			and not game.hud._attack_armed
		),
		"Battle hotkeys leaked through Settings"
	)
	_check(
		not is_instance_valid(root.get_node("SaveManager").dialog),
		"Archive hotkey opened over Settings"
	)
	var manager = root.get_node("SaveManager")
	_check(
		not manager.busy and not FileAccess.file_exists(manager.slots.path_for("quick")),
		"Quicksave hotkey wrote an archive through Settings"
	)
	held_key = held_key.duplicate()
	held_key.pressed = false
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	await _capture(dialog, "settings-battle-720p")
	await _key(KEY_ESCAPE)
	_check(
		preferences.capture() == before and paused and game.hud._overlay != null,
		"Escape lost battle menu or rollback"
	)
	_check(root.gui_get_focus_owner() == settings_button, "Battle menu focus was lost")
	# Native display/confinement preview must be reversible with Escape.
	await _click(settings_button)
	dialog = root.get_node("Globals").settings_dialog
	dialog._preview("mouse_restricted", true)
	dialog._preview("screen", preferences.Screen.FULL)
	await _settle_window(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_check(
		(
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			and Input.mouse_mode == Input.MOUSE_MODE_CONFINED
		),
		"Display/confinement preview not applied"
	)
	await _key(KEY_ESCAPE)
	await _settle_window(DisplayServer.WINDOW_MODE_WINDOWED)
	_check(
		(
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		),
		"Display/confinement cancellation failed"
	)
	# Reproduce cancelling while the native fullscreen animation is still pending.
	await _click(settings_button)
	dialog = root.get_node("Globals").settings_dialog
	dialog._preview("screen", preferences.Screen.FULL)
	await _frames(2)
	await _key(KEY_ESCAPE)
	await _settle_window(DisplayServer.WINDOW_MODE_WINDOWED)
	_check(
		preferences.screen == preferences.Screen.WINDOW and paused,
		"Rapid display cancellation lost settings or battle pause"
	)
	game.hud._close_menu()
	_check(not paused, "Closing battle menu did not resume original play state")
	# The saved reduction must not remove real damage or attack accounting.
	var sides = _sides()
	var lancer = _spawn_weapon("CombatRobot", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(46, 0, 10))
	await _frames(10)
	lancer.process_mode = Node.PROCESS_MODE_PAUSABLE
	lancer.issue_manual_order(
		load("res://source/match/units/actions/AttackingWhileInRange.gd").new(target)
	)
	await _frames(60)
	_check(
		preferences.reduced_flashes and target.hp < target.hp_max,
		"Reduced flashes changed actual weapon damage"
	)


func _click(control):
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames(3)
		ancestor = ancestor.get_parent()
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)


func _capture(dialog, title):
	await _frames(10)
	var rect = dialog._panel.get_global_rect()
	_check(
		rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 1280 and rect.end.y <= 720,
		"Settings exceed 720p viewport"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _named_button(node, title):
	var buttons = node.find_children("*", "Button", true, false)
	return buttons.filter(func(button): return button.text == title)[0]


func _settle_window(mode):
	var started = Time.get_ticks_msec()
	var matched_since = -1
	while Time.get_ticks_msec() - started < 6000:
		await process_frame
		if DisplayServer.window_get_mode() != mode:
			matched_since = -1
		elif matched_since < 0:
			matched_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - matched_since > 1800:
			return
	_check(false, "Native display did not settle into the requested mode")
