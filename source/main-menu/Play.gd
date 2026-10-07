extends Control

const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const LoadingScene = preload("res://source/main-menu/Loading.tscn")
const MAPS = [
	[
		"res://source/match/maps/DesertFrontier.tscn",
		"Desert Frontier",
		"Central staging ground · two flanks · outer electronics",
		"128 × 96"
	],
	[
		"res://source/match/maps/PlainAndSimple.tscn",
		"Open Plains",
		"Close bases · open ground · quick engagements",
		"50 × 50"
	],
	[
		"res://source/match/maps/BigArena.tscn",
		"Great Expanse",
		"Longer supply lines · room to expand",
		"100 × 100"
	],
	[
		"res://source/match/maps/AlpineRelay.tscn",
		"Alpine Relay",
		"Two passes · rear bypass · infantry capture relays for vision",
		"128 × 104"
	],
	[
		"res://source/match/maps/IndustrialCrossroads.tscn",
		"Industrial Crossroads",
		"Three streets · opaque warehouses · infantry vision relays",
		"128 × 104"
	],
	[
		"res://source/match/maps/CoastalFoundry.tscn",
		"Coastal Foundry",
		"Harbor inlet · quay and inland routes · aircraft cross the water",
		"128 × 104"
	],
]
const FACTION_DESCRIPTIONS = [
	"Heavy armor and durable firepower.\nHold ground and support your tanks.",
	"Fast machines and extended scouting.\nSpend electronics on precision units.",
	"Mobile refurbished armor and cheaper retrofits.\nRecover wrecks with your engineers.",
	"Bastion, Helix or Frontier, chosen when the battle starts.",
]
var preferences_path = "user://skirmish.cfg"
var _map_paths = []
var _map_list = null
var _preview = null
var _map_details = null
var _player_faction = null
var _enemy_faction = null
var _difficulty = null
var _start_mode = null
var _start_button = null
var _summary = null
var _cards = []
var _starting = false


func _ready():
	_build_ui()
	_load_preferences()
	_on_map_list_item_selected(_map_list.selected)
	_update_faction(0, _player_faction.selected)
	_update_faction(1, _enemy_faction.selected)
	_update_summary()
	_start_button.grab_focus()


