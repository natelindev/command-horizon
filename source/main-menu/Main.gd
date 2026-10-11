extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	theme = ArtTheme.create()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .48
	add_child(backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)
	var masthead = HBoxContainer.new()
	page.add_child(masthead)
	_label(masthead, "OPEN RTS", 20, Color("f1eee4"))
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(space)
	_label(masthead, tr("TACTICS SHAPE A BRIGHTER TOMORROW"), 12, Color("acb8bd"))

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 36)
	page.add_child(body)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_label(column, tr("THEATER OF OPERATIONS"), 12, Color("d8bc80"))
	_label(column, tr("Command the battlefield"), 28, Color("f1eee4"))
	var intro = _label(column, tr("Choose your next operation."), 14, Color("95a4aa"))
	intro.custom_minimum_size.y = 28
	var actions = VBoxContainer.new()
	actions.name = "MenuActions"
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var skirmish = _action(
		actions, "Skirmish", tr("SKIRMISH"), "ico_skirmish", _on_play_button_pressed
	)
	skirmish.theme_type_variation = "BattlePrimaryButton"
	_action(
		actions,
		"Campaign",
		tr("CAMPAIGN"),
		"ico_campaign",
		func(): _open("res://source/main-menu/Campaign.tscn")
	)
	_action(
		actions,
		"Continue",
		tr("CONTINUE / LOAD"),
		"ico_multiplayer",
		func(): get_node("/root/SaveManager").open_dialog()
	)
	_action(
		actions,
		"World",
		tr("WORLD & FACTIONS"),
		"ico_mods",
		func(): _open("res://source/main-menu/World.tscn")
	)
	var utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 8)
	column.add_child(utilities)
	_action(utilities, "Settings", tr("SETTINGS"), "ico_settings", _on_options_button_pressed, 42)
	_action(utilities, "Exit", tr("EXIT"), "ico_exit", _on_quit_button_pressed, 42)

	var feature = VBoxContainer.new()
	feature.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature.alignment = BoxContainer.ALIGNMENT_END
	feature.add_theme_constant_override("separation", 10)
	body.add_child(feature)
	var kicker = _label(feature, tr("BUILD. COMMAND. PREVAIL."), 13, Color("d8bc80"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var feature_title = _label(feature, tr("Every order matters."), 32, Color("f1eee4"))
	feature_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feature_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var caption = _label(feature, tr("Three factions. One battlefield."), 15, Color("b8c3c6"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)
	for entry in [
		["Credits", _on_credits_button_pressed],
		["Model gallery", func(): _open("res://source/showcase/HelixShowcase.tscn")],
		["Bastion demo", func(): _open("res://source/match/BastionDemo.tscn")]
	]:
		var button = Button.new()
		button.text = tr(entry[0])
		button.theme_type_variation = "BattleQuietButton"
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(entry[1])
		footer.add_child(button)
	skirmish.grab_focus()
	if Globals.options.menu_motion:
		panel.modulate.a = 0.0
		create_tween().tween_property(panel, "modulate:a", 1.0, .35)


func _label(parent, text_value, font_size, color):
	var label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _action(parent, node_name, title, icon_name, callback, height = 56):
	var button = Button.new()
	button.name = node_name
	button.text = title
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = load("res://assets/ui/menu/%s.png" % icon_name)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _open(path):
	get_tree().change_scene_to_file(path)


func _on_play_button_pressed():
	_open("res://source/main-menu/Play.tscn")


func _on_options_button_pressed():
	Globals.open_settings()


func _on_credits_button_pressed():
	_open("res://source/main-menu/Credits.tscn")


func _on_quit_button_pressed():
	get_tree().quit()
