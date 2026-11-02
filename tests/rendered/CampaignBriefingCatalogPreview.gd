extends SceneTree

var failures := []
var checked := 0
var _rendered := false
var _catalog: Dictionary
var _narration: Script
var _scene: PackedScene
var _directory := ""
var _layouts := []


func _initialize():
	_run.call_deferred()


func _run():
	var arguments := OS.get_cmdline_user_args()
	_rendered = DisplayServer.get_name() != "headless"
	var matrix := "--layout-matrix" in arguments
	if not _rendered and "--layout-only" not in arguments:
		push_error("Use --layout-only for headless briefing geometry checks")
		quit(1)
		return
	if _rendered and matrix:
		push_error("The layout matrix requires --headless and --layout-only")
		quit(1)
		return
	var globals = root.get_node("Globals")
	root.get_node("SaveManager").autosaves_enabled = false
	var original = globals.options.capture()
	var options = original.duplicate(true)
	options.merge(
		{"screen": 1, "interface_scale": 1.5, "subtitle_size": 26, "subtitles": true}, true
	)
	globals.options.restore(options)
	if _rendered:
		root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	# Canvas scaling keeps physical PNG pixels while UI coordinates retain the
	# requested interface scale; VIEWPORT captures the smaller logical target.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Engine.max_fps = 120
	await _frames(30)
	root.size = Vector2i(1280, 720)
	_catalog = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/audio/campaign/briefings.json")
	)
	_narration = load("res://source/match/campaign/CampaignNarration.gd")
	_scene = load("res://source/match/campaign/CampaignBriefing.tscn")
	_directory = (
		"res://art/campaign-briefing-catalog" if _rendered else "user://campaign-briefing-catalog"
	)
	for argument in arguments:
		if argument.begins_with("--output-dir="):
			_directory = argument.trim_prefix("--output-dir=")
	_check(
		DirAccess.make_dir_recursive_absolute(_directory) == OK,
		"Cannot create briefing output directory: " + _directory
	)
	_check(_catalog.size() == 16, "Briefing review requires all16 missions")
	var scales := [1.0, 1.25, 1.5] if matrix else [1.5]
	var sizes := [18, 22, 26] if matrix else [26]
	for factor in scales:
		for font_size in sizes:
			globals.options.interface_scale = factor
			globals.options.subtitle_size = font_size
			for locale in ["en", "zh_CN"]:
				globals.options.language = locale
				globals.options.apply()
				await _frames(4)
				for id in _catalog:
					await _review_mission(id, locale, factor, font_size)
	_check(checked == 128 * scales.size() * sizes.size(), "Briefing review missed paragraphs")
	var file = FileAccess.open(
		_directory.path_join("layouts.json" if _rendered else "layouts-headless.json"),
		FileAccess.WRITE
	)
	_check(file != null, "Cannot write briefing layout evidence: " + _directory)
	if file != null:
		file.store_string(JSON.stringify(_layouts, "\t") + "\n")
		file.close()
	for failure in failures:
		push_error(failure)
	print(
		(
			"Briefing catalog %s: %d paragraphs, %d failures"
			% ["render" if _rendered else "headless layout", checked, failures.size()]
		)
	)
	var restored = original.duplicate(true)
	restored.screen = 1
	globals.options.restore(restored)
	globals.options.screen = original.screen
	await globals.quit_game(0 if failures.is_empty() else 1)


