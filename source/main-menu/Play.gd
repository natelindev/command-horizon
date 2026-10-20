extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const LoadingScene = preload("res://source/main-menu/Loading.tscn")
const Lore = preload("res://source/lore/WorldLore.gd")
const Difficulty = preload("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
# Skirmish roster; the first entry is the default for a fresh setup.
const MAPS = [
	[
		"res://source/match/maps/battlefields/DesertFrontierMap.tscn",
		"Desert Frontier",
		"A Mojave rail outpost · three routes past sandstone escarpments · 12 resource fields",
		"192 × 144"
	],
	[
		"res://source/match/maps/ExpandedAlpineRelay.tscn",
		"Alpine Relay",
		"Wide mountain passes · eight resource fields · six capturable facilities",
		"192 × 156"
	],
	[
		"res://source/match/maps/ExpandedCoastalFoundry.tscn",
		"Coastal Foundry",
		"Wide harbor routes · eight resource fields · six capturable facilities",
		"192 × 156"
	],
	[
		"res://source/match/maps/battlefields/RedrockDivideMap.tscn",
		"Redrock Divide",
		(
			"A sandstone mesa splits the canyon · cross by the wash or slot canyons"
			+ " · 14 resource fields"
		),
		"192 × 160"
	],
	[
		"res://source/match/maps/battlefields/SaltwindBasinMap.tscn",
		"Saltwind Basin",
		"Rim terraces above an exposed salt pan · potash ponds crossed by dikes · 12 resource fields",
		"192 × 160"
	],
	[
		"res://source/match/maps/battlefields/PinebreakValleyMap.tscn",
		"Pinebreak Valley",
		(
			"A logging valley split by a river · fir stands, a log bridge and gravel fords"
			+ " · 12 resource fields"
		),
		"192 × 160"
	],
	[
		"res://source/match/maps/GlacierNarrows.tscn",
		"Glacier Narrows",
		"Frozen meltwater divides two broad mountain passes.",
		"192 × 160"
	],
	[
		"res://source/match/maps/Emberworks.tscn",
		"Emberworks",
		"Abandoned furnaces and service alleys around a central works.",
		"192 × 160"
	],
	[
		"res://source/match/maps/CinderRing.tscn",
		"Cinder Ring",
		"A black volcanic caldera with an open outer circuit.",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/FourRiversMap.tscn",
		"Four Rivers",
		"Farmland where four rivers meet · hedged fields, stone bridges and fords · 16 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/SunkenExchange.tscn",
		"Sunken Exchange",
		"Flooded port basins leave a cross of cargo roads.",
		"224 × 224"
	],
	[
		"res://source/match/maps/FrostboundCrown.tscn",
		"Frostbound Crown",
		"A crown of glacial shelves guards the central repair network.",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/CopperBadlandsMap.tscn",
		"Copper Badlands",
		"An open-pit copper mine · haul roads spiral down to a contested pit floor · 16 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/VerdantCommonsMap.tscn",
		"Verdant Commons",
		"A village green ringed by groves · lanes, walled fields and chalk downs · 16 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/RailspireJunction.tscn",
		"Railspire Junction",
		"Rail depots divide a grid of long industrial sightlines.",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/ShatteredOasisMap.tscn",
		"Shattered Oasis",
		"A palm-grove oasis split by dry wadis · caravanserai camps · 16 resource fields",
		"224 × 224"
	],
]
# Old numeric preferences used this order. Resolve them before selecting a new index.
const LEGACY_MAP_NAMES = [
	"DesertFrontier",
	"PlainAndSimple",
	"BigArena",
	"AlpineRelay",
	"IndustrialCrossroads",
	"CoastalFoundry",
	"ExpandedDesertFrontier",
	"ExpandedAlpineRelay",
	"ExpandedCoastalFoundry"
]

# Saved preferences may name maps that left the roster; open their successors.
const SUCCESSORS = {
	"BastionDesert": "res://source/match/maps/battlefields/DesertFrontierMap.tscn",
	"DesertFrontier": "res://source/match/maps/battlefields/DesertFrontierMap.tscn",
	"ExpandedDesertFrontier": "res://source/match/maps/battlefields/DesertFrontierMap.tscn",
	"RedrockDivide": "res://source/match/maps/battlefields/RedrockDivideMap.tscn",
	"SaltwindBasin": "res://source/match/maps/battlefields/SaltwindBasinMap.tscn",
	"CopperBadlands": "res://source/match/maps/battlefields/CopperBadlandsMap.tscn",
	"ShatteredOasis": "res://source/match/maps/battlefields/ShatteredOasisMap.tscn",
	"PinebreakValley": "res://source/match/maps/battlefields/PinebreakValleyMap.tscn",
	"FourRivers": "res://source/match/maps/battlefields/FourRiversMap.tscn",
	"VerdantCommons": "res://source/match/maps/battlefields/VerdantCommonsMap.tscn",
	"AlpineRelay": "res://source/match/maps/ExpandedAlpineRelay.tscn",
	"CoastalFoundry": "res://source/match/maps/ExpandedCoastalFoundry.tscn",
}

const FACTION_DESCRIPTIONS = [
	Lore.FACTIONS.bastion.short,
	Lore.FACTIONS.helix.short,
	Lore.FACTIONS.frontier.short,
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
var _difficulty_note = null
var _start_mode = null
var _doctrine_selector = null
var _start_button = null
var _summary = null
var _cards = []
var _starting = false
var _body_grid: GridContainer


func _ready():
	theme = ArtTheme.create()
	_build_ui()
	_load_preferences()
	_on_map_list_item_selected(_map_list.selected)
	_update_faction(0, _player_faction.selected)
	_update_faction(1, _enemy_faction.selected)
	_update_summary()
	_start_button.grab_focus()


func _build_ui():
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .68
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var title = _label(page, "SKIRMISH", 28)
	title.theme_type_variation = "HudHeading"
	var scroll = ScrollContainer.new()
	scroll.name = "SetupScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	_body_grid = GridContainer.new()
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 20)
	_body_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_body_grid)
	var map_column = _panel(_body_grid)
	_label(map_column, "Battlefield", 18).theme_type_variation = "HudHeading"
	_map_list = _option(map_column, "MapList", [])
	for entry in MAPS:
		_map_paths.append(entry[0])
		_map_list.add_item(
			tr(entry[1]) + " · " + (tr("%d players") % Constants.Match.MAPS[entry[0]].players)
		)
	_map_list.item_selected.connect(_on_map_list_item_selected)
	var preview_frame = PanelContainer.new()
	preview_frame.theme_type_variation = "HudSocket"
	map_column.add_child(preview_frame)
	_preview = load("res://source/main-menu/SkirmishMapPreview.gd").new()
	_preview.custom_minimum_size.y = 280
	preview_frame.add_child(_preview)
	_map_details = _label(map_column, "", 13, ArtTheme.MUTED)
	_map_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var legend_toggle = Button.new()
	legend_toggle.text = "Map legend"
	legend_toggle.theme_type_variation = "BattleQuietButton"
	legend_toggle.toggle_mode = true
	map_column.add_child(legend_toggle)
	var legend = _label(map_column, "", 12, ArtTheme.MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = (
		"1  "
		+ tr("Your base")
		+ "    2  "
		+ tr("Enemy bases")
		+ "\n"
		+ tr("Dots: resources · Small squares: relays")
		+ "\n"
		+ tr("Blocks: buildings · Lines: roads · Blue: water")
		+ "\n"
		+ tr("R: refinery · M: mercenary camp · +: repair shop")
	)
	legend.hide()
	legend_toggle.toggled.connect(func(shown): legend.visible = shown)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	_body_grid.add_child(right)
	var faction_row = HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 12)
	right.add_child(faction_row)
	_player_faction = _faction_card(faction_row, "Your faction", 0)
	_enemy_faction = _faction_card(faction_row, "AI factions", 1)
	var rules = _panel(right)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	rules.add_child(grid)
	_label(grid, "AI difficulty", 14, ArtTheme.MUTED)
	_difficulty = _option(grid, "Difficulty", Difficulty.NAMES)
	_difficulty.tooltip_text = tr(
		"AI levels change decisions only. No health, damage or resource bonuses."
	)
	grid.add_child(Control.new())
	_difficulty_note = _label(grid, "", 12, ArtTheme.MUTED)
	_difficulty_note.name = "DifficultyNote"
	_difficulty_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(grid, "Starting forces", 14, ArtTheme.MUTED)
	_start_mode = _option(
		grid, "StartMode", ["Standard — build your base", "Advanced — armor and technology"]
	)
	_label(grid, "Tactical doctrine", 14, ArtTheme.MUTED)
	_doctrine_selector = _option(
		grid,
		"TacticalDoctrine",
		["Standard Field Protocol", "Hit & Run Kiting", "Ironclad Defense"]
	)
	_summary = _label(rules, "", 12, ArtTheme.MUTED)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty.item_selected.connect(func(_index): _update_summary())
	_start_mode.item_selected.connect(func(_index): _update_summary())
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	page.add_child(footer)
	var back = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(100, 46)
	back.pressed.connect(_on_back_button_pressed)
	footer.add_child(back)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "START BATTLE  →"
	_start_button.theme_type_variation = "BattlePrimaryButton"
	_start_button.custom_minimum_size = Vector2(220, 46)
	_start_button.pressed.connect(_on_start_button_pressed)
	footer.add_child(_start_button)
	resized.connect(_layout_setup)
	_layout_setup()


