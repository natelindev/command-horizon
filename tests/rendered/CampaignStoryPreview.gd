extends "res://tests/headless/CampaignRegression.gd"


func _run():
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore(
		{"screen": 1, "edge_scrolling": false, "subtitles": true}
	)
	path = "user://campaign-story-preview-%d.json" % OS.get_process_id()
	await _make_match()
	var story = game.campaign_story
	_check(story.cinematic and paused, "Rendered campaign did not show animated intro")
	await _frames(5)
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("/tmp/campaign-story-en.png")
	var modal_rect = story._briefing.get_global_rect()
	_check(root.get_visible_rect().encloses(modal_rect), "Briefing clipped outside viewport")
	_check(story._subtitle._text.size.x > 400, "Narration text failed to wrap in readable space")
	root.get_node("Globals").options.language = "zh_CN"
	root.get_node("Globals").options.subtitle_size = 26
	root.get_node("Globals").options.interface_scale = 1.5
	root.get_node("Globals").options.apply()
	await _frames(5)
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("/tmp/campaign-story-zh.png")
	_check(
		root.get_visible_rect().encloses(story._briefing.get_global_rect()),
		"Chinese briefing clipped"
	)
	var point = story._skip.get_global_rect().get_center()
	for pressed in [true, false]:
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
	_check(not story.cinematic and not paused, "Mouse skip did not resume rendered game")
	await _result_cases("first_orders")
	game.queue_free()
	await _frames(5)
	paused = false
	await _horizon_match()
	var horizon_story = game.campaign_story
	_check(horizon_story.cinematic, "Horizon opening is missing")
	_mouse_click(horizon_story._skip.get_global_rect().get_center())
	await _frames(2)
	_check(not horizon_story.cinematic, "Horizon mouse skip failed")
	await _result_cases("command_horizon")
	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign story rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _horizon_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "command_horizon"
	settings.map_path = "res://source/match/maps/CommandHorizonMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if index == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load("res://source/match/campaign/CommandHorizon.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(5)


func _result_cases(mission):
	game.finished = true
	game.result = "Victory"
	for locale in ["en", "zh_CN"]:
		root.get_node("Globals").options.language = locale
		root.get_node("Globals").options.interface_scale = 1.5
		root.get_node("Globals").options.apply()
		game.hud.show_result("Victory")
		await _frames(5)
		var overlay = game.hud._overlay
		_check(overlay != null, "Result overlay failed to build: " + mission + locale)
		if overlay == null:
			return
		var details = overlay.find_child("DebriefScroll", true, false).get_child(0)
		var ending = load("res://source/match/campaign/CampaignNarration.gd").record(
			mission + ".victory", locale
		)
		_check(
			details.text.contains(ending.text),
			"Result debrief lost spoken story outro: " + mission + locale
		)
		var panel = overlay.find_children("*", "PanelContainer", true, false)[0]
		_check(
			root.get_visible_rect().encloses(panel.get_global_rect()),
			"Result panel clipped: " + mission + locale
		)
		for name in ["PlayAgainButton", "LoadButton", "SetupButton", "MainMenuButton"]:
			var button = overlay.find_child(name, true, false)
			_check(
				root.get_visible_rect().encloses(button.get_global_rect()),
				"Result action clipped: " + mission + locale + name
			)
		_check(
			overlay.find_child("PlayAgainButton", true, false).has_focus(),
			"Result action did not retain keyboard focus"
		)
		var scroll = overlay.find_child("ResultBodyScroll", true, false)
		var bar = scroll.get_v_scroll_bar()
		_check(bar.visible, "Long campaign debrief cannot scroll: " + mission + locale)
		bar.grab_focus()
		var before = bar.value
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_DOWN
			key.physical_keycode = KEY_DOWN
			key.pressed = pressed
			root.push_input(key, true)
		_check(bar.value > before, "Debrief keyboard scrolling failed: " + mission + locale)
		bar.value = 0
		overlay.find_child("PlayAgainButton", true, false).grab_focus()
		RenderingServer.force_draw(false)
		get_root().get_texture().get_image().save_png(
			"/tmp/campaign-story-%s-result-%s.png" % [mission, locale]
		)


func _mouse_click(point):
	for pressed in [true, false]:
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
