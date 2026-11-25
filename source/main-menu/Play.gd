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
		"res://source/match/maps/battlefields/AlpineRelayMap.tscn",
		"Alpine Relay",
		"Two cols cut a snowbound massif · capture relays for local vision · 12 resource fields",
		"192 × 160"
	],
	[
		"res://source/match/maps/battlefields/CoastalFoundryMap.tscn",
		"Coastal Foundry",
		(
			"A harbour town with a ship foundry · over the fort hill, the swing bridge"
			+ " or the mole · 12 resource fields"
		),
		"192 × 160"
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
		"res://source/match/maps/battlefields/GlacierNarrowsMap.tscn",
		"Glacier Narrows",
		(
			"A fjord head below a glacier · cross by the moraine, the lakeshore, the dam"
			+ " or the outwash ford · 14 resource fields"
		),
		"192 × 160"
	],
	[
		"res://source/match/maps/battlefields/EmberworksMap.tscn",
		"Emberworks",
		"A steelworks split by its canal · two bridges under the slag heaps · 14 resource fields",
		"192 × 160"
	],
	[
		"res://source/match/maps/battlefields/CinderRingMap.tscn",
		"Cinder Ring",
		"A caldera around a lava lake · climb the crater rim or pass its breaches · 24 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/FourRiversMap.tscn",
		"Four Rivers",
		"Farmland where four rivers meet · hedged fields, stone bridges and fords · 16 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/SunkenExchangeMap.tscn",
		"Sunken Exchange",
		"A drowned port city · canals and bridges round the flooded exchange · 24 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/FrostboundCrownMap.tscn",
		"Frostbound Crown",
		"A polar research plateau · crevasse fields ring a radar crown · 24 resource fields",
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
		"res://source/match/maps/battlefields/RailspireJunctionMap.tscn",
		"Railspire Junction",
		"Four track fields meet at a signal box · overpasses over long sightlines · 24 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/ShatteredOasisMap.tscn",
		"Shattered Oasis",
		"A palm-grove oasis split by dry wadis · caravanserai camps · 16 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/TripointBasinMap.tscn",
		"Tripoint Basin",
		"A three-way canyon basin · elevated mesas over rolling dunes · 15 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/HighlandCrownMap.tscn",
		"Highland Crown",
		"Three wooded ridges around a moated watchtower island · bridges and fords · 15 resource fields",
		"224 × 224"
	],
	[
		"res://source/match/maps/battlefields/IronTriadMap.tscn",
		"Iron Triad",
		"Three foundry terraces above a Y-shaped canal and rail spurs · 15 resource fields",
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
	"AlpineRelay": "res://source/match/maps/battlefields/AlpineRelayMap.tscn",
	"ExpandedAlpineRelay": "res://source/match/maps/battlefields/AlpineRelayMap.tscn",
	"GlacierNarrows": "res://source/match/maps/battlefields/GlacierNarrowsMap.tscn",
	"FrostboundCrown": "res://source/match/maps/battlefields/FrostboundCrownMap.tscn",
	"CoastalFoundry": "res://source/match/maps/battlefields/CoastalFoundryMap.tscn",
	"ExpandedCoastalFoundry": "res://source/match/maps/battlefields/CoastalFoundryMap.tscn",
	"Emberworks": "res://source/match/maps/battlefields/EmberworksMap.tscn",
	"CinderRing": "res://source/match/maps/battlefields/CinderRingMap.tscn",
	"SunkenExchange": "res://source/match/maps/battlefields/SunkenExchangeMap.tscn",
	"RailspireJunction": "res://source/match/maps/battlefields/RailspireJunctionMap.tscn",
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
var _start_mode = null
var _start_button = null
var _cards = []
var _starting = false
var _body_grid: HBoxContainer
var _game_mode
var _mode_label
var _slots = []


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
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var title = _label(page, "SKIRMISH", 28)
	title.theme_type_variation = "HudHeading"
	_body_grid = HBoxContainer.new()
	_body_grid.name = "SetupBody"
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("separation", 16)
	page.add_child(_body_grid)
	var map_column = _panel(_body_grid)
	map_column.get_parent().size_flags_stretch_ratio = 1.4
	map_column.get_parent().custom_minimum_size.x = 320
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
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_child(preview_frame)
	_preview = load("res://source/main-menu/SkirmishMapPreview.gd").new()
	_preview.custom_minimum_size = Vector2(0, 180)
	_preview.start_selected.connect(_on_preview_start_selected)
	preview_frame.add_child(_preview)
	_map_details = _label(map_column, "", 13, ArtTheme.MUTED)
	_map_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_details.tooltip_text = (
		tr("Dots: resources · Small squares: relays")
		+ "\n"
		+ tr("Blocks: buildings · Lines: roads · Blue: water")
		+ "\n"
		+ tr("R: refinery · D: data relay · M: mercenary camp · S: repair shop")
	)
	var location_hint = _label(map_column, "", 12, ArtTheme.MUTED)
	location_hint.text = tr("Choose a starting location · click or arrow keys")
	location_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 12)
	_body_grid.add_child(right)
	_player_faction = _faction_card(right, "Your faction", 0)
	_enemy_faction = _faction_card(right, "AI factions", 1)
	var rules = _panel(right)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	rules.add_child(grid)
	_label(grid, "AI difficulty", 14, ArtTheme.MUTED)
	_difficulty = _option(grid, "Difficulty", Difficulty.NAMES)
	_label(grid, "Starting forces", 14, ArtTheme.MUTED)
	_start_mode = _option(
		grid, "StartMode", ["Standard — build your base", "Advanced — armor and technology"]
	)
	_difficulty.item_selected.connect(func(_index): _update_summary())
	_start_mode.item_selected.connect(func(_index): _update_summary())
	_mode_label = _label(grid, "Game mode", 14, ArtTheme.MUTED)
	_game_mode = _option(grid, "GameMode", ["Free-for-all", "Teams · 2 vs 2", "Teams · 1 vs 3"])
	_game_mode.item_selected.connect(_apply_teams)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	page.add_child(footer)
	var back = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(100, 40)
	back.pressed.connect(_on_back_button_pressed)
	footer.add_child(back)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "START BATTLE  →"
	_start_button.theme_type_variation = "BattlePrimaryButton"
	_start_button.custom_minimum_size = Vector2(220, 40)
	_start_button.pressed.connect(_on_start_button_pressed)
	footer.add_child(_start_button)