func _layout_setup():
	_body_grid.columns = 2 if size.x >= 1100 else 1
	_preview.custom_minimum_size.y = clampf(size.y * .34, 200, 360)


func _panel(parent):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = "HudHousing"
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _label(parent, value, font_size, color_value = Color("f1eee4")):
	var label = Label.new()
	label.text = tr(value)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	parent.add_child(label)
	return label


func _option(parent, node_name, items):
	var choice = OptionButton.new()
	choice.name = node_name
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size = Vector2(160, 38)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_theme_font_size_override("font_size", 14)
	for item in items:
		choice.add_item(tr(item))
	parent.add_child(choice)
	return choice


func _faction_card(parent, heading, index):
	var box = _panel(parent)
	_label(box, tr(heading), 13, Color("d8a846"))

	var portrait_box = PanelContainer.new()
	portrait_box.theme_type_variation = "HudSocket"
	box.add_child(portrait_box)

	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(100, 88)
	portrait_box.add_child(portrait)

	var choice = _option(
		box,
		"PlayerFaction" if index == 0 else "EnemyFaction",
		["Bastion", "Helix", "Frontier", "Random"]
	)
	var description = _label(box, "", 12, Color("9eb0b8"))
	description.custom_minimum_size.y = 44
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cards.append({"portrait": portrait, "description": description})
	choice.item_selected.connect(func(selected): _update_faction(index, selected))
	return choice