func _review_mission(id: String, locale: String, factor: float, font_size: int):
	if _rendered:
		await _settle_capture_window()
	var briefing = _scene.instantiate()
	root.add_child(briefing)
	briefing.duration = _catalog[id].duration
	briefing.configure(id)
	var lines = _narration.scene(id + ".briefing", locale)
	_check(lines.size() == 4, "Briefing must retain all four paragraphs: " + id + "/" + locale)
	var elapsed := 0.0
	var largest := -1.0
	var longest := -1
	var capture: Image
	for index in lines.size():
		var line = lines[index]
		briefing.caption.set_line(line.speaker, line.text, font_size)
		briefing.caption.set_caption_visible(true)
		briefing.seek(elapsed + _catalog[id].segments[index].duration * .5)
		await _frames(4)
		if _rendered:
			await RenderingServer.frame_post_draw
		_review_layout(briefing, line.id, locale, factor, font_size)
		var box: Rect2 = briefing.dialogue_panel.get_global_rect()
		if (
			box.size.y > largest
			or (is_equal_approx(box.size.y, largest) and line.text.length() > longest)
		):
			largest = box.size.y
			longest = line.text.length()
			if _rendered:
				capture = root.get_texture().get_image()
		elapsed += _catalog[id].segments[index].duration
	if _rendered:
		_check(
			capture != null and capture.get_size() == Vector2i(1280, 720),
			"Briefing capture has wrong raster"
		)
	if capture != null:
		_check(
			capture.save_png(_directory.path_join(id + "-" + locale + ".png")) == OK,
			"Cannot write briefing capture: " + id + "/" + locale
		)
	briefing.queue_free()
	await _frames(2)


func _review_layout(briefing, paragraph: String, locale: String, factor: float, font_size: int):
	var label: Label = briefing.caption._text
	var box: Rect2 = briefing.dialogue_panel.get_global_rect()
	var bounds: Rect2 = root.get_visible_rect()
	var objective_box: Rect2 = briefing.objectives.get_global_rect()
	var context := "%s/%s/scale%s/font%d" % [paragraph, locale, factor, font_size]
	var expected_size := Vector2(1280, 720) / factor
	_check(root.size == Vector2i(1280, 720), "Physical viewport changed: " + context)
	_check(bounds.size.is_equal_approx(expected_size), "Interface scale did not apply: " + context)
	_check(
		label.get_theme_font_size("font_size") == font_size,
		"Caption size did not apply: " + context
	)
	_check(bounds.encloses(box), "Dialogue outside viewport: " + context)
	_check(box.encloses(label.get_global_rect()), "Caption outside panel: " + context)
	_check(box.encloses(briefing.title_label.get_global_rect()), "Title outside panel: " + context)
	_check(label.get_minimum_size().y <= label.size.y + 1, "Caption vertically clipped: " + context)
	_check(
		label.get_visible_line_count() == label.get_line_count(), "Caption hides lines: " + context
	)
	_check(bounds.encloses(objective_box), "Objectives outside viewport: " + context)
	_check(
		briefing.objectives.get_minimum_size().y <= briefing.objectives.size.y + 1,
		"Objectives vertically clipped: " + context
	)
	_check(
		briefing.objectives.get_visible_line_count() == briefing.objectives.get_line_count(),
		"Objectives hide lines: " + context
	)
	_check(objective_box.end.y <= box.position.y + 1, "Objectives overlap dialogue: " + context)
	_check(
		box.encloses(briefing.skip_button.get_global_rect()), "Continue outside panel: " + context
	)
	_layouts.append(
		{
			"mission": briefing.mission_id,
			"locale": locale,
			"paragraph": paragraph,
			"interface_scale": factor,
			"subtitle_size": font_size,
			"logical_viewport": [bounds.size.x, bounds.size.y],
			"lines": label.get_line_count(),
			"caption_height": label.size.y,
			"panel_y": box.position.y,
			"panel_height": box.size.y,
			"objective_y": briefing.objectives.position.y,
			"objective_height": briefing.objectives.size.y,
			"objective_minimum": briefing.objectives.get_minimum_size().y,
			"objective_lines": briefing.objectives.get_line_count()
		}
	)
	checked += 1


func _settle_capture_window():
	# A native fullscreen transition can finish after the initial resize.
	var deadline := Time.get_ticks_msec() + 5000
	var stable_since := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1280, 720):
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			stable_since = Time.get_ticks_msec()
		if Time.get_ticks_msec() - stable_since >= 500:
			return
		await process_frame
	_check(false, "Physical briefing window did not stabilize at1280x720")


func _check(condition: bool, message: String):
	if not condition and message not in failures:
		failures.append(message)


func _frames(count: int):
	for index in count:
		await process_frame
