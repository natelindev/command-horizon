extends CanvasLayer

signal closed

var options
var save_path = ""
var controls = {}
var key_panel
var _initial = {}
var _frozen = []
var _scene
var _was_paused = false
var _focus
var _closing = false
var _window_mode = DisplayServer.WINDOW_MODE_WINDOWED
var _panel
var _status
var _sample
var _effects_sample
var _ambience_sample
var _ambience_test
var _sample_caption
var _sample_left = 0.0
var _save
var _cancel
var _tabs


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	_initial = options.capture()
	_window_mode = options.display_mode()
	_scene = get_tree().current_scene
	_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	get_tree().paused = true
	if is_instance_valid(_scene):
		_freeze(_scene)
		_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var shade = ColorRect.new()
	shade.color = Color("080e17ed")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 680
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19232f")
	style.set_corner_radius_all(10)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 22)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_label(column, "SETTINGS", 25)
	_label(column, "Preview changes · Save to keep them · Esc to cancel", 14)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(680, 480)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	var general_scroll = ScrollContainer.new()
	general_scroll.name = "General"
	general_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	general_scroll.follow_focus = true
	_tabs.add_child(general_scroll)
	var general = VBoxContainer.new()
	general.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	general.add_theme_constant_override("separation", 6)
	general_scroll.add_child(general)
	_heading(general, "Audio")
	_slider(general, "Master volume", "master_volume", 0, 1, 0.05)
	_slider(general, "Voice volume", "voice_volume", 0, 1, 0.05)
	_slider(general, "Effects volume", "effects_volume", 0, 1, 0.05)
	_effects_sample = AudioStreamPlayer.new()
	_effects_sample.bus = "Effects"
	_effects_sample.stream = load("res://assets/audio/combat/cannon_fire.wav")
	_effects_sample.volume_db = -10.0
	add_child(_effects_sample)
	_button(general, "Test combat sound", func(): _effects_sample.play())
	_slider(general, "Ambience volume", "ambience_volume", 0, 1, 0.05)
	_ambience_sample = AudioStreamPlayer.new()
	_ambience_sample.bus = "Ambience"
	_ambience_sample.stream = load("res://assets/audio/environment/sample.wav")
	_ambience_sample.volume_db = -6.0
	add_child(_ambience_sample)
	_ambience_test = _button(general, "Test ambience", _test_ambience)
	_ambience_sample.finished.connect(func(): _ambience_test.text = "Test ambience")
	_sample = AudioStreamPlayer.new()
	_sample.bus = "Voice"
	_sample.stream = load(
		"res://assets/voice/english/ttsmaker-com-148-alayna-us/battle_control_online.ogg"
	)
	add_child(_sample)
	_check(general, "Show speech subtitles", "subtitles")
	var subtitle_row = _row(general, "Subtitle size")
	var subtitle_size = OptionButton.new()
	for title in ["Small", "Standard", "Large"]:
		subtitle_size.add_item(title)
	subtitle_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_size.item_selected.connect(func(index): _preview("subtitle_size", [18, 22, 26][index]))
	subtitle_row.add_child(subtitle_size)
	controls.subtitle_size = subtitle_size
	_button(general, "Test voice and subtitles", _test_voice)
	_sample_caption = load("res://source/match/hud/SubtitleCard.gd").new()
	general.add_child(_sample_caption)
	_sample_caption.hide()
	_heading(general, "Camera")
	_slider(general, "Pan speed", "camera_speed", 0.5, 2.0, 0.1)
	_slider(general, "Zoom speed", "zoom_speed", 0.5, 3.0, 0.1)
	_check(general, "Scroll at screen edges", "edge_scrolling")
	_check(general, "Keep pointer inside the game window", "mouse_restricted")
	_heading(general, "Display")
	var symbols = _check(general, "Show unit ownership symbols", "ownership_symbols")
	symbols.tooltip_text = (
		"● Your forces · ▲ Opponent. Hover a unit for its owner. "
		+ "Minimap shapes remain visible."
	)
	var scale_row = _row(general, "Interface size")
	var interface_scale = OptionButton.new()
	for title in ["100%", "125%", "150%"]:
		interface_scale.add_item(title)
	interface_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interface_scale.tooltip_text = "Resize menus, text, and battle controls."
	interface_scale.item_selected.connect(
		func(index): _preview("interface_scale", [1.0, 1.25, 1.5][index])
	)
	scale_row.add_child(interface_scale)
	controls.interface_scale = interface_scale
	var row = _row(general, "Window mode")
	var screen = OptionButton.new()
	screen.add_item("Fullscreen")
	screen.add_item("Windowed")
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.item_selected.connect(func(index): _preview("screen", index))
	row.add_child(screen)
	controls.screen = screen
	var flashes = _check(general, "Reduce bright combat flashes", "reduced_flashes")
	flashes.tooltip_text = "Reduce flashes and sparks. Keep shot trails and charge warnings."
	key_panel = load("res://source/main-menu/KeyBindingsPanel.gd").new()
	key_panel.name = "Controls"
	key_panel.dialog = self
	_tabs.add_child(key_panel)
	_tabs.tab_changed.connect(func(_index): key_panel.cancel_capture())
	_status = _label(column, "", 13)
	_status.custom_minimum_size.y = 36
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_save = _button(actions, "Save & back", func(): _finish(true))
	_cancel = _button(actions, "Cancel [Esc]", func(): _finish(false))
	_button(actions, "Reset defaults", _defaults)
	_refresh()
	controls.master_volume.grab_focus()


