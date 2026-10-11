extends CanvasLayer

signal closed

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")

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
	shade.color = Color("080e1778")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = ArtTheme.create()
	_panel.custom_minimum_size.x = 680
	var style = StyleBoxFlat.new()
	style.bg_color = Color("0a1216f8")
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = Color("1e2f3bc8")
	for side in ["left", "right"]:
		style.set("content_margin_" + side, 22)
	for side in ["top", "bottom"]:
		style.set("content_margin_" + side, 16)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	var header_box = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	column.add_child(header_box)
	var tag = Label.new()
	tag.text = tr("// SYSTEM CONFIGURATION // TACTICAL SETTINGS")
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color("d8a846"))
	header_box.add_child(tag)
	_label(header_box, tr("SETTINGS"), 22)
	_label(
		header_box, tr("Preview changes · Save to keep them · Esc to cancel"), 13, Color("8ea0a8")
	)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(680, 480)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	var general_scroll = ScrollContainer.new()
	general_scroll.name = "General"
	general_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	general_scroll.follow_focus = true
	_tabs.add_child(general_scroll)
	_tabs.set_tab_title(0, tr("General"))
	var general = VBoxContainer.new()
	general.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	general.add_theme_constant_override("separation", 6)
	general_scroll.add_child(general)
	_heading(general, "Language")
	var language_row = _row(general, "Interface language")
	var language_choice = OptionButton.new()
	language_choice.add_item("English")
	language_choice.add_item("简体中文")
	language_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_choice.item_selected.connect(func(index): _preview("language", ["en", "zh_CN"][index]))
	language_row.add_child(language_choice)
	controls.language = language_choice
	_heading(general, "Audio")
	_slider(general, "Master volume", "master_volume", 0, 1, 0.05)
	_slider(general, "Music volume", "music_volume", 0, 1, 0.05)
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
	_ambience_sample.volume_db = load("res://source/match/audio/EnvironmentAudio.gd").BED_LEVEL
	add_child(_ambience_sample)
	_ambience_test = _button(general, "Test ambience", _test_ambience)
	_ambience_sample.finished.connect(func(): _ambience_test.text = tr("Test ambience"))
	_sample = AudioStreamPlayer.new()
	_sample.bus = "Voice"
	_sample.stream = load("res://assets/audio/voices/bastion/Command/MATCH_STARTED_0.ogg")
	add_child(_sample)
	_check(general, "Show speech subtitles", "subtitles")
	var subtitle_row = _row(general, "Subtitle size")
	var subtitle_size = OptionButton.new()
	for title in ["Small", "Standard", "Large"]:
		subtitle_size.add_item(tr(title))
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
	screen.add_item(tr("Fullscreen"))
	screen.add_item(tr("Windowed"))
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.item_selected.connect(func(index): _preview("screen", index))
	row.add_child(screen)
	controls.screen = screen
	var flashes = _check(general, "Reduce bright combat flashes", "reduced_flashes")
	flashes.tooltip_text = "Reduce flashes and sparks. Keep shot trails and charge warnings."
	_build_graphics()
	key_panel = load("res://source/main-menu/KeyBindingsPanel.gd").new()
	key_panel.name = "Controls"
	key_panel.dialog = self
	_tabs.add_child(key_panel)
	_tabs.set_tab_title(2, tr("Controls"))
	_tabs.tab_changed.connect(func(_index): key_panel.cancel_capture())
	_status = _label(column, "", 13)
	_status.custom_minimum_size.y = 36
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_save = _button(actions, tr("Save & back"), func(): _finish(true))
	_save.add_theme_stylebox_override("normal", ArtTheme.primary_button_style())
	_save.add_theme_stylebox_override("hover", ArtTheme.primary_button_hover_style())
	_save.add_theme_stylebox_override("pressed", ArtTheme.primary_button_pressed_style())
	_save.add_theme_color_override("font_color", Color("142130"))
	_save.add_theme_color_override("font_hover_color", Color("142130"))
	_save.add_theme_color_override("font_pressed_color", Color("142130"))
	_cancel = _button(actions, tr("Cancel [Esc]"), func(): _finish(false))
	_button(actions, tr("Reset defaults"), _defaults)
	_refresh()
	controls.master_volume.grab_focus()
	if options.menu_motion:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, .18)


