extends Control

const Lore = preload("res://source/lore/WorldLore.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")

const TABS = [
	{"id": "split", "label": "The Split", "art": "res://assets/ui/art/river-city-menu.png"},
	{"id": "bastion", "label": "Bastion", "art": "res://assets/ui/art/bastion-foundry-dawn.png"},
	{"id": "helix", "label": "Helix", "art": "res://assets/ui/art/helix-relay-night.png"},
	{
		"id": "frontier",
		"label": "Frontier",
		"art": "res://assets/ui/art/frontier-convoy-sunset.png"
	},
]

var _backdrop
var _header = {}
var _tab_buttons = []
var _art_rect: TextureRect
var _portrait_frame: PanelContainer
var _portrait_rect: TextureRect
var _unit_strip: HBoxContainer
var _left_caption: Label
var _left_motto: Label
var _dossier_heading: PanelContainer
var _dossier_title: Label
var _dossier_sub: Label
var _dossier_body: VBoxContainer
var _active_tab = 0


func _ready():
	ArtTheme.Console.use_faction("bastion")
	theme = ArtTheme.create()

	_backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	_backdrop.dim = .54
	_backdrop.left_focus = 0.35
	_backdrop.set_accent(ArtTheme.accent())
	add_child(_backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 26)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)

	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	var group = ButtonGroup.new()
	for idx in TABS.size():
		var btn = Button.new()
		btn.text = tr(TABS[idx].label)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(96, 34)
		btn.pressed.connect(_select_tab.bind(idx))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	_header = MenuChrome.screen_header(
		page,
		tr("WORLD & FACTIONS"),
		tr("THE ORIGIN OF THE SPLIT · THREE FORCES OF THE NEW FRONTIER"),
		tab_bar
	)

	var spread = HBoxContainer.new()
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 16)
	page.add_child(spread)

	# Left visual showcase column (key art, commander portrait, unit icons, motto).
	var left_panel = PanelContainer.new()
	left_panel.theme_type_variation = "HudHousing"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.95
	spread.add_child(left_panel)

	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)
	left_panel.add_child(left_col)

	var art_socket = PanelContainer.new()
	art_socket.theme_type_variation = "HudSocket"
	art_socket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(art_socket)

	_art_rect = TextureRect.new()
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.custom_minimum_size = Vector2(260, 180)
	art_socket.add_child(_art_rect)

	var identity_row = HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 10)
	left_col.add_child(identity_row)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.theme_type_variation = "HudSocket"
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(_portrait_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(64, 64)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait_rect)

	var motto_col = VBoxContainer.new()
	motto_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motto_col.alignment = BoxContainer.ALIGNMENT_CENTER
	motto_col.add_theme_constant_override("separation", 4)
	identity_row.add_child(motto_col)

	_left_caption = _label(motto_col, "", 12, ArtTheme.MUTED)
	_left_caption.add_theme_font_override("font", ArtTheme.heading_font())
	_left_motto = _label(motto_col, "", 15, ArtTheme.IVORY)

	_unit_strip = HBoxContainer.new()
	_unit_strip.add_theme_constant_override("separation", 8)
	left_col.add_child(_unit_strip)

	# Right dossier column.
	var right_panel = PanelContainer.new()
	right_panel.theme_type_variation = "HudHousing"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.25
	spread.add_child(right_panel)

	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_col)

	_dossier_heading = MenuChrome.nameplate_heading(right_col, tr("The Split"))
	_dossier_title = _label(right_col, "", 24, ArtTheme.IVORY)
	_dossier_title.add_theme_font_override("font", ArtTheme.heading_font())
	_dossier_sub = _label(right_col, "", 14, ArtTheme.accent())

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)

	_dossier_body = VBoxContainer.new()
	_dossier_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_dossier_body)

	var footer = HBoxContainer.new()
	page.add_child(footer)
	var back = Button.new()
	back.text = tr("Back")
	back.custom_minimum_size = Vector2(130, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back)
	footer.add_child(back)

	_select_tab(0)
	back.grab_focus()
	MenuChrome.animate_entrance(spread, 8.0, 0.2)


func _select_tab(idx: int):
	_active_tab = idx
	var entry = TABS[idx]
	var theme_faction = "bastion" if entry.id == "split" else entry.id
	ArtTheme.Console.use_faction(theme_faction)
	theme = ArtTheme.create()
	_backdrop.set_accent(ArtTheme.accent())
	_backdrop.show_art(entry.art)
	MenuChrome.sync_header_accent(_header, ArtTheme.accent())

	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		btn.set_pressed_no_signal(i == idx)
		btn.theme_type_variation = "BattlePrimaryButton" if i == idx else "BattleQuietButton"

	_art_rect.texture = load(entry.art)
	for child in _unit_strip.get_children():
		child.queue_free()
	for child in _dossier_body.get_children():
		child.queue_free()

	var heading_lbl: Label = _dossier_heading.get_child(0)
	heading_lbl.text = tr(entry.label)
	heading_lbl.add_theme_color_override("font_color", ArtTheme.accent())
	_dossier_sub.add_theme_color_override("font_color", ArtTheme.accent())

	if entry.id == "split":
		_portrait_frame.visible = false
		_unit_strip.visible = false
		_left_caption.text = tr("COMMAND HORIZON")
		_left_motto.text = tr(Lore.TAGLINE)
		_dossier_title.text = tr(Lore.TITLE)
		_dossier_sub.text = tr(Lore.TAGLINE)
		for block in [Lore.OPENING, Lore.TURN, Lore.CONFLICT]:
			var card = PanelContainer.new()
			card.theme_type_variation = "HudCard"
			_dossier_body.add_child(card)
			_label(card, block, 14, ArtTheme.IVORY)
	else:
		var f_data = Lore.FACTIONS[entry.id]
		_portrait_frame.visible = true
		_portrait_rect.texture = Artwork.commander(entry.id)
		_left_caption.text = tr(f_data.role)
		_left_motto.text = tr(f_data.motto)

		_unit_strip.visible = true
		for unit_type in ["Infantry", "Tank", "Walker", "Aircraft"]:
			var icon_path = Factions.icon(entry.id, unit_type)
			if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
				continue
			var sock = PanelContainer.new()
			sock.theme_type_variation = "HudSocket"
			_unit_strip.add_child(sock)
			var tex = TextureRect.new()
			tex.texture = load(icon_path)
			tex.custom_minimum_size = Vector2(36, 36)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sock.add_child(tex)

		_dossier_title.text = tr(f_data.name)
		_dossier_sub.text = tr(f_data.role)

		var tech_card = PanelContainer.new()
		tech_card.theme_type_variation = "HudCard"
		_dossier_body.add_child(tech_card)
		_label(
			tech_card,
			Factions.TECH_SUMMARY[entry.id],
			14,
			ArtTheme.accent().lerp(ArtTheme.IVORY, 0.35)
		)

		var story_card = PanelContainer.new()
		story_card.theme_type_variation = "HudSocket"
		_dossier_body.add_child(story_card)
		_label(story_card, f_data.story, 14, ArtTheme.IVORY)


func _label(parent, text_value, font_size, color = ArtTheme.IVORY):
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
