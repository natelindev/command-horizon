extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Console = preload("res://source/match/hud/BattleTheme.gd")


func _ready():
	get_node("/root/SaveManager").autosaves_enabled = true
	Console.use_faction("bastion")
	theme = ArtTheme.create()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .38
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 24)
	scroll.add_child(page)
	var title = Label.new()
	title.text = "OPEN RTS"
	title.theme_type_variation = "HudHeading"
	title.add_theme_font_size_override("font_size", 36)
	page.add_child(title)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "HudHousing"
	panel.custom_minimum_size.x = 380
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(panel)
	var actions = VBoxContainer.new()
	actions.name = "MenuActions"
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)
	var skirmish = _action(actions, "Skirmish", "SKIRMISH", _on_play_button_pressed)
	skirmish.theme_type_variation = "BattlePrimaryButton"
	_action(actions, "Campaign", "CAMPAIGN", func(): _open("res://source/main-menu/Campaign.tscn"))
	_action(
		actions, "Continue", "CONTINUE / LOAD", func(): get_node("/root/SaveManager").open_dialog()
	)
	_action(
		actions, "World", "WORLD & FACTIONS", func(): _open("res://source/main-menu/World.tscn")
	)
	actions.add_child(HSeparator.new())
	var utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 10)
	actions.add_child(utilities)
	_action(utilities, "Settings", "SETTINGS", _on_options_button_pressed)
	_action(utilities, "Exit", "EXIT", _on_quit_button_pressed)
	var footer = HBoxContainer.new()
	page.add_child(footer)
	var credits = _action(footer, "Credits", "Credits", _on_credits_button_pressed)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	credits.theme_type_variation = "BattleQuietButton"
	skirmish.grab_focus()


func _action(parent, node_name, caption, callback):
	var button = Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	Globals.quit_game()