func _heading(parent, title):
	parent.add_child(HSeparator.new())
	_label(parent, "// " + tr(title).to_upper(), 12, Color("d8af67"))


func _test_ambience():
	if _ambience_sample.playing:
		_ambience_sample.stop()
		_ambience_test.text = tr("Test ambience")
	else:
		_ambience_sample.play()
		_ambience_test.text = tr("Stop ambience sample")


func _row(parent, title):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label = _label(row, tr(title), 14, Color("cbd5e1"))
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
	slider.tooltip_text = tr(title)
	row.add_child(slider)
	var value = _label(row, "", 13, Color("d8af67"))
	value.custom_minimum_size.x = 55
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(amount): _preview(key, amount))
	controls[key] = slider
	controls[key + "_value"] = value


func _check(parent, title, key):
	var checkbox = CheckBox.new()
	checkbox.text = tr(title)
	checkbox.add_theme_font_size_override("font_size", 14)
	checkbox.toggled.connect(func(value): _preview(key, value))
	parent.add_child(checkbox)
	controls[key] = checkbox
	return checkbox


func _button(parent, title, callback):
	var button = Button.new()
	button.text = tr(title)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", ArtTheme.secondary_button_style())
	button.add_theme_stylebox_override("hover", ArtTheme.secondary_button_hover_style())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent, title, font_size, color_val = Color("edf2f7")):
	var label = Label.new()
	label.text = tr(title)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_val)
	parent.add_child(label)
	return label


func _preview(key, value):
	options.set(key, value)
	options.apply()
	_status.text = tr("Changes previewed — not saved yet.")
	_refresh()


func _defaults():
	key_panel.cancel_capture()
	options.restore(options.DEFAULTS)
	_status.text = tr("Defaults previewed — Save to keep them.")
	_refresh()


func _refresh():
	if is_instance_valid(key_panel):
		key_panel.refresh()
	controls.language.select(["en", "zh_CN"].find(options.language))
	for key in ["graphics_msaa", "time_of_day", "weather"]:
		controls[key].select(options.get(key))
	for key in [
		"graphics_shadows",
		"graphics_ao",
		"graphics_glow",
		"graphics_fog",
		"graphics_dof",
		"day_cycle",
		"weather_particles",
		"living_world",
		"menu_motion"
	]:
		controls[key].set_pressed_no_signal(options.get(key))
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
		"music_volume",
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


func _build_graphics():
	var scroll = ScrollContainer.new()
	scroll.name = "Graphics"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	_tabs.set_tab_title(1, tr("Graphics"))
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	_heading(column, "Light & atmosphere")
	_choice(column, "Time of day", "time_of_day", ["Afternoon", "Golden hour", "Night", "Dawn"])
	_check(column, "Day / night cycle (24 minutes)", "day_cycle")
	_choice(column, "Weather", "weather", ["Changing skies", "Clear", "Overcast", "Rain", "Mist"])
	_check(column, "Rain particles", "weather_particles")
	_check(column, "Atmospheric fog", "graphics_fog")
	_heading(column, "Rendering")
	_check(column, "Soft sun and moon shadows", "graphics_shadows")
	_check(column, "Ambient occlusion (contact shading)", "graphics_ao")
	_check(column, "Bloom / light glow", "graphics_glow")
	_check(column, "Cinematic depth of field", "graphics_dof")
	controls.graphics_dof.tooltip_text = tr(
		"Keep the camera focus sharp; softly blur distant scenery."
	)
	_choice(column, "Anti-aliasing", "graphics_msaa", ["Off", "2× MSAA", "4× MSAA"])
	var forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	for key in ["graphics_ao", "graphics_dof"]:
		controls[key].disabled = not forward
		if not forward:
			controls[key].tooltip_text = tr("Available with the Forward+ renderer.")
	_heading(column, "World & interface")
	_check(column, "Scenic districts and background population", "living_world")
	_check(column, "Animated menu backgrounds and entrances", "menu_motion")


func _choice(parent, title, key, titles):
	var row = _row(parent, title)
	var choice = OptionButton.new()
	for item in titles:
		choice.add_item(tr(item))
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.item_selected.connect(func(index): _preview(key, index))
	row.add_child(choice)
	controls[key] = choice
