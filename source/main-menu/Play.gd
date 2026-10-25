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
var _doctrine_selector = null
var _start_button = null
var _cards = []
var _starting = false
var _body_grid: GridContainer
var _game_mode
var _resources
var _visibility
var _events
var _random_starts
var _slots_grid
var _slots = []
var _setup_status


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
	_preview.start_selected.connect(_on_preview_start_selected)
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
		+ tr("Starting locations")
		+ "    2  "
		+ tr("Player slots choose these numbers")
		+ "\n"
		+ tr("Dots: resources · Small squares: relays")
		+ "\n"
		+ tr("Blocks: buildings · Lines: roads · Blue: water")
		+ "\n"
		+ tr("R: refinery · M: mercenary camp · S: repair shop")
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
	_difficulty.item_selected.connect(func(_index): _update_summary())
	_start_mode.item_selected.connect(func(_index): _update_summary())
	_label(grid, "Game mode", 14, ArtTheme.MUTED)
	_game_mode = _option(
		grid, "GameMode", ["Free-for-all", "Teams · 2 vs 2", "Teams · 1 vs 3", "Custom teams"]
	)
	_game_mode.item_selected.connect(_apply_teams)
	_label(grid, "Starting resources", 14, ArtTheme.MUTED)
	_resources = _option(
		grid, "StartingResources", ["Standard resources", "Double resources", "Quadruple resources"]
	)
	_label(grid, "Visibility", 14, ArtTheme.MUTED)
	_visibility = _option(
		grid, "Visibility", ["Team vision · fog of war", "All players · fog of war", "Reveal map"]
	)
	_label(grid, "Battlefield events", 14, ArtTheme.MUTED)
	_events = _option(grid, "BattlefieldEvents", ["On", "Off"])
	var slots_panel = _panel(right)
	_label(slots_panel, "Player slots", 18).theme_type_variation = "HudHeading"
	_random_starts = CheckButton.new()
	_random_starts.text = tr("Random starting locations")
	slots_panel.add_child(_random_starts)
	_random_starts.toggled.connect(func(_enabled): _refresh_slots())
	_slots_grid = GridContainer.new()
	_slots_grid.columns = 5
	_slots_grid.add_theme_constant_override("h_separation", 6)
	_slots_grid.add_theme_constant_override("v_separation", 6)
	slots_panel.add_child(_slots_grid)
	_setup_status = _label(slots_panel, "", 12, ArtTheme.MUTED)
	_setup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_start_mode.tooltip_text = tr(opening)
	_start_mode.accessibility_description = _start_mode.tooltip_text
	_start_button.tooltip_text = tr(
		"Win by destroying the enemy HQ and preventing a rebuild for 60 seconds."
	)
	_difficulty.tooltip_text = tr(Difficulty.DESCRIPTIONS[_difficulty.selected])
	_difficulty.accessibility_description = _difficulty.tooltip_text


func _on_map_list_item_selected(index):
	_preview.set_map(MAPS[index][0])
	_events.disabled = not load("res://source/match/world/BattlefieldEvents.gd").supported(
		MAPS[index][0]
	)
	_events.tooltip_text = (
		tr("Automatic events with small optional rewards")
		if not _events.disabled
		else tr("No events on this battlefield")
	)
	_rebuild_slots(Constants.Match.MAPS[MAPS[index][0]].players)
	_map_details.text = (
		tr(MAPS[index][2])
		+ "\n"
		+ MAPS[index][3]
		+ " · "
		+ (
			tr("4 players · Free-for-all or teams")
			if Constants.Match.MAPS[MAPS[index][0]].players == 4
			else tr("2 players · Head-to-head")
		)
	)
	_refresh_slots()


func _rebuild_slots(count):
	if _slots.size() == count:
		return
	for child in _slots_grid.get_children():
		_slots_grid.remove_child(child)
		child.queue_free()
	_slots.clear()
	for heading in ["Player", "Faction", "Difficulty", "Starting position", "Team"]:
		_label(_slots_grid, heading, 12, ArtTheme.MUTED)
	for index in count:
		_label(_slots_grid, tr("You") if index == 0 else tr("AI %d") % index, 12)
		var faction = _option(
			_slots_grid,
			"SlotFaction%d" % index,
			["Use faction above", "Bastion", "Helix", "Frontier", "Random"]
		)
		var difficulty = _option(
			_slots_grid, "SlotDifficulty%d" % index, ["Use AI difficulty"] + Difficulty.NAMES
		)
		difficulty.disabled = index == 0
		var start_items = []
		for location in count:
			start_items.append(tr("Start %d") % (location + 1))
		var start = _option(_slots_grid, "SlotStart%d" % index, start_items)
		start.select(index)
		start.item_selected.connect(func(selected): _select_start(index, selected))
		var team = _option(
			_slots_grid, "SlotTeam%d" % index, ["Team 1", "Team 2", "Team 3", "Team 4"]
		)
		team.select(index)
		team.item_selected.connect(func(_selected): _refresh_slots())
		for option in [faction, difficulty, start, team]:
			option.custom_minimum_size.x = 60
		_slots.append(
			{
				"faction": faction,
				"difficulty": difficulty,
				"start": start,
				"team": team,
				"location": index
			}
		)
	_game_mode.set_item_disabled(1, count != 4)
	_game_mode.set_item_disabled(2, count != 4)
	if count != 4 and _game_mode.selected in [1, 2]:
		_game_mode.select(0)
	_apply_teams(_game_mode.selected)


func _select_start(index, selected):
	var previous = _slots[index].location
	for other in _slots:
		if other != _slots[index] and other.location == selected:
			other.location = previous
			other.start.select(previous)
	_slots[index].location = selected
	_slots[index].start.select(selected)
	_refresh_slots()