func _build_ui():
	var backdrop = ColorRect.new()
	backdrop.color = Color("0c1520")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	_label(page, "SKIRMISH", 30)
	_label(
		page,
		"Choose your battlefield. Build your army. Defeat the enemy command.",
		15,
		Color("a8b8c8")
	)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)
	var map_column = _panel(body)
	map_column.custom_minimum_size.x = 390
	_label(map_column, "01  BATTLEFIELD", 14, Color("a8b8c8"))
	_map_list = OptionButton.new()
	_map_list.name = "MapList"
	_map_list.custom_minimum_size.y = 42
	map_column.add_child(_map_list)
	for entry in MAPS:
		_map_paths.append(entry[0])
		_map_list.add_item(entry[1])
	_map_list.item_selected.connect(_on_map_list_item_selected)
	_preview = load("res://source/main-menu/SkirmishMapPreview.gd").new()
	_preview.custom_minimum_size.y = 240
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_child(_preview)
	_map_details = _label(map_column, "", 14, Color("bdcbd8"))
	_label(
		map_column,
		(
			"1  Your base    2  Enemy base\n"
			+ "Dots: resources · Small squares: relays\nBlocks: buildings · Lines: roads · Blue: water"
		),
		13,
		Color("93a5b7")
	)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.35
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var faction_row = HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 16)
	right.add_child(faction_row)
	_player_faction = _faction_card(faction_row, "02  YOUR FACTION", 0)
	_enemy_faction = _faction_card(faction_row, "03  ENEMY FACTION", 1)
	var rules = _panel(right)
	_label(rules, "MATCH RULES", 14, Color("a8b8c8"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	rules.add_child(grid)
	_label(grid, "AI difficulty", 15)
	_difficulty = _option(grid, "Difficulty", ["Easy", "Normal", "Hard"])
	_label(grid, "Starting forces", 15)
	_start_mode = _option(
		grid, "StartMode", ["Standard — build your base", "Advanced — armor and technology"]
	)
	_summary = _label(rules, "", 14, Color("bdcbd8"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty.item_selected.connect(func(_index): _update_summary())
	_start_mode.item_selected.connect(func(_index): _update_summary())
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	page.add_child(footer)
	var back = Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(130, 48)
	back.pressed.connect(_on_back_button_pressed)
	footer.add_child(back)
	var note = _label(
		footer, "1 vs 1 · Fog of war · Tactical pause · 100 units per side", 14, Color("a8b8c8")
	)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.text = "START BATTLE  →"
	_start_button.custom_minimum_size = Vector2(250, 48)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("d8af67")
	style.set_corner_radius_all(7)
	_start_button.add_theme_stylebox_override("normal", style)
	_start_button.add_theme_color_override("font_color", Color("142130"))
	_start_button.pressed.connect(_on_start_button_pressed)
	footer.add_child(_start_button)


func _panel(parent):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color("192633")
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _label(parent, value, font_size, color_value = Color("edf2f7")):
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	parent.add_child(label)
	return label


func _option(parent, node_name, items):
	var choice = OptionButton.new()
	choice.name = node_name
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = 38
	choice.add_theme_font_size_override("font_size", 15)
	for item in items:
		choice.add_item(item)
	parent.add_child(choice)
	return choice


func _faction_card(parent, heading, index):
	var box = _panel(parent)
	_label(box, heading, 14, Color("a8b8c8"))
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(140, 82)
	box.add_child(portrait)
	var choice = _option(
		box,
		"PlayerFaction" if index == 0 else "EnemyFaction",
		["Bastion", "Helix", "Frontier", "Random"]
	)
	var description = _label(box, "", 13, Color("bdcbd8"))
	description.custom_minimum_size.y = 44
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cards.append({"portrait": portrait, "description": description})
	choice.item_selected.connect(func(selected): _update_faction(index, selected))
	return choice


func _update_faction(index, selected):
	_cards[index].description.text = FACTION_DESCRIPTIONS[selected]
	_cards[index].portrait.texture = load(
		Factions.icon(
			Factions.IDS[selected] if selected < Factions.IDS.size() else "bastion",
			"Tank" if selected < Factions.IDS.size() else "Drone"
		)
	)


func _update_summary():
	var opening = (
		"HQ, 4 engineers, 2 infantry · 60 M / 12 E"
		if _start_mode.selected == 0
		else "Established base, 2 tanks, repair support · 120 M / 60 E"
	)
	_summary.text = (
		opening + "\nWin by destroying the enemy HQ and preventing a rebuild for 60 seconds."
	)
	_summary.tooltip_text = "Difficulty changes AI timing. No health, damage or resource bonuses."


func _on_map_list_item_selected(index):
	_preview.set_map(MAPS[index][0])
	_map_details.text = MAPS[index][2] + "\n" + MAPS[index][3] + " · Opposite starting positions"


func _create_match_settings():
	var result = MatchSettings.new()
	result.skirmish = true
	result.advanced_start = _start_mode.selected == 1
	result.map_path = _get_selected_map_path()
	result.match_seed = randi() & 0x7fffffff
	var rng = RandomNumberGenerator.new()
	rng.seed = result.match_seed
	for index in range(2):
		var player = PlayerSettings.new()
		player.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		var selected = _player_faction.selected if index == 0 else _enemy_faction.selected
		player.faction = Factions.IDS[
			rng.randi_range(0, Factions.IDS.size() - 1)
			if selected == Factions.IDS.size()
			else selected
		]
		player.color = Color("e0ad46") if index == 0 else Color("d86965")
		player.difficulty = _difficulty.selected
		player.spawn_index_offset = (
			0 if index == 0 else Constants.Match.MAPS[result.map_path].players / 2 - 1
		)
		result.players.append(player)
	return result


func _get_selected_map_path():
	return _map_paths[_map_list.selected]


func _on_start_button_pressed():
	if _starting:
		return
	_starting = true
	_start_button.disabled = true
	_save_preferences()
	var loading = LoadingScene.instantiate()
	loading.match_settings = _create_match_settings()
	loading.map_path = _get_selected_map_path()
	get_parent().add_child(loading)
	get_tree().current_scene = loading
	queue_free()


func _save_preferences():
	var config = ConfigFile.new()
	for pair in [
		["map", _map_list],
		["player", _player_faction],
		["enemy", _enemy_faction],
		["difficulty", _difficulty],
		["start", _start_mode]
	]:
		var value = pair[1].selected
		if pair[0] in ["player", "enemy"]:
			value = (Factions.IDS + ["random"])[value]
		config.set_value("setup", pair[0], value)
	config.save(preferences_path)


func _load_preferences():
	var config = ConfigFile.new()
	config.load(preferences_path)
	for pair in [
		["map", _map_list, 0],
		["player", _player_faction, "bastion"],
		["enemy", _enemy_faction, "random"],
		["difficulty", _difficulty, 1],
		["start", _start_mode, 0]
	]:
		var value = config.get_value("setup", pair[0], pair[2])
		if pair[0] in ["player", "enemy"]:
			# Old index 2 meant Random. Persist stable IDs before adding further factions.
			if value is int:
				value = ["bastion", "helix", "random"][clampi(value, 0, 2)]
			value = (Factions.IDS + ["random"]).find(value)
			if value < 0:
				value = 0 if pair[0] == "player" else Factions.IDS.size()
		pair[1].select(clampi(int(value), 0, pair[1].item_count - 1))


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
