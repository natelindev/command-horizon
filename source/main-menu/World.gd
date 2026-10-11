extends Control

const Lore = preload("res://source/lore/WorldLore.gd")
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")


func _ready():
	theme = ArtTheme.create()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .48
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	# --- TOP HEADER ---
	var top_bar = HBoxContainer.new()
	page.add_child(top_bar)
	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	top_bar.add_child(title_box)

	var tag = Label.new()
	tag.text = tr("// INTELLIGENCE ARCHIVE // SYSTEM LORE & RECORDS")
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color("8ea0a8"))
	title_box.add_child(tag)

	_label(title_box, tr("WORLD & FACTIONS"), 26)
	_label(
		title_box,
		tr("THE ORIGIN OF THE SPLIT · THREE FORCES OF THE NEW FRONTIER"),
		12,
		Color("9eb0b8")
	)

	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var telemetry = VBoxContainer.new()
	telemetry.alignment = BoxContainer.ALIGNMENT_CENTER
	telemetry.add_theme_constant_override("separation", 2)
	top_bar.add_child(telemetry)

	var status_lbl = Label.new()
	status_lbl.text = tr("● ARCHIVE CLEARANCE: LEVEL 3")
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color("68d391"))
	telemetry.add_child(status_lbl)

	var proto_lbl = Label.new()
	proto_lbl.text = tr("DATA INTEGRITY // 100% VERIFIED")
	proto_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	proto_lbl.add_theme_font_size_override("font_size", 10)
	proto_lbl.add_theme_color_override("font_color", Color("6c7d86"))
	telemetry.add_child(proto_lbl)

	# --- SCROLL CONTENT ---
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	# Historical Lore Dossier Card
	var lore_panel = PanelContainer.new()
	lore_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lp_style = StyleBoxFlat.new()
	lp_style.bg_color = Color("0d151dea")
	lp_style.set_corner_radius_all(0)
	lp_style.set_border_width_all(1)
	lp_style.border_color = Color("1e2f3bc8")
	lp_style.set_content_margin_all(18)
	lore_panel.add_theme_stylebox_override("panel", lp_style)
	content.add_child(lore_panel)

	var lore_vbox = VBoxContainer.new()
	lore_vbox.add_theme_constant_override("separation", 8)
	lore_panel.add_child(lore_vbox)

	_label(lore_vbox, tr("// HISTORICAL CHRONICLES //"), 12, Color("d8a846"))
	_label(lore_vbox, tr(Lore.TITLE), 28)
	_label(lore_vbox, tr(Lore.TAGLINE), 16, Color("d8a846"))

	var div = HSeparator.new()
	lore_vbox.add_child(div)

	_label(lore_vbox, tr(Lore.OPENING), 14, Color("cbd5e1"))
	_label(lore_vbox, tr(Lore.TURN), 14, Color("cbd5e1"))
	_label(lore_vbox, tr(Lore.CONFLICT), 14, Color("cbd5e1"))

	# Faction Dossier Section
	_label(content, tr("// ACTIVE FACTIONS OF THE NEW FRONTIER //"), 12, Color("d8a846"))

	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	content.add_child(cards)

	var faction_configs = {
		"bastion":
		{"accent": Color("d8af67"), "bg_accent": Color("1f1a14cc"), "tag": "// BASTION // "},
		"helix": {"accent": Color("38c8ce"), "bg_accent": Color("101d24cc"), "tag": "// HELIX // "},
		"frontier":
		{"accent": Color("e29b68"), "bg_accent": Color("221814cc"), "tag": "// FRONTIER // "}
	}

	for faction in ["bastion", "helix", "frontier"]:
		var cfg = faction_configs[faction]
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("0d151dea")
		p_style.set_corner_radius_all(0)
		p_style.set_border_width_all(1)
		p_style.border_color = Color("1e2f3bc8")
		p_style.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", p_style)
		cards.add_child(panel)

		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)

		var entry = Lore.FACTIONS[faction]

		var header_box = PanelContainer.new()
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = cfg.bg_accent
		h_style.set_corner_radius_all(0)
		h_style.set_border_width_all(1)
		h_style.border_color = Color("1e2f3bc0")
		h_style.set_content_margin_all(6)
		header_box.add_theme_stylebox_override("panel", h_style)
		column.add_child(header_box)

		_label(header_box, cfg.tag + tr(entry.role), 11, cfg.accent)
		_label(column, tr(entry.name), 20)
		_label(column, tr(entry.motto), 14, cfg.accent)

		var story_box = PanelContainer.new()
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color("070d13b3")
		s_style.set_corner_radius_all(0)
		s_style.set_border_width_all(1)
		s_style.border_color = Color("1e2f3bc0")
		s_style.set_content_margin_all(8)
		story_box.add_theme_stylebox_override("panel", s_style)
		column.add_child(story_box)

		_label(story_box, tr(entry.story), 13, Color("cbd5e1"))

	# --- FOOTER BAR ---
	var back = Button.new()
	back.text = tr("Back")
	back.custom_minimum_size = Vector2(140, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_theme_stylebox_override("normal", ArtTheme.secondary_button_style())
	back.add_theme_stylebox_override("hover", ArtTheme.secondary_button_hover_style())
	back.pressed.connect(_back)
	page.add_child(back)
	back.grab_focus()


func _label(parent, text_value, font_size, color = Color("e3e8e8")):
	var label = Label.new()
	label.text = tr(text_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _back():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
