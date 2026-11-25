extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")
const Console = preload("res://source/match/hud/BattleTheme.gd")
const Lore = preload("res://source/lore/WorldLore.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")
const TacticalButton = preload("res://source/main-menu/TacticalButton.gd")

const FACTION_ART = {
	"bastion": "res://assets/ui/art/bastion-foundry-dawn.png",
	"helix": "res://assets/ui/art/helix-relay-night.png",
	"frontier": "res://assets/ui/art/frontier-convoy-sunset.png",
}
const FACTION_LABELS = {
	"bastion": "Bastion",
	"helix": "Helix",
	"frontier": "Frontier",
}

var _backdrop
var _lockup = {}
var _tactical_buttons = []
var _faction_pills = {}
var _active_faction = "bastion"
var _theater_panel: PanelContainer
var _theater_portrait: TextureRect
var _theater_title: Label
var _theater_motto: Label


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	_active_faction = "bastion"
	Console.use_faction(_active_faction)
	theme = ArtTheme.create()

	_backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	_backdrop.dim = 0.14
	_backdrop.left_focus = 0.90
	_backdrop.set_accent(ArtTheme.accent())
	add_child(_backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)

	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	# Left command rail: sculpted metallic blades leaving the key art open.
	var rail = VBoxContainer.new()
	rail.custom_minimum_size.x = 356
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rail.add_theme_constant_override("separation", 10)
	body.add_child(rail)

	_lockup = MenuChrome.brand_lockup(
		rail, tr("THE ORIGIN OF THE SPLIT · THREE FORCES OF THE NEW FRONTIER")
	)

	var actions = VBoxContainer.new()
	actions.name = "MenuActions"
	actions.add_theme_constant_override("separation", 6)
	rail.add_child(actions)

	var skirmish = _tactical_action(
		actions,
		"Skirmish",
		"SKIRMISH",
		_on_play_button_pressed,
		true,
		"",
		"Instant tactical battle · AI & maps",
		Console.icon("attack_move"),
		44
	)
	_tactical_action(
		actions,
		"Campaign",
		"CAMPAIGN",
		func(): _open("res://source/main-menu/CampaignHub.tscn"),
		false,
		"",
		"Story operations · three factions",
		Console.icon("plan"),
		40
	)
	_tactical_action(
		actions,
		"Multiplayer",
		"MULTIPLAYER",
		func(): _open("res://source/main-menu/Multiplayer.tscn"),
		false,
		"",
		"LAN, localhost or dedicated server",
		Console.icon("relays"),
		40
	)
	_tactical_action(
		actions,
		"Continue",
		"CONTINUE / LOAD",
		func(): get_node("/root/SaveManager").open_dialog(),
		false,
		"",
		"Resume a saved battle",
		Console.icon("resume"),
		38
	)

	var archive_row = HBoxContainer.new()
	archive_row.add_theme_constant_override("separation", 6)
	actions.add_child(archive_row)
	_tactical_action(
		archive_row,
		"Replays",
		"REPLAYS",
		func(): _open("res://source/main-menu/Replays.tscn"),
		false,
		"",
		"",
		null,
		34
	)
	_tactical_action(
		archive_row,
		"World",
		"WORLD & FACTIONS",
		func(): _open("res://source/main-menu/World.tscn"),
		false,
		"",
		"",
		null,
		34
	)

	var sys_row = HBoxContainer.new()
	sys_row.add_theme_constant_override("separation", 6)
	actions.add_child(sys_row)
	_utility_action(sys_row, "Settings", "SETTINGS", _on_options_button_pressed)
	_utility_action(sys_row, "Exit", "EXIT", _on_quit_button_pressed)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)

	# Top-right Theater / Faction Showcase card (inspired by SC2 HotS status card).
	var right_col = VBoxContainer.new()
	right_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(right_col)
	_build_theater_card(right_col)

	# Bottom command utility strip.
	var footer_bar = PanelContainer.new()
	footer_bar.theme_type_variation = "HudStrip"
	var strip_style = ArtTheme.Console.strip(12, 4)
	footer_bar.add_theme_stylebox_override("panel", strip_style)
	page.add_child(footer_bar)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer_bar.add_child(footer)

	_quiet_footer_btn(
		footer,
		"ScenarioEditor",
		"SCENARIO EDITOR",
		func(): _open("res://source/scenario/ScenarioEditor.tscn")
	)
	_quiet_footer_btn(
		footer,
		"ModelGallery",
		"MODEL GALLERY",
		func(): _open("res://source/showcase/ModelGalleryMatch.tscn")
	)

	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)

	_quiet_footer_btn(footer, "Credits", "Credits", _on_credits_button_pressed)

	_sync_theater()
	skirmish.grab_focus()
	MenuChrome.animate_entrance(rail, 12.0, 0.24)

	var user_args = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and "--headless-startup-smoke" in user_args:
		_finish_headless_smoke.call_deferred()


