extends "res://tests/headless/CampaignControlsRegression.gd"


func _run():
	Engine.max_fps = 60
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://campaign-layout-%d.json" % OS.get_process_id()
	var catalog = load("res://source/match/campaign/CampaignCatalog.gd")
	for mission in catalog.OPERATIONS:
		var definition = catalog.OPERATIONS[mission]
		var settings = load("res://source/data-model/MatchSettings.gd").new()
		settings.skirmish = true
		settings.mission_id = mission
		settings.map_path = definition.map
		for index in 2:
			var side = load("res://source/data-model/PlayerSettings.gd").new()
			side.controller = index + 1
			side.faction = "bastion" if index == 0 else "helix"
			settings.players.append(side)
		game = load(definition.scene).instantiate()
		game.settings = settings
		game.map = load(definition.map).instantiate()
		game.progress_path = path
		root.add_child(game)
		current_scene = game
		await _frames(15)
		game.get_node("IsometricCamera3D").set_physics_process(false)
		var hud = game.hud
		hud._toggle_pause()
		await _frames(8)
		var panel = hud.get_child(0)
		var baseline = panel.get_global_rect()
		hud.show_notice("Checkpoint saved · Operation start")
		await _frames(8)
		_check(panel.get_global_rect() == baseline, mission + ": short notice resized commands")
		await _capture_controls(mission)
		var objectives = hud.objective_panel if "objective_panel" in hud else hud.lesson_panel
		var minimap_rect = game.find_child("Minimap").get_global_rect()
		_check(
			objectives.get_global_rect().end.y + 4 <= minimap_rect.position.y,
			mission + ": objectives overlap real minimap bounds"
		)
		print(
			"LAYOUT ",
			mission,
			" objective_bottom=",
			objectives.get_global_rect().end.y,
			" minimap_top=",
			minimap_rect.position.y
		)
		if "objective_panel" in hud:
			_check(
				hud.objective_panel.get_global_rect().end.y < 500,
				mission + ": objectives overlap minimap"
			)
			hud.show_notice("Long feedback remains available.\n".repeat(10))
			await _frames(8)
			_check(panel.get_global_rect() == baseline, mission + ": long notice resized commands")
			_check(
				hud._notice_slot.get_v_scroll_bar().visible, mission + ": long notice cannot scroll"
			)
			if mission == "split_signal":
				await _capture_controls("split-long-notice")
				await _scroll_notice(hud)
			hud._hint_left = 0.001
			await _frames(8)
			_check(
				panel.get_global_rect() == baseline, mission + ": expired notice resized commands"
			)
			if mission == "split_signal":
				await _capture_controls("split-expired-notice")
		await _cleanup()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign controls preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture_controls(title):
	await RenderingServer.frame_post_draw
	var capture = root.get_texture().get_image()
	_check(capture.get_size() == Vector2i(1280, 720), "Wrong capture size")
	capture.save_png("res://art/skirmish/campaign-controls-%s-720p.png" % title)


func _scroll_notice(hud):
	var point = hud._notice_slot.get_global_rect().get_center()
	for pressed in [true, false]:
		var wheel = InputEventMouseButton.new()
		wheel.position = point
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = pressed
		root.push_input(wheel, true)
	await _frames(3)
	_check(hud._notice_slot.scroll_vertical > 0, "Mouse wheel cannot read long notice")
	var bar = hud._notice_slot.get_v_scroll_bar()
	bar.grab_focus()
	var before = bar.value
	for pressed in [true, false]:
		var key = InputEventKey.new()
		key.keycode = KEY_DOWN
		key.physical_keycode = KEY_DOWN
		key.pressed = pressed
		root.push_input(key, true)
	await _frames(3)
	_check(bar.value > before, "Keyboard cannot read long notice")
