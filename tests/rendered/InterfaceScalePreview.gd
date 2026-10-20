extends "res://tests/rendered/SettingsPreview.gd"

var expected_pixels = Vector2i(1280, 720)


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://interface-scale-%d.tres" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	if DisplayServer.get_name() != "headless":
		await _settle_window(DisplayServer.WINDOW_MODE_WINDOWED)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var manager = root.get_node("SaveManager")
	var old_directory = manager.slots.directory
	var old_autosaves = manager.autosaves_enabled
	manager.slots.directory = "user://interface-scale-slots-%d" % OS.get_process_id()
	manager.autosaves_enabled = false
	await _scale_storage()
	await _menu_screens()
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		game.hud._toggle_pause()
		for factor in [1.0, 1.25, 1.5]:
			preferences.interface_scale = factor
			preferences.apply()
			await _frames(10)
			print(
				"Scale ",
				factor,
				" logical ",
				root.get_visible_rect().size,
				" transform ",
				root.get_final_transform()
			)
			_check(
				root.get_visible_rect().size.is_equal_approx(Vector2(1920, 1080) / factor),
				"Logical canvas does not match interface size"
			)
			await _battle_scale(faction, factor)
		await _scale_settings()
		if faction == "helix":
			await _larger_windows()
		await _clean_match()
	await _campaign_scale()
	manager.slots.directory = old_directory
	manager.autosaves_enabled = old_autosaves
	preferences.restore(original)
	DirAccess.remove_absolute(archive)
	print("Interface scaling: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _scale_storage():
	for factor in [1.0, 1.25, 1.5]:
		preferences.interface_scale = factor
		preferences.apply()
		_check(root.content_scale_factor == factor, "Interface factor not applied")
		_check(preferences.persist(archive) == OK, "Could not save interface size")
		var loaded = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(loaded.interface_scale == factor, "Interface size lost in settings file")
	for invalid in [INF, NAN, -1.0, 8.0, "invalid"]:
		preferences.restore({"screen": 1, "interface_scale": invalid})
		_check(preferences.interface_scale == 1.0, "Invalid interface size not repaired")
	preferences.restore({"screen": 1, "edge_scrolling": false})
	_check(preferences.interface_scale == 1.0, "Legacy interface size default missing")
	print("PASS: persisted interface sizes, invalid values and legacy defaults")


func _battle_scale(faction, factor):
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var hq = _units(human, "CommandCenter")[0]
	if factor == 1.0:
		for index in range(5):
			_check(
				hq.production_queue.produce(load("res://source/match/units/Worker.tscn")) != null,
				"Could not fill paid production queue"
			)
	var menus = game.find_child("UnitMenus")
	for role in ["Worker", "CommandCenter", "VehicleFactory", "Tank", "CommandLab"]:
		for selected in get_nodes_in_group("selected_units"):
			selected.get_node("Selection").deselect()
		var unit = _units(human, role)[0]
		unit.get_node("Selection").select()
		await _frames(8)
		_inside(menus, role + " commands")
		_inside(
			game.get_node("HUD/MarginContainer3/VBoxContainer/ProductionQueue"), "Production queue"
		)
		if role == "CommandCenter":
			await _shot("interface-production-%s-%d-720p" % [faction, roundi(factor * 100)])
	for selected in get_nodes_in_group("selected_units"):
		selected.get_node("Selection").deselect()
	tank.get_node("Selection").select()
	await _frames(5)
	var camera = game.get_node("IsometricCamera3D")
	var point = hq.position + Vector3(4, 0, 4)
	camera.set_position_safely(point)
	await _frames(4)
	var minimap = game.get_node("HUD/MarginContainer/Minimap")
	await _click(minimap._texture_rect)
	var map_center = Vector3(game.map.size.x / 2, 0, game.map.size.y / 2)
	_check(
		camera.get_ray_intersection(root.get_visible_rect().size / 2).distance_to(map_center) < 0.1,
		"Scaled minimap click moved camera to wrong point"
	)
	camera.set_position_safely(point)
	var projected = camera.unproject_position(point)
	var hit = camera.get_ray_intersection(projected)
	_check(hit != null and hit.distance_to(point) < 0.1, "Scaled camera projection mismatch")
	await _click(game.hud._attack_button)
	_check(game.hud._attack_armed, "Scaled mouse missed Attack move")
	await _physical_click(projected)
	_check(not game.hud._attack_armed, "Scaled map target was not accepted")
	_check(
		(
			not tank.manual_orders.pending.is_empty()
			and tank.manual_orders.pending[0].kind == "attack_move"
		),
		"Scaled target lost order"
	)
	if not tank.manual_orders.pending.is_empty():
		_check(
			tank.manual_orders.pending[0].point.distance_to(point) < 0.1,
			"Scaled click ordered wrong world point"
		)
	var panel = game.hud.alert_panel
	await _click(panel.toggle)
	_check(panel.panel.visible, "Scaled mouse missed Alerts")
	_inside(panel.panel, "Alert history")
	await _shot("interface-%s-%d-720p" % [faction, roundi(factor * 100)])
	await _key(KEY_ESCAPE)
	var caption = game.subtitles._card
	game.subtitles._on_line({"speaker": "Command", "text": "Our base is under attack."})
	await _frames(5)
	_inside(caption, "Subtitles")
	_check(
		not caption.get_global_rect().intersects(menus.get_global_rect()),
		"Scaled subtitles cover commands"
	)
	await _shot("interface-battle-%s-%d-720p" % [faction, roundi(factor * 100)])
	await manager_dialog_check()
	await _frames(5)
	var dialog = root.get_node("SaveManager").dialog
	if is_instance_valid(dialog):
		for control in dialog.find_children("*", "Button", true, false):
			if control.is_visible_in_tree():
				_inside(control, "Archive action")
		await _key(KEY_ESCAPE)
		_check(not is_instance_valid(root.get_node("SaveManager").dialog), "Archive did not close")
	print("PASS: ", faction, " ", factor, " battle panels, map target, alerts, archive")


func manager_dialog_check():
	await root.get_node("SaveManager").open_dialog("save")
	_check(is_instance_valid(root.get_node("SaveManager").dialog), "Archive did not open")


func _scale_settings():
	var globals = root.get_node("Globals")
	var dialog = globals.open_settings()
	dialog.save_path = archive
	await _frames(5)
	_inside(dialog._panel, "Settings")
	var clock = game.simulation_time
	dialog._preview("interface_scale", 1.0)
	await _frames(5)
	dialog.controls.interface_scale.grab_focus()
	await _key(KEY_SPACE)
	_check(dialog.controls.interface_scale.get_popup().visible, "Interface dropdown did not open")
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(5)
	_check(preferences.interface_scale == 1.5, "Interface dropdown keyboard selection failed")
	_inside(dialog._panel, "Large settings")
	await _shot("interface-settings-150-720p")
	await _click(dialog._save)
	_check(not is_instance_valid(globals.settings_dialog), "Scaled Save missed")
	_check(paused and game.simulation_time == clock, "Scaling changed battle pause/clock")
	dialog = globals.open_settings()
	await _frames(5)
	dialog._preview("interface_scale", 1.25)
	await _frames(3)
	await _click(_named_button(dialog, "Reset defaults"))
	_check(
		preferences.interface_scale == 1.0 and root.content_scale_factor == 1.0,
		"Reset defaults did not reset scale"
	)
	await _key(KEY_ESCAPE)
	_check(
		preferences.interface_scale == 1.5 and root.content_scale_factor == 1.5,
		"Cancel did not restore scale"
	)
	print("PASS: scale dropdown, Save, Cancel and paused battle isolation")


func _inside(control, label):
	if control is Control and control.is_visible_in_tree():
		_check(
			root.get_visible_rect().grow(1).encloses(control.get_global_rect()),
			label + " outside viewport"
		)


func _click(control):
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames(3)
		ancestor = ancestor.get_parent()
	await _physical_click(control.get_global_rect().get_center())


func _physical_click(point):
	# Supply window coordinates so Godot performs the actual stretch/input transform.
	var window_point = root.get_final_transform() * point
	var motion = InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	root.push_input(motion, false)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = window_point
		event.global_position = window_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)


