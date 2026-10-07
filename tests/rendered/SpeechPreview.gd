extends "res://tests/headless/SpeechRegression.gd"

var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 120000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Speech preview exceeded wall-time deadline")
		quit(1)
	return false


func _run():
	var manager = root.get_node("SaveManager")
	var original_directory = manager.slots.directory
	var original_autosaves = manager.autosaves_enabled
	manager.slots.directory = "user://speech-preview-slots-%d" % OS.get_process_id()
	manager.autosaves_enabled = false
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	archive = "user://speech-preview-%d.tres" % OS.get_process_id()
	path = "user://speech-campaign-%d.json" % OS.get_process_id()
	preferences.restore({"screen": 1, "edge_scrolling": false, "subtitle_size": 26})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _settings_preview()
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		_attach_voice()
		await _capture("speech-opening-" + faction)
		await _battle_preview(faction)
		await _clean_match()
	await _make_match()
	_attach_voice()
	game.hud._toggle_pause()
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	await _capture("speech-campaign-720p")
	_check(
		not game.subtitles._card.get_global_rect().intersects(
			game.hud.lesson_panel.get_global_rect()
		),
		"Caption overlaps campaign lesson"
	)
	game.result = "Victory"
	game.finished = true
	game.hud.show_result("First Orders · Victory")
	await _capture("speech-result-720p")
	_check(
		voice.current.get("event") == EVENTS.MATCH_FINISHED_WITH_VICTORY,
		"Campaign result did not display spoken victory"
	)
	await _clean_match()
	preferences.restore(original)
	DirAccess.remove_absolute(manager.slots.directory)
	manager.slots.directory = original_directory
	manager.autosaves_enabled = original_autosaves
	DirAccess.remove_absolute(archive)
	DirAccess.remove_absolute(path)
	print("Speech UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _settings_preview():
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(10)
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = archive
	await _frames(6)
	# Actual keyboard navigation changes text size; mouse toggles visibility.
	dialog.controls.subtitle_size.grab_focus()
	await _key(KEY_SPACE)
	var popup = dialog.controls.subtitle_size.get_popup()
	_check(popup.visible, "Subtitle size keyboard did not open menu")
	await _key(KEY_UP)
	await _key(KEY_UP)
	await _key(KEY_ENTER)
	_check(preferences.subtitle_size == 18, "Size keyboard control did not select Small")
	await _key(KEY_SPACE)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(preferences.subtitle_size == 26, "Size keyboard control did not select Large")
	await _click(dialog.controls.subtitles)
	_check(not preferences.subtitles, "Subtitle checkbox did not turn off")
	await _click(dialog.controls.subtitles)
	var buttons = dialog.find_children("*", "Button", true, false)
	var effects_sample = buttons.filter(func(button): return button.text == "Test combat sound")[0]
	await _click(effects_sample)
	_check(dialog._effects_sample.playing, "Combat sample button did not play")
	var sample = buttons.filter(func(button): return button.text == "Test voice and subtitles")[0]
	await _click(sample)
	_check(
		dialog._sample.playing and dialog._sample_caption.visible,
		"Audio/subtitle sample did not play together"
	)
	await _capture_settings(dialog)
	await _click(dialog._save)
	var saved = ResourceLoader.load(archive, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(saved.subtitles and saved.subtitle_size == 26, "Rendered Save lost subtitle options")
	menu.queue_free()
	await _frames(4)


func _battle_preview(faction):
	var human = game._get_human_player()
	var hq = _units(human, "CommandCenter")[0]
	var tank = _units(human, "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(30, 0, 30))
	camera.set_size_safely(22)
	game.hud._toggle_pause()
	hq.get_node("Selection").select()
	var worker_scene = load("res://source/match/units/Worker.tscn")
	hq.production_queue.produce(worker_scene)
	hq.production_queue.produce(worker_scene)
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	await _capture("speech-production-" + faction)
	var menu = game.find_child("UnitMenus")
	_check(
		not game.subtitles._card.get_global_rect().intersects(menu.get_global_rect()),
		"Largest caption overlaps production/selection controls"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in _units(human, "Tank"):
		unit.get_node("Selection").select()
	_reset_speech()
	voice.say(EVENTS.UNIT_UNDER_ATTACK)
	await _capture("speech-group-" + faction)
	_check(
		not game.subtitles._card.get_global_rect().intersects(menu.get_global_rect()),
		"Largest caption overlaps group controls"
	)
	# A right-click through the caption reaches the actual battlefield command path.
	var point = game.subtitles._card.get_global_rect().get_center()
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
	_check(not tank.manual_orders.pending.is_empty(), "Caption swallowed battlefield right-click")
	# Both muted buses keep the same timed caption. Tactical pause advances speech only.
	preferences.master_volume = 0
	preferences.voice_volume = 0
	preferences.apply()
	_reset_speech()
	voice.say(EVENTS.UNIT_ACK_2)
	var clock = game.simulation_time
	var before_position = voice._audio.get_playback_position()
	await _frames(18)
	_check(
		game.subtitles._card.visible and voice._audio.get_playback_position() > before_position,
		"Paused muted speech did not advance audio/caption presentation"
	)
	_check(game.simulation_time == clock, "Paused speech advanced battle")
	var manager = root.get_node("SaveManager")
	await manager.open_dialog()
	await _frames(3)
	var remaining = voice._remaining
	var audio_position = voice._audio.get_playback_position()
	await _frames(20)
	_check(
		(
			is_equal_approx(voice._remaining, remaining)
			and absf(voice._audio.get_playback_position() - audio_position) < 0.08
		),
		"Archive modal desynchronized caption and audio"
	)
	manager.close_dialog()
	await _frames(180)
	_check(
		voice.current.is_empty() and not game.subtitles._card.visible,
		"Real-time subtitle did not expire after playback/read time"
	)
	preferences.master_volume = 0.8
	preferences.voice_volume = 0.8
	preferences.apply()
	# Live controls preview/Cancel restores caption size and visibility in battle.
	_reset_speech()
	voice.say(EVENTS.BASE_UNDER_ATTACK)
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = archive
	await _frames(5)
	await _click(dialog.controls.subtitles)
	_check(not game.subtitles._card.visible, "Live setting did not hide frozen caption")
	await _click(dialog._cancel)
	_check(
		game.subtitles._card.visible and preferences.subtitle_size == 26 and paused,
		"Battle Cancel lost caption/pause rollback"
	)
	await _capture("speech-paused-" + faction)
	if faction == "bastion":
		root.size = Vector2i(1440, 900)
		root.content_scale_size = root.size
		await _capture("speech-wide-900p")
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size


func _capture(title):
	await _frames(4)
	var rect = game.subtitles._card.get_global_rect()
	var viewport = root.get_visible_rect()
	_check(viewport.encloses(rect), "Caption exceeds viewport: " + title + " " + str(rect))
	_check(game.subtitles._card._text.get_line_count() <= 3, "Caption wraps beyond readable limit")
	_check(
		(
			game.subtitles._card._text.get_visible_line_count()
			== game.subtitles._card._text.get_line_count()
		),
		"Caption text clipped"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _capture_settings(dialog):
	await _frames(4)
	_check(
		root.get_visible_rect().encloses(dialog._panel.get_global_rect()),
		"Speech settings exceed 720p"
	)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/speech-settings-720p.png")


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
		Input.parse_input_event(event)
		await _frames(3)