func _update_faction(index, selected):
	if index == 0:
		ArtTheme.Console.use_faction(
			Factions.IDS[selected] if selected < Factions.IDS.size() else "bastion"
		)
		theme = ArtTheme.create()
	_cards[index].description.text = tr(FACTION_DESCRIPTIONS[selected])
	_cards[index].description.tooltip_text = (
		tr(Factions.TECH_SUMMARY[Factions.IDS[selected]]) if selected < Factions.IDS.size() else ""
	)
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
	_summary.text = (tr(opening))
	_start_button.tooltip_text = tr(
		"Win by destroying the enemy HQ and preventing a rebuild for 60 seconds."
	)
	_difficulty_note.text = tr(Difficulty.DESCRIPTIONS[_difficulty.selected])


func _on_map_list_item_selected(index):
	_preview.set_map(MAPS[index][0])
	_map_details.text = (
		tr(MAPS[index][2])
		+ "\n"
		+ MAPS[index][3]
		+ " · "
		+ (
			tr("4 players · Free-for-all")
			if Constants.Match.MAPS[MAPS[index][0]].players == 4
			else tr("2 players · Head-to-head")
		)
	)


func _create_match_settings():
	var result = MatchSettings.new()
	result.skirmish = true
	result.advanced_start = _start_mode.selected == 1
	result.map_path = _get_selected_map_path()
	result.match_seed = randi() & 0x7fffffff
	var doctrine_keys = ["balanced", "kiting", "ironclad"]
	result.tactical_doctrine = (
		doctrine_keys[_doctrine_selector.selected] if _doctrine_selector != null else "balanced"
	)
	var rng = RandomNumberGenerator.new()
	rng.seed = result.match_seed
	for index in range(Constants.Match.MAPS[result.map_path].players):
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
		player.color = Constants.Player.COLORS[index]
		# The level belongs to the computer commander; the human keeps the default.
		if index > 0:
			player.difficulty = _difficulty.selected
		player.spawn_index_offset = 0
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
		["start", _start_mode],
		["doctrine", _doctrine_selector]
	]:
		if pair[1] == null:
			continue
		var value = pair[1].selected
		if pair[0] == "map":
			value = _map_paths[value]
		if pair[0] in ["player", "enemy"]:
			value = (Factions.IDS + ["random"])[value]
		config.set_value("setup", pair[0], value)
	config.save(preferences_path)


func _load_preferences():
	var config = ConfigFile.new()
	config.load(preferences_path)
	for pair in [
		["map", _map_list, MAPS[0][0]],
		["player", _player_faction, "bastion"],
		["enemy", _enemy_faction, "random"],
		["difficulty", _difficulty, 1],
		["start", _start_mode, 0],
		["doctrine", _doctrine_selector, 0]
	]:
		if pair[1] == null:
			continue
		var value = config.get_value("setup", pair[0], pair[2])
		if pair[0] == "map":
			if value is int:
				value = "res://source/match/maps/%s.tscn" % LEGACY_MAP_NAMES[clampi(value, 0, 8)]
			if str(value) not in _map_paths:
				value = SUCCESSORS.get(str(value).get_file().get_basename(), MAPS[0][0])
			value = _map_paths.find(str(value))
			if value < 0:
				value = 0
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