func _shot(title):
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(root.size == expected_pixels, "Window changed size during capture: " + title)
	_check(frame.get_size() == expected_pixels, "UI scaling changed render resolution: " + title)
	frame.save_png("res://art/skirmish/%s.png" % title)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)


func _menu_screens():
	preferences.interface_scale = 1.5
	preferences.apply()
	for title in ["Main", "Play", "Campaign"]:
		var menu = load("res://source/main-menu/%s.tscn" % title).instantiate()
		root.add_child(menu)
		current_scene = menu
		await _frames(8)
		for button in menu.find_children("*", "Button", true, false):
			_inside(button, title + " button " + button.text)
		await _shot("interface-%s-150-720p" % title.to_lower())
		menu.queue_free()
		await _frames(4)
	print("PASS: main menu, skirmish setup and campaign at 150%")


func _larger_windows():
	if DisplayServer.get_name() != "headless":
		await _settle_window(DisplayServer.WINDOW_MODE_WINDOWED)
	for dimensions in [Vector2i(1440, 900), Vector2i(1920, 1080)]:
		expected_pixels = dimensions
		root.size = dimensions
		await _frames(15)
		_check(root.size == dimensions, "Window resize did not settle")
		var dialog = root.get_node("Globals").open_settings()
		await _frames(6)
		_inside(dialog._panel, "Large-window settings")
		await _shot("interface-settings-150-%dp" % dimensions.y)
		await _click(dialog._cancel)
		_inside(game.find_child("UnitMenus"), "Large-window commands")
		await _shot("interface-battle-150-%dp" % dimensions.y)
	expected_pixels = Vector2i(1280, 720)
	root.size = expected_pixels
	await _frames(10)
	_check(root.size == Vector2i(1280, 720), "720p window did not settle")
	print("PASS: 900p and 1080p settings, battle controls and rendering resolution")


func _campaign_scale():
	path = "user://interface-campaign-%d.json" % OS.get_process_id()
	await _make_match()
	game.hud._toggle_pause()
	var human = game._get_human_player()
	_units(human, "CommandCenter")[0].get_node("Selection").select()
	await _frames(8)
	_inside(game.hud.lesson_panel, "Campaign lesson")
	_inside(game.find_child("UnitMenus"), "Campaign commands")
	var marker = game.hud._relay_marker
	_check(
		marker.get_parent().layer < game.get_node("HUD").layer, "Relay marker draws over commands"
	)
	_check(
		not marker.visible or root.get_visible_rect().encloses(marker.get_rect()),
		"Relay label clips at window edge"
	)
	await _shot("interface-campaign-battle-150-720p")
	await _click(_named_button(game.hud.lesson_panel, "View relay"))
	_check(marker.visible, "View relay did not reveal its map label")
	_inside(marker, "Relay map label")
	await _shot("interface-relay-150-720p")
	game.result = "Victory"
	game.finished = true
	game.hud.show_result("First Orders · Victory")
	await _frames(5)
	for button in game.hud._overlay.find_children("*", "Button", true, false):
		_inside(button, "Result action")
	await _shot("interface-result-150-720p")
	await _clean_match()
	DirAccess.remove_absolute(path)
	print("PASS: campaign lesson and result at 150%")
