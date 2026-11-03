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
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	scroll.add_child(page)
	var title = Label.new()
	title.text = "OPEN RTS"
	title.theme_type_variation = "HudHeading"
	title.add_theme_font_size_override("font_size", 30)
	page.add_child(title)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "HudHousing"
	panel.custom_minimum_size.x = 600
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(panel)
	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	panel.add_child(menu)
	var actions = GridContainer.new()
	actions.name = "MenuActions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 8)
	menu.add_child(actions)
	var skirmish = _action(actions, "Skirmish", "SKIRMISH", _on_play_button_pressed)
	_action(
		actions,
		"Multiplayer",
		"MULTIPLAYER",
		func(): _open("res://source/main-menu/Multiplayer.tscn")
	)
	_action(actions, "Replays", "REPLAYS", func(): _open("res://source/main-menu/Replays.tscn"))
	skirmish.theme_type_variation = "BattlePrimaryButton"
	_action(
		actions, "Campaign", "CAMPAIGN", func(): _open("res://source/main-menu/CampaignHub.tscn")
	)
	_action(
		actions,
		"ScenarioEditor",
		"SCENARIO EDITOR",
		func(): _open("res://source/scenario/ScenarioEditor.tscn")
	)
	_action(
		actions, "Continue", "CONTINUE / LOAD", func(): get_node("/root/SaveManager").open_dialog()
	)
	_action(
		actions, "World", "WORLD & FACTIONS", func(): _open("res://source/main-menu/World.tscn")
	)
	menu.add_child(HSeparator.new())
	var utilities = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 10)
	menu.add_child(utilities)
	_action(utilities, "Settings", "SETTINGS", _on_options_button_pressed)
	_action(utilities, "Exit", "EXIT", _on_quit_button_pressed)
	var footer = HBoxContainer.new()
	page.add_child(footer)
	var credits = _action(footer, "Credits", "Credits", _on_credits_button_pressed)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	credits.theme_type_variation = "BattleQuietButton"
	credits.custom_minimum_size.y = 32
	skirmish.grab_focus()
	var user_args = OS.get_cmdline_user_args()
	if "--dedicated-server" in user_args or "--server" in user_args:
		_start_dedicated_server.call_deferred()
		return
	if (
		DisplayServer.get_name() == "headless"
		and "--headless-startup-smoke" in user_args
	):
		_finish_headless_smoke.call_deferred()


func _start_dedicated_server():
	var server = load("res://source/match/network/DedicatedServer.gd").new()
	server.name = "DedicatedServer"
	get_tree().root.add_child(server)


func _finish_headless_smoke():
	for _frame in 120:
		await get_tree().process_frame
	if get_tree().current_scene != self or find_child("MenuActions", true, false) == null:
		push_error("Headless startup smoke did not retain the ordinary ready menu")
		await Globals.quit_game(1)
		return
	print("Headless startup smoke: ordinary_menu_ready frames=120")
	await Globals.quit_game()


func _action(parent, node_name, caption, callback):
	var button = Button.new()
	button.name = node_name
	button.text = tr(caption)
	button.custom_minimum_size.y = 40
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