func _quiet_footer_btn(parent: Control, node_name: String, caption: String, callback: Callable):
	var btn = Button.new()
	btn.name = node_name
	btn.text = tr(caption)
	btn.theme_type_variation = "BattleQuietButton"
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _build_theater_card(parent: Control):
	_theater_panel = PanelContainer.new()
	_theater_panel.theme_type_variation = "HudPanel"
	_theater_panel.add_theme_stylebox_override("panel", ArtTheme.panel(12))
	_theater_panel.custom_minimum_size.x = 290
	parent.add_child(_theater_panel)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_theater_panel.add_child(col)

	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)

	var socket = PanelContainer.new()
	socket.theme_type_variation = "HudSocket"
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(socket)

	_theater_portrait = TextureRect.new()
	_theater_portrait.custom_minimum_size = Vector2(44, 44)
	_theater_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_theater_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socket.add_child(_theater_portrait)

	var meta = VBoxContainer.new()
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.add_theme_constant_override("separation", 1)
	top.add_child(meta)

	_theater_title = Label.new()
	_theater_title.add_theme_font_override("font", ArtTheme.heading_font())
	_theater_title.add_theme_font_size_override("font_size", 15)
	_theater_title.add_theme_color_override("font_color", ArtTheme.IVORY)
	meta.add_child(_theater_title)

	_theater_motto = Label.new()
	_theater_motto.add_theme_font_size_override("font_size", 11)
	_theater_motto.add_theme_color_override("font_color", ArtTheme.MUTED)
	_theater_motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_child(_theater_motto)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var group = ButtonGroup.new()
	for faction in ["bastion", "helix", "frontier"]:
		var btn = Button.new()
		btn.name = "Theme_" + faction
		btn.text = tr(FACTION_LABELS[faction])
		btn.toggle_mode = true
		btn.button_group = group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 26)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_switch_faction_theme.bind(faction))
		row.add_child(btn)
		_faction_pills[faction] = btn


func _switch_faction_theme(faction: String):
	_active_faction = faction
	Console.use_faction(faction)
	theme = ArtTheme.create()
	_backdrop.set_accent(ArtTheme.accent())
	_backdrop.show_art(FACTION_ART[faction])
	MenuChrome.sync_header_accent(_lockup, ArtTheme.accent())
	if _lockup.has("subtitle") and _lockup.subtitle != null:
		_lockup.subtitle.add_theme_color_override(
			"font_color", ArtTheme.accent().lerp(ArtTheme.IVORY, 0.35)
		)
	if is_instance_valid(_theater_panel):
		_theater_panel.add_theme_stylebox_override("panel", ArtTheme.panel(12))
	for btn in _tactical_buttons:
		if is_instance_valid(btn):
			btn.sync_theme(ArtTheme.accent(), ArtTheme.ink())
	_sync_theater()


func _sync_theater():
	var f_data = Lore.FACTIONS.get(_active_faction, {})
	if is_instance_valid(_theater_portrait):
		_theater_portrait.texture = Artwork.commander(_active_faction)
	if is_instance_valid(_theater_title):
		_theater_title.text = tr(f_data.get("name", FACTION_LABELS[_active_faction]))
		_theater_title.add_theme_color_override("font_color", ArtTheme.accent())
	if is_instance_valid(_theater_motto):
		_theater_motto.text = tr(f_data.get("role", ""))
	for faction in _faction_pills:
		var btn: Button = _faction_pills[faction]
		var active = faction == _active_faction
		btn.set_pressed_no_signal(active)
		btn.theme_type_variation = "BattlePrimaryButton" if active else "BattleQuietButton"


func _finish_headless_smoke():
	for _frame in 120:
		await get_tree().process_frame
	if get_tree().current_scene != self or find_child("MenuActions", true, false) == null:
		push_error("Headless startup smoke did not retain the ordinary ready menu")
		await Globals.quit_game(1)
		return
	print("Headless startup smoke: ordinary_menu_ready frames=120")
	await Globals.quit_game()


func _tactical_action(
	parent,
	node_name: String,
	caption: String,
	callback: Callable,
	primary: bool = false,
	index_code: String = "",
	subtitle: String = "",
	icon_tex: Texture2D = null,
	height: int = 44
):
	var button = TacticalButton.new()
	button.name = node_name
	button.text = tr(caption)
	button.is_primary = primary
	button.index_code = index_code
	button.subtitle_text = subtitle
	button.icon = icon_tex
	button.button_height = height
	button.cut_size = 11.0 if primary else 9.0
	button.pressed.connect(callback)
	parent.add_child(button)
	_tactical_buttons.append(button)
	return button


func _utility_action(parent, node_name, caption, callback):
	var button = TacticalButton.new()
	button.name = node_name
	button.text = tr(caption)
	button.is_primary = false
	button.index_code = ""
	button.subtitle_text = ""
	button.button_height = 34
	button.cut_size = 7.0
	button.pressed.connect(callback)
	parent.add_child(button)
	_tactical_buttons.append(button)
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
	Globals.quit_game()