func _on_preview_start_selected(start_index):
	if _slots.is_empty() or start_index < 0 or start_index >= _slots.size():
		return
	if _random_starts.button_pressed:
		_random_starts.button_pressed = false
	_select_start(0, start_index)


func _apply_teams(mode):
	for index in _slots.size():
		if mode != 3:
			_slots[index].team.select(
				index / 2 if mode == 1 else (mini(index, 1) if mode == 2 else index)
			)
	_refresh_slots()


func _refresh_slots():
	var teams = []
	for slot in _slots:
		slot.start.disabled = _random_starts.button_pressed
		slot.team.disabled = _game_mode.selected != 3
		teams.append(slot.team.selected)
	var valid = _game_mode.selected == 0 or teams.any(func(team): return team != teams[0])
	if _start_button != null:
		_start_button.disabled = not valid or _starting
	_setup_status.text = (
		tr("Choose at least two opposing teams.")
		if not valid
		else tr("Start numbers match the map preview. Choosing an occupied start swaps players.")
	)
	_sync_preview_slots()


func _sync_preview_slots():
	if _preview == null or not is_instance_valid(_preview):
		return
	var assignments = []
	for slot_index in _slots.size():
		var slot = _slots[slot_index]
		assignments.append(
			{
				"slot": slot_index,
				"location": slot.location,
				"name": tr("You") if slot_index == 0 else tr("AI %d") % slot_index,
				"color":
				[Color("e2c180"), Color("dd8d81"), Color("88bad4"), Color("b5a1d4")][slot_index % 4]
			}
		)
	_preview.set_slot_assignments(assignments)


func _create_match_settings():
	_rebuild_slots(Constants.Match.MAPS[_get_selected_map_path()].players)
	var result = MatchSettings.new()
	result.skirmish = true
	result.advanced_start = _start_mode.selected == 1
	result.map_path = _get_selected_map_path()
	result.match_seed = randi() & 0x7fffffff
	result.visibility = _visibility.selected
	result.battlefield_events = not _events.disabled and _events.selected == 0
	result.starting_resources_multiplier = [1, 2, 4][_resources.selected]
	var doctrine_keys = ["balanced", "kiting", "ironclad"]
	result.tactical_doctrine = (
		doctrine_keys[_doctrine_selector.selected] if _doctrine_selector != null else "balanced"
	)
	var rng = RandomNumberGenerator.new()
	rng.seed = result.match_seed
	var locations = range(_slots.size())
	if _random_starts.button_pressed:
		for index in range(locations.size() - 1, 0, -1):
			var other = rng.randi_range(0, index)
			var previous = locations[index]
			locations[index] = locations[other]
			locations[other] = previous
	for index in range(Constants.Match.MAPS[result.map_path].players):
		var player = PlayerSettings.new()
		player.controller = (
			Constants.PlayerType.HUMAN if index == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		var selected = _player_faction.selected if index == 0 else _enemy_faction.selected
		if _slots[index].faction.selected > 0:
			selected = _slots[index].faction.selected - 1
		player.faction = Factions.IDS[
			rng.randi_range(0, Factions.IDS.size() - 1)
			if selected == Factions.IDS.size()
			else selected
		]
		player.color = Constants.Player.COLORS[index]
		# The level belongs to the computer commander; the human keeps the default.
		if index > 0:
			player.difficulty = _difficulty.selected
			if _slots[index].difficulty.selected > 0:
				player.difficulty = _slots[index].difficulty.selected - 1
		player.spawn_index_offset = 0
		player.spawn_index = (
			locations[index] if _random_starts.button_pressed else _slots[index].location
		)
		player.team = -1 if _game_mode.selected == 0 else _slots[index].team.selected
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
		["doctrine", _doctrine_selector],
		["mode", _game_mode],
		["resources", _resources],
		["visibility", _visibility],
		["events", _events]
	]:
		if pair[1] == null:
			continue
		var value = pair[1].selected
		if pair[0] == "map":
			value = _map_paths[value]
		if pair[0] in ["player", "enemy"]:
			value = (Factions.IDS + ["random"])[value]
		config.set_value("setup", pair[0], value)
	config.set_value("setup", "random_starts", _random_starts.button_pressed)
	var slots = []
	for slot in _slots:
		slots.append(
			[slot.faction.selected, slot.difficulty.selected, slot.location, slot.team.selected]
		)
	config.set_value("setup", "slots", slots)
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
		["doctrine", _doctrine_selector, 0],
		["mode", _game_mode, 0],
		["resources", _resources, 0],
		["visibility", _visibility, 0],
		["events", _events, 0]
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
	_on_map_list_item_selected(_map_list.selected)
	_random_starts.set_pressed_no_signal(config.get_value("setup", "random_starts", false))
	_load_slot_preferences(config.get_value("setup", "slots", []))
	_apply_teams(_game_mode.selected)


func _load_slot_preferences(saved_slots):
	if not saved_slots is Array or saved_slots.size() != _slots.size():
		return
	var locations = []
	for saved in saved_slots:
		if not saved is Array or saved.size() != 4:
			return
		for value in saved:
			if not value is int:
				return
		if saved[2] < 0 or saved[2] >= _slots.size() or saved[2] in locations:
			return
		locations.append(saved[2])
	for index in _slots.size():
		var slot = _slots[index]
		var saved = saved_slots[index]
		slot.faction.select(clampi(saved[0], 0, slot.faction.item_count - 1))
		slot.difficulty.select(clampi(saved[1], 0, slot.difficulty.item_count - 1))
		slot.start.select(saved[2])
		slot.location = saved[2]
		slot.team.select(clampi(saved[3], 0, 3))


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