func _heading(parent, title):
	parent.add_child(HSeparator.new())
	_label(parent, title, 16)


func _test_ambience():
	if _ambience_sample.playing:
		_ambience_sample.stop()
		_ambience_test.text = "Test ambience"
	else:
		_ambience_sample.play()
		_ambience_test.text = "Stop ambience sample"


func _row(parent, title):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label = _label(row, title, 14)
	label.custom_minimum_size.x = 165
	return row


func _slider(parent, title, key, low, high, step):
	var row = _row(parent, title)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(280, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = title
	row.add_child(slider)
	var value = _label(row, "", 14)
	value.custom_minimum_size.x = 55
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(amount): _preview(key, amount))
	controls[key] = slider
	controls[key + "_value"] = value


func _check(parent, title, key):
	var checkbox = CheckBox.new()
	checkbox.text = title
	checkbox.add_theme_font_size_override("font_size", 14)
	checkbox.toggled.connect(func(value): _preview(key, value))
	parent.add_child(checkbox)
	controls[key] = checkbox
	return checkbox


func _button(parent, title, callback):
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent, title, font_size):
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _preview(key, value):
	options.set(key, value)
	options.apply()
	_status.text = "Changes previewed — not saved yet."
	_refresh()


func _defaults():
	key_panel.cancel_capture()
	options.restore(options.DEFAULTS)
	_status.text = "Defaults previewed — Save to keep them."
	_refresh()


func _refresh():
	if is_instance_valid(key_panel):
		key_panel.refresh()
	controls.screen.select(options.screen)
	controls.interface_scale.select([1.0, 1.25, 1.5].find(options.interface_scale))
	controls.subtitle_size.select([18, 22, 26].find(options.subtitle_size))
	_sample_caption.visible = options.subtitles and _sample_left > 0
	_sample_caption.set_line("Command", "Battle control online.", options.subtitle_size)
	for key in [
		"master_volume",
		"voice_volume",
		"effects_volume",
		"ambience_volume",
		"camera_speed",
		"zoom_speed"
	]:
		controls[key].set_value_no_signal(options.get(key))
		controls[key + "_value"].text = "%d%%" % roundi(options.get(key) * 100)
	for key in [
		"edge_scrolling", "mouse_restricted", "reduced_flashes", "subtitles", "ownership_symbols"
	]:
		controls[key].set_pressed_no_signal(options.get(key))


func _finish(save):
	if _closing:
		return
	if save and options.persist(save_path) != OK:
		_status.text = "Could not save settings. Retry or Cancel to restore your previous settings."
		return
	if not save:
		_rollback()
	_closing = true
	_thaw()
	if Globals.settings_dialog == self:
		Globals.settings_dialog = null
	closed.emit()
	queue_free()


func _freeze(node):
	_frozen.append({"node": node, "mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_INHERIT
	for child in node.get_children():
		_freeze(child)


func _thaw():
	for entry in _frozen:
		if is_instance_valid(entry.node):
			entry.node.process_mode = entry.mode
	_frozen.clear()
	if is_instance_valid(_scene) and get_tree().current_scene == _scene:
		get_tree().paused = _was_paused
	if is_instance_valid(_focus) and _focus.is_inside_tree():
		_focus.grab_focus()


func _exit_tree():
	if not _closing:
		_rollback()
		_thaw()
	if Globals.settings_dialog == self:
		Globals.settings_dialog = null


func _rollback():
	options.restore(_initial)
	options.request_display(_window_mode)


func _input(event):
	if is_instance_valid(key_panel) and key_panel.handle_key(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish(false)


func _unhandled_input(_event):
	get_viewport().set_input_as_handled()


func _test_voice():
	_sample.play()
	_sample_left = maxf(3.0, _sample.stream.get_length() + 0.25)
	_refresh()


func _process(delta):
	if _sample_left > 0:
		_sample_left = maxf(0, _sample_left - delta / maxf(Engine.time_scale, 0.001))
		if _sample_left == 0:
			_sample_caption.hide()
