extends "res://tests/rendered/LuaEditorPreview.gd"


func _run():
	Engine.max_fps = 60
	create_timer(70).timeout.connect(
		func():
			push_error("Arena UI timed out")
			quit(1)
	)
	var options = root.get_node("Globals").options
	var initial = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5})
	await _settle_window()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var record = load("res://source/match/programs/ProgramRecord.gd")
	var rules = load("res://source/match/programs/VisualRules.gd")
	var directory = ProjectSettings.globalize_path("user://arena-ui-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("request.json")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"token": "0123456789abcdef0123456789abcdef",
				"faction": "helix",
				"research":
				{
					"coordination": true,
					"completed":
					["weapons_1", "weapons_2", "armor_1", "armor_2", "service", "doctrine"]
				},
				"record": record.visual("Guard review", 1, rules.starter(1), ["Tank", "Helicopter"])
			}
		)
	)
	file.close()
	var arena = load("res://source/match/programs/arena/ArenaWindow.gd").new()
	arena.request_path = path
	# The child arena must override the main window's pending fullscreen preference.
	options.request_display(DisplayServer.WINDOW_MODE_FULLSCREEN)
	root.add_child(arena)
	current_scene = arena
	await _settle_window()
	_check(
		options.display_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Arena kept fullscreen target"
	)
	await _frames(5)
	_check(arena._run_button.get_global_rect().end.x <= 1280, "Arena controls overflow")
	_check(arena._trace.get_global_rect().end.y <= 680, "Arena trace clips at 720p")
	await _capture("arena-research-ready-720p")
	await _click(arena._run_button)
	_check(arena.session.running or arena.session.starting, "Research arena Run input failed")
	print("ARENA RUN ", arena.session.running, " ", arena.session.starting)
	if not arena.session.running and not arena.session.starting:
		await _capture("arena-research-input-failure")
		options.restore(initial)
		quit(1)
		return
	await _frames(80)
	_check(
		is_equal_approx(arena.session.subject.hp_max, arena.session.subject.base_hp_max * 1.2),
		"Arena UI omitted upgraded armor"
	)
	_check(arena.session.game.subtitles == null, "Voiceless arena attached battle subtitles")
	await _click(arena._pause_button)
	var time = arena.session.elapsed
	var position = arena.session.subject.position
	var evaluations = arena.session.evaluations
	await _frames(40)
	_check(arena.session.elapsed == time, "Paused arena timer advanced")
	_check(arena.session.subject.position == position, "Paused arena unit moved")
	_check(arena.session.evaluations == evaluations, "Paused arena Lua advanced")
	await _capture("arena-research-paused-720p")
	arena._pause_button.grab_focus()
	_key(KEY_SPACE)
	await _frames(3)
	_check(not arena._paused, "Keyboard resume failed")
	await arena.session.completed
	await _frames(3)
	_check(arena.session.outcome.passed, "Rendered retreat did not pass")
	_check(
		"PASS" in arena._trace.text and "ACTUAL TRACE" in arena._trace.text,
		"Arena lost outcome/trace"
	)
	await _capture("arena-research-result-720p")
	# Choose the baseline with native keyboard input; research must reset on restart.
	arena._research.grab_focus()
	_key(KEY_ENTER)
	await _frames(3)
	var popup = arena._research.get_popup()
	_check(popup.visible, "Research selector did not open")
	print("POPUP focus=", popup.get_focused_item(), " embedded=", popup.is_embedded())
	for code in [KEY_DOWN, KEY_ENTER]:
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.pressed = pressed
			if popup.is_embedded():
				Input.parse_input_event(event)
			else:
				popup.push_input(event, true)
		await _frames(3)
		print("POPUP after=", popup.get_focused_item(), " selected=", arena._research.selected)
	_check(arena._research.selected == 1, "Keyboard did not select baseline")
	_check("No completed research" in arena._research_summary.text, "Baseline summary stale")
	# Restart produces fresh memory/time, not a continuation of the earlier run.
	await _click(arena._run_button)
	await _frames(15)
	_check(
		arena.session.elapsed < 1.0 and arena.session.evaluations < evaluations + 5,
		"Restart reused prior state"
	)
	_check(
		arena.session.subject.hp_max == arena.session.subject.base_hp_max,
		"Baseline restart retained armor"
	)
	await _capture("arena-research-baseline-720p")
	# A user can return while a case is still running; completed results remain bounded.
	_check(arena.results.size() == 1, "Restart discarded completed results")
	arena.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory.path_join("ready"))
	DirAccess.remove_absolute(directory)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			"PASS: researched arena input, baseline comparison, pause/restart, evidence and 720p layout"
		)
	options.restore(initial)
	quit(0 if _errors.is_empty() else 1)


func _settle_window():
	var started = Time.get_ticks_msec()
	var matched_since = -1
	while Time.get_ticks_msec() - started < 6000:
		await process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			matched_since = -1
		elif matched_since < 0:
			matched_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - matched_since > 1800:
			return
	_check(false, "Arena did not settle into windowed mode")


func _capture(title):
	await _frames(4)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(root.size == Vector2i(1280, 720), "Arena window is not 720p")
	_check(frame.get_size() == Vector2i(1280, 720), "Arena render resolution changed")
	frame.save_png("res://art/skirmish/%s.png" % title)
	print("ARENA CAPTURE ", title)


func _click(control):
	var point = control.get_global_rect().get_center()
	DisplayServer.window_move_to_foreground()
	Input.warp_mouse(point)
	await _frames(5)
	print(
		"CLICK ",
		control.text,
		" rect=",
		control.get_global_rect(),
		" final=",
		root.get_final_transform(),
		" viewport=",
		root.get_visible_rect(),
		" disabled=",
		control.disabled
	)
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await _frames(2)
	print("HOVER ", root.gui_get_hovered_control())
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
