extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Console = preload("res://source/match/hud/BattleTheme.gd")
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


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	_active_faction = "bastion"
	Console.use_faction(_active_faction)
	theme = ArtTheme.create()

	_backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	_backdrop.dim = 0.16
	_backdrop.left_focus = 0.92
	_backdrop.set_accent(ArtTheme.accent())
	add_child(_backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)

	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# Left-third floating command rail keeps the right two-thirds open for key art.
	var rail = VBoxContainer.new()
	rail.custom_minimum_size.x = 396
	rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rail.add_theme_constant_override("separation", 14)
	body.add_child(rail)

	_lockup = MenuChrome.brand_lockup(rail, tr("THE ORIGIN OF THE SPLIT · THREE FORCES OF THE NEW FRONTIER"))

	var actions = VBoxContainer.new()
	actions.name = "MenuActions"
	actions.add_theme_constant_override("separation", 7)
	rail.add_child(actions)

	var skirmish = _tactical_action(
		actions,
		"Skirmish",
		"SKIRMISH",
		_on_play_button_pressed,
		true,
		"01",
		"Instant tactical battle · AI & maps",
		Console.icon("attack_move"),
		48
	)
	_tactical_action(
		actions,
		"Campaign",
		"CAMPAIGN",
		func(): _open("res://source/main-menu/CampaignHub.tscn"),
		false,
		"02",
		"Story operations · three factions",
		Console.icon("plan"),
		44
	)
	_tactical_action(
		actions,
		"Multiplayer",
		"MULTIPLAYER",
		func(): _open("res://source/main-menu/Multiplayer.tscn"),
		false,
		"03",
		"LAN, localhost or dedicated server",
		Console.icon("relays"),
		44
	)
	_tactical_action(
		actions,
		"Continue",
		"CONTINUE / LOAD",
		func(): get_node("/root/SaveManager").open_dialog(),
		false,
		"04",
		"Resume a saved battle",
		Console.icon("resume"),
		42
	)

	var archive_row = HBoxContainer.new()
	archive_row.add_theme_constant_override("separation", 8)
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
		38
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
		38
	)

	rail.add_child(HSeparator.new())

	var utilities = GridContainer.new()
	utilities.columns = 2
	utilities.add_theme_constant_override("h_separation", 8)
	utilities.add_theme_constant_override("v_separation", 6)
	rail.add_child(utilities)
	_utility_action(
		utilities,
		"ScenarioEditor",
		"SCENARIO EDITOR",
		func(): _open("res://source/scenario/ScenarioEditor.tscn")
	)
	_utility_action(
		utilities,
		"ModelGallery",
		"MODEL GALLERY",
		func(): _open("res://source/showcase/ModelGalleryMatch.tscn")
	)
	_utility_action(utilities, "Settings", "SETTINGS", _on_options_button_pressed)
	_utility_action(utilities, "Exit", "EXIT", _on_quit_button_pressed)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)

	var credits = Button.new()
	credits.name = "Credits"
	credits.text = tr("Credits")
	credits.pressed.connect(_on_credits_button_pressed)
	footer.add_child(credits)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	credits.theme_type_variation = "BattleQuietButton"
	credits.custom_minimum_size = Vector2(96, 32)

	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)

	_build_faction_switcher(footer)
	_sync_faction_pills()
	skirmish.grab_focus()
	MenuChrome.animate_entrance(rail, 12.0, 0.24)

	var user_args = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and "--headless-startup-smoke" in user_args:
		_finish_headless_smoke.call_deferred()


func _build_faction_switcher(parent: Control):
	var bar = PanelContainer.new()
	bar.theme_type_variation = "HudStrip"
	parent.add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	var tag = Label.new()
	tag.text = tr("Theme")
	tag.add_theme_font_override("font", ArtTheme.heading_font())
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", ArtTheme.MUTED)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	var group = ButtonGroup.new()
	for faction in ["bastion", "helix", "frontier"]:
		var btn = Button.new()
		btn.name = "Theme_" + faction
		btn.text = tr(FACTION_LABELS[faction])
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_switch_faction_theme.bind(faction))
		row.add_child(btn)
		_faction_pills[faction] = btn


func _switch_faction_theme(faction: String):
	_active_faction = faction
	Console.use_faction(faction)
	theme = ArtTheme.create()
	_backdrop.set_accent(ArtTheme.accent())
	_backdrop.show_art(FACTION_ART[faction])
	if _lockup.has("crest"):
		_lockup.crest.accent = ArtTheme.accent()
		_lockup.crest.queue_redraw()
	if _lockup.has("subtitle") and _lockup.subtitle != null:
		_lockup.subtitle.add_theme_color_override(
			"font_color", ArtTheme.accent().lerp(ArtTheme.IVORY, 0.35)
		)
	if _lockup.has("stripe"):
		_lockup.stripe.add_theme_stylebox_override("panel", ArtTheme.stripe())
	for btn in _tactical_buttons:
		if is_instance_valid(btn):
			btn.sync_theme(ArtTheme.accent(), ArtTheme.ink())
	_sync_faction_pills()


func _sync_faction_pills():
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
	button.button_height = 36
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