func _panel(parent):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = "HudHousing"
	panel.add_theme_stylebox_override("panel", ArtTheme.section(14, 12))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
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
	choice.custom_minimum_size = Vector2(148, 32)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_theme_font_size_override("font_size", 14)
	for item in items:
		choice.add_item(tr(item))
	parent.add_child(choice)
	return choice


func _faction_card(parent, heading, index):
	var box = _panel(parent)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(52, 52)
	row.add_child(portrait)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	_label(details, tr(heading), 13, ArtTheme.MUTED)
	var choice = _option(
		details,
		"PlayerFaction" if index == 0 else "EnemyFaction",
		["Bastion", "Helix", "Frontier", "Random"]
	)
	_cards.append({"portrait": portrait, "choice": choice})
	choice.item_selected.connect(func(selected): _update_faction(index, selected))
	return choice


func _update_faction(index, selected):
	if index == 0:
		ArtTheme.Console.use_faction(
			Factions.IDS[selected] if selected < Factions.IDS.size() else "bastion"
		)
		theme = ArtTheme.create()
	_cards[index].choice.tooltip_text = (
		tr(FACTION_DESCRIPTIONS[selected])
		+ (
			"\n\n" + tr(Factions.TECH_SUMMARY[Factions.IDS[selected]])
			if selected < Factions.IDS.size()
			else ""
		)
	)
	_cards[index].choice.accessibility_description = _cards[index].choice.tooltip_text
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
	_start_mode.tooltip_text = tr(opening)
	_start_mode.accessibility_description = _start_mode.tooltip_text
	_start_button.tooltip_text = tr(
		"Win by destroying the enemy HQ and preventing a rebuild for 60 seconds."
	)
	_difficulty.tooltip_text = tr(Difficulty.DESCRIPTIONS[_difficulty.selected])
	_difficulty.accessibility_description = _difficulty.tooltip_text


