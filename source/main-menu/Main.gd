extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const TacticalButton = preload("res://source/main-menu/TacticalButton.gd")
const UnitTelemetryWidget = preload("res://source/main-menu/UnitTelemetryWidget.gd")

var _telemetry: Control


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	theme = ArtTheme.create()

	# Atmospheric background
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .42
	add_child(backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)

	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	# --- TOP MASTHEAD ---
	var masthead = HBoxContainer.new()
	page.add_child(masthead)

	var title_box = HBoxContainer.new()
	title_box.add_theme_constant_override("separation", 14)
	masthead.add_child(title_box)

	_label(title_box, "OPEN RTS", 22, Color("f1eee4"))
	_label(title_box, tr("// TAC-OPS // THEATER OF OPERATIONS"), 11, Color("d8a846"))

	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(space)

	var telemetry_strip = HBoxContainer.new()
	telemetry_strip.add_theme_constant_override("separation", 16)
	masthead.add_child(telemetry_strip)
	_label(telemetry_strip, tr("SYS: ONLINE"), 11, Color("4da8cc"))
	_label(telemetry_strip, "·", 11, Color("41545e"))
	_label(telemetry_strip, tr("SAT-LINK: SECURE"), 11, Color("7b929e"))
	_label(telemetry_strip, "·", 11, Color("41545e"))
	_label(telemetry_strip, tr("GRID: 48°14'N 16°22'E"), 11, Color("7b929e"))
	_label(telemetry_strip, "·", 11, Color("41545e"))
	_label(telemetry_strip, tr("BUILD 1.0"), 11, Color("d8a846"))

	# Top hairline divider
	var top_line = ColorRect.new()
	top_line.custom_minimum_size.y = 1
	top_line.color = Color("ffffff15")
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(top_line)

	# --- BODY SECTION ---
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 32)
	page.add_child(body)

	# Left Column: Command & Operations
	var left_column = VBoxContainer.new()
	left_column.custom_minimum_size.x = 420
	left_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_column.add_theme_constant_override("separation", 12)
	body.add_child(left_column)

	var intro_header = VBoxContainer.new()
	intro_header.add_theme_constant_override("separation", 2)
	left_column.add_child(intro_header)

	_label(intro_header, tr("THEATER OF OPERATIONS"), 11, Color("d8a846"))
	_label(intro_header, tr("Command the battlefield"), 24, Color("f1eee4"))
	var intro = _label(intro_header, tr("Choose your next operation."), 12, Color("7b929e"))
	intro.custom_minimum_size.y = 20

	# Tactical Action Buttons
	var actions = VBoxContainer.new()
	actions.name = "MenuActions"
	actions.add_theme_constant_override("separation", 8)
	left_column.add_child(actions)

	var skirmish = _tactical_action(
		actions,
		"Skirmish",
		"01 //",
		tr("SKIRMISH"),
		tr("TACTICAL FORCE DEPLOYMENT"),
		"ico_skirmish",
		_on_play_button_pressed
	)
	var campaign = _tactical_action(
		actions,
		"Campaign",
		"02 //",
		tr("CAMPAIGN"),
		tr("THEATERS OF WAR & SCRIPTED OPS"),
		"ico_campaign",
		func(): _open("res://source/main-menu/Campaign.tscn")
	)
	var cont = _tactical_action(
		actions,
		"Continue",
		"03 //",
		tr("CONTINUE / LOAD"),
		tr("RESTORE ACTIVE BATTLEFIELD"),
		"ico_multiplayer",
		func(): get_node("/root/SaveManager").open_dialog()
	)
	var world = _tactical_action(
		actions,
		"World",
		"04 //",
		tr("WORLD & FACTIONS"),
		tr("FACTION DOSSIERS & SPECS"),
		"ico_mods",
		func(): _open("res://source/main-menu/World.tscn")
	)

	# Utility Row
	var utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 8)
	left_column.add_child(utilities)

	_tactical_action(
		utilities,
		"Settings",
		"05 //",
		tr("SETTINGS"),
		"",
		"ico_settings",
		_on_options_button_pressed,
		44
	)
	_tactical_action(
		utilities, "Exit", "06 //", tr("EXIT"), "", "ico_exit", _on_quit_button_pressed, 44
	)

	# Center Spacer
	var body_spacer = Control.new()
	body_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(body_spacer)

	# Right Column: Live 3D Unit Telemetry Widget
	_telemetry = UnitTelemetryWidget.new()
	body.add_child(_telemetry)

	# Link button hover to unit telemetry preview
	skirmish.mouse_entered.connect(func(): _telemetry.set_unit("walker"))
	skirmish.focus_entered.connect(func(): _telemetry.set_unit("walker"))
	campaign.mouse_entered.connect(func(): _telemetry.set_unit("tank"))
	campaign.focus_entered.connect(func(): _telemetry.set_unit("tank"))
	cont.mouse_entered.connect(func(): _telemetry.set_unit("walker"))
	cont.focus_entered.connect(func(): _telemetry.set_unit("walker"))
	world.mouse_entered.connect(func(): _telemetry.set_unit("helicopter"))
	world.focus_entered.connect(func(): _telemetry.set_unit("helicopter"))

	# Bottom hairline divider
	var bottom_line = ColorRect.new()
	bottom_line.custom_minimum_size.y = 1
	bottom_line.color = Color("ffffff15")
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bottom_line)

	# --- FOOTER BAR ---
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
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(entry[1])
		footer.add_child(button)

	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	_label(footer, tr("SEC-CLEARANCE: LEVEL 4 // CLASSIFIED OPERATIONS"), 10, Color("5d7582"))
	_label(footer, "·", 10, Color("41545e"))
	_label(footer, tr("FACTIONS: BASTION · FRONTIER · HELIX"), 10, Color("7b929e"))

	skirmish.grab_focus()
	if Globals.options.menu_motion:
		left_column.modulate.a = 0.0
		_telemetry.modulate.a = 0.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(left_column, "modulate:a", 1.0, 0.35)
		tw.tween_property(_telemetry, "modulate:a", 1.0, 0.45)


func _label(parent, text_value, font_size, color):
	var label = Label.new()
	label.text = tr(text_value)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _tactical_action(
	parent, node_name, index_code, title, subtitle, icon_name, callback, height = 52
):
	var button = TacticalButton.new()
	button.name = node_name
	button.text = title
	button.index_code = index_code
	button.subtitle_text = subtitle
	button.button_height = height
	if not icon_name.is_empty():
		button.icon = load("res://assets/ui/menu/%s.png" % icon_name)
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
