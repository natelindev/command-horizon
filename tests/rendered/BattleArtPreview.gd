extends "res://tests/rendered/InterfaceScalePreview.gd"

const EVIDENCE = "res://art/battle-ui-v2/"


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 600000
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	if "--gallery" in OS.get_cmdline_user_args():
		_gallery.call_deferred()
	else:
		_run.call_deferred()


func _setup(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn")
	for side in get_nodes_in_group("players"):
		if side != game._get_human_player():
			side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)


func _battle_scale(faction, factor):
	await super._battle_scale(faction, factor)
	await _command_tabs()
	var locale = TranslationServer.get_locale()
	for language in ["en", "zh_CN"]:
		TranslationServer.set_locale(language)
		await _frames(6)
		await _click(game.hud._technology_button)
		await _frames(6)
		var panel = game.hud._technology_scroll.get_parent().get_parent()
		_inside(panel, "Artwork technology dialog " + language)
		_inside(game.hud._technology_scroll, "Artwork technology scroll " + language)
		await _shot("technology-%s-%s-%d" % [faction, language, roundi(factor * 100)])
		await _key(KEY_ESCAPE)
		_check(game.hud._overlay == null and paused, "Technology lost battle pause state")
		await _click(game.hud._menu_button)
		await _frames(6)
		_check_pause()
		await _shot("pause-%s-%s-%d" % [faction, language, roundi(factor * 100)])
		var controls = _named_button(game.hud._overlay, "Controls")
		await _click(controls)
		_check(game.hud._menu_help.visible, "Pause controls disclosure did not open")
		_inside(game.hud._menu_help, "Expanded control reference")
		await _click(controls)
		_check(not game.hud._menu_help.visible, "Pause controls disclosure did not close")
		await _key(KEY_ESCAPE)
		_check(game.hud._overlay == null and paused, "Pause menu lost prior pause state")
	TranslationServer.set_locale(locale)


func _check_pause():
	for button in game.hud._overlay.find_children("*", "Button", true, false):
		_inside(button, "Artwork pause action")
	var title = game.hud._overlay.find_child("ArtworkHeader", true, false).get_child(0)
	var width = (
		title
		. get_theme_font("font")
		. get_string_size(
			title.tr(title.text),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			title.get_theme_font_size("font_size")
		)
		. x
	)
	_check(width <= title.size.x, "Pause heading was truncated")


func _command_tabs():
	var menus = game.find_child("UnitMenus")
	var selection = menus._selection.duplicate()
	var tabs = menus._pages.get_tab_bar()
	menus._scroll.ensure_control_visible(tabs)
	await _frames(3)
	for index in menus._pages.get_tab_count():
		await _physical_click(tabs.global_position + tabs.get_tab_rect(index).get_center())
		_check(menus._pages.current_tab == index, "Command tab click missed")
		_check(menus._selection == selection, "Command tab changed unit selection")
		_inside(menus, "Command tab panel")
	var current = menus._pages.current_tab
	menus._reset_menus()
	await _frames(5)
	_check(menus._pages.current_tab == current, "Command rebuild lost the active tab")
	tabs = menus._pages.get_tab_bar()
	tabs.grab_focus()
	await _key(KEY_LEFT)
	_check(menus._pages.current_tab == maxi(0, current - 1), "Keyboard tab navigation failed")
	menus._pages.current_tab = 0
	await _frames(5)
	print("PASS: command tabs, selection stability, rebuild and keyboard navigation")


func _shot(title):
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == expected_pixels, "Artwork changed render resolution: " + title)
	frame.save_png(EVIDENCE + title + ".png")


func _gallery():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore(
		{"screen": 1, "interface_scale": 1.25, "edge_scrolling": false, "language": "zh_CN"}
	)
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	expected_pixels = root.size
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	await _setup("frontier")
	print("ART GALLERY MAP: ", game.settings.map_path, " / ", game.map.get_script().resource_path)
	_check(game.map.get_script().resource_path.ends_with("CoastalFoundry.gd"), "Wrong gallery map")
	game.hud._toggle_pause()
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(22, 0, 33))
	camera.set_size_safely(38)
	for role in ["Worker", "Tank", "VehicleFactory"]:
		root.get_node("MatchSignals").deselect_all_units.emit()
		_units(human, role)[0].get_node("Selection").select()
		await _frames(12)
		await _shot("gallery-" + role.to_lower())
		if role == "Tank":
			await _command_tabs()
	game.alerts.scan()
	game.simulation_time += 7
	game.alerts.scan()
	await _click(game.hud.alert_panel.toggle)
	await _frames(8)
	await _shot("gallery-alerts")
	await _key(KEY_ESCAPE)
	game.hud._open_menu()
	await _frames(8)
	await _shot("gallery-pause")
	await _click(_named_button(game.hud._overlay, "Controls"))
	_check(game.hud._menu_help.visible, "Gallery controls disclosure missing")
	await _shot("gallery-controls")
	await _key(KEY_ESCAPE)
	game.hud.open_technology()
	await _frames(8)
	await _shot("gallery-technology")
	_inside(game.hud._technology_scroll.get_parent().get_parent(), "Gallery technology")
	await _key(KEY_ESCAPE)
	var tank = _units(human, "Tank")[0]
	game.hud.open_visual_editor([tank], "user://battle-art-gallery.json")
	await _frames(8)
	await _shot("gallery-rules")
	game.hud.program_editor.close_editor()
	await _frames(4)
	root.size = Vector2i(1280, 720)
	expected_pixels = root.size
	preferences.interface_scale = 1.5
	preferences.apply()
	root.get_node("MatchSignals").deselect_all_units.emit()
	_units(human, "Worker")[0].get_node("Selection").select()
	await _frames(10)
	var menus = game.find_child("UnitMenus")
	_inside(menus, "720p construction panel")
	_check(
		not game.hud.battle_plan.get_global_rect().intersects(
			game.find_child("Minimap").get_global_rect()
		),
		"720p battle plan overlaps the minimap"
	)
	for entry in menus._buttons:
		menus._scroll.ensure_control_visible(entry.button)
		await _frames(3)
		_inside(entry.button, "720p construction card")
	menus._scroll.scroll_vertical = 0
	await _frames(4)
	await _shot("gallery-worker-720p")
	game.hud._open_menu()
	await _frames(6)
	_check_pause()
	await _shot("gallery-pause-720p")
	await _click(_named_button(game.hud._overlay, "Controls"))
	_inside(game.hud._menu_help, "720p expanded control reference")
	await _key(KEY_ESCAPE)
	TranslationServer.set_locale("en")
	game.hud._open_menu()
	await _frames(6)
	_check_pause()
	await _shot("gallery-pause-en-720p")
	await _key(KEY_ESCAPE)
	await _click(game.hud.alert_panel.toggle)
	await _frames(6)
	await _shot("gallery-alerts-en-720p")
	await _key(KEY_ESCAPE)
	await _clean_match()
	manager.autosaves_enabled = autosaves
	preferences.restore(original)
	print("Battle art gallery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