func _on_map_list_item_selected(index):
	_preview.set_map(MAPS[index][0])
	var players: int = Constants.Match.MAPS[MAPS[index][0]].players
	_rebuild_slots(players)
	var player_summary := tr("2 players · Head-to-head")
	if players == 3:
		player_summary = tr("3 players · Free-for-all or 1 vs 2")
	elif players == 4:
		player_summary = tr("4 players · Free-for-all or teams")
	_map_details.text = tr(MAPS[index][2]) + "\n" + MAPS[index][3] + " · " + player_summary
	_sync_preview_slots()


func _rebuild_slots(count):
	if _slots.size() != count:
		_slots.clear()
		for index in count:
			_slots.append({"location": index})
	var modes := ["Free-for-all"]
	if count == 3:
		modes = ["Free-for-all", "Teams · 1 vs 2"]
	elif count == 4:
		modes = ["Free-for-all", "Teams · 2 vs 2", "Teams · 1 vs 3"]
	var previous = _game_mode.selected
	_game_mode.clear()
	for label in modes:
		_game_mode.add_item(tr(label))
	_game_mode.visible = count >= 3
	_mode_label.visible = count >= 3
	_game_mode.select(clampi(previous, 0, modes.size() - 1) if count >= 3 else 0)
	_sync_preview_slots()


func _select_start(index, selected):
	var previous = _slots[index].location
	for other in _slots:
		if other != _slots[index] and other.location == selected:
			other.location = previous
	_slots[index].location = selected
	_sync_preview_slots()


func _on_preview_start_selected(start_index):
	if start_index < 0 or start_index >= _slots.size():
		return
	_select_start(0, start_index)


func _apply_teams(_mode):
	_sync_preview_slots()


func _sync_preview_slots():
	if _preview == null or not is_instance_valid(_preview):
		return
	var assignments = []
	for slot_index in _slots.size():
		var slot = _slots[slot_index]
		var caption = tr("You") if slot_index == 0 else tr("AI %d") % slot_index
		if _game_mode.selected > 0:
			caption += " · " + tr("Team %d") % (_team_for_slot(slot_index) + 1)
		assignments.append(
			{
				"slot": slot_index,
				"location": slot.location,
				"name": caption,
				"color":
				[Color("e2c180"), Color("dd8d81"), Color("88bad4"), Color("b5a1d4")][slot_index % 4]
			}
		)
	_preview.set_slot_assignments(assignments)


func _team_for_slot(index):
	if _game_mode.selected == 0:
		return -1
	if _slots.size() == 3:
		return 0 if index == 0 else 1
	return index / 2 if _game_mode.selected == 1 else mini(index, 1)


func _create_match_settings():
	_rebuild_slots(Constants.Match.MAPS[_get_selected_map_path()].players)
	var result = MatchSettings.new()
	result.skirmish = true
	result.advanced_start = _start_mode.selected == 1
	result.map_path = _get_selected_map_path()
	result.match_seed = randi() & 0x7fffffff
	# New matches use the standard rules, regardless of retired setup preferences.
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
		player.spawn_index = _slots[index].location
		player.team = _team_for_slot(index)
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
		["mode", _game_mode],
	]:
		if pair[1] == null:
			continue
		var value = pair[1].selected
		if pair[0] == "map":
			value = _map_paths[value]
		if pair[0] in ["player", "enemy"]:
			value = (Factions.IDS + ["random"])[value]
		config.set_value("setup", pair[0], value)
	config.set_value("setup", "locations", _slots.map(func(slot): return slot.location))
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
		["mode", _game_mode, 0],
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
		if pair[0] == "mode" and int(value) not in [0, 1, 2]:
			value = 0
		pair[1].select(clampi(int(value), 0, pair[1].item_count - 1))
	_on_map_list_item_selected(_map_list.selected)
	var locations = config.get_value("setup", "locations", [])
	# Keep previously chosen map positions, but retire hidden per-player overrides.
	if not config.has_section_key("setup", "locations"):
		var old_slots = config.get_value("setup", "slots", [])
		if (
			old_slots is Array
			and old_slots.all(func(slot): return slot is Array and slot.size() == 4)
		):
			locations = old_slots.map(func(slot): return slot[2])
	_load_locations(locations)
	_sync_preview_slots()


func _load_locations(locations):
	if not locations is Array or locations.size() != _slots.size():
		return
	var seen = []
	for location in locations:
		if not location is int or location < 0 or location >= _slots.size() or location in seen:
			return
		seen.append(location)
	for index in _slots.size():
		_slots[index].location = locations[index]


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
