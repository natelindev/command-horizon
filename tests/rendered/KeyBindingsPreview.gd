extends "res://tests/headless/KeyBindingsRegression.gd"


func _initialize():
	Engine.max_fps = 60
	create_timer(180).timeout.connect(func(): quit(1))
	_run.call_deferred()


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://key-preview-%d.tres" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(15)
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = archive
	await _frames(5)
	if "--native" in OS.get_cmdline_user_args():
		print("Native Controls ready: choose Controls, bind Tactical pause to P, Save & back")
		while is_instance_valid(dialog):
			await process_frame
		_check(
			preferences.key_bindings.keys.pause_battle == KEY_P,
			"Native capture/save did not bind P"
		)
	else:
		dialog._tabs.current_tab = 1
		await _frames(5)
		await _click(dialog.key_panel.buttons.pause_battle)
		await _press(KEY_R)
		_check("Already used" in dialog.key_panel._message.text, "UI omitted key conflict")
		await _capture(dialog, "controls-conflict-720p")
		await _press(KEY_P)
		_check(Keys.label("pause_battle") == "P", "UI failed key capture")
		await _capture(dialog, "controls-main-720p")
		# Keyboard focus scrolls all the way to group 9 rather than disappearing offscreen.
		dialog.key_panel.buttons.unit_groups_access_9.grab_focus()
		await _frames(5)
		await _capture(dialog, "controls-groups-720p")
		await _click(dialog._save)
	await _frames(4)
	var saved = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(
		saved != null and saved.key_bindings.keys.pause_battle == KEY_P,
		"UI failed to persist binding"
	)
	menu.queue_free()
	await _frames(5)
	await _setup("bastion")
	_release_focus()
	if "--native" in OS.get_cmdline_user_args():
		print("Native battle ready: press P to pause, then P to resume")
		while not paused:
			await process_frame
		await _capture(null, "controls-native-paused")
		while paused:
			await process_frame
		print("Native P pause/resume passed")
	else:
		await _press(KEY_P)
		_check(paused and "[P]" in game.hud._pause_button.text, "Rendered remap did not pause")
		await _capture(null, "controls-battle-paused")
		await _press(KEY_P)
		_check(not paused, "Rendered remap did not resume")
	game.hud._open_menu()
	await _frames(5)
	var battle_buttons = game.hud._overlay.find_children("*", "Button", true, false)
	var battle_settings = battle_buttons.filter(func(button): return button.text == "Settings")[0]
	await _click(battle_settings)
	dialog = root.get_node("Globals").settings_dialog
	_check(is_instance_valid(dialog), "Battle Settings entry failed")
	dialog.save_path = archive
	dialog._tabs.current_tab = 1
	await _frames(5)
	await _click(dialog.key_panel.buttons.attack_move)
	await _press(KEY_K | KEY_MASK_CTRL)
	_check(Keys.label("attack_move") == "Ctrl+K", "Battle key capture lost modifiers")
	await _capture(dialog, "controls-battle-720p")
	await _click(dialog._cancel)
	_check(
		Keys.label("attack_move") == "F" and paused,
		"Battle Cancel did not restore binding/menu pause"
	)
	game.hud._close_menu()
	await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	for message in errors:
		push_error(message)
	print("Controls UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _click(control):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)


func _capture(dialog, title):
	print("CONTROLS CAPTURE begin ", title)
	await _frames(5)
	if is_instance_valid(dialog):
		var rect = dialog._panel.get_global_rect()
		_check(
			(
				rect.position.x >= 0
				and rect.position.y >= 0
				and rect.end.x <= 1280
				and rect.end.y <= 720
			),
			"Controls exceed 720p"
		)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)
	print("CONTROLS CAPTURE complete ", title)
