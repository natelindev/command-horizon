extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const LoadingScene = preload("res://source/main-menu/Loading.tscn")
const Lore = preload("res://source/lore/WorldLore.gd")
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
	[
		"res://source/match/maps/ExpandedDesertFrontier.tscn",
		"Desert Frontier — Expanded",
		"Eight resource fields · capture refineries, mercenary camps and repair shops",
		"192 × 144"
	],
	[
		"res://source/match/maps/ExpandedAlpineRelay.tscn",
		"Alpine Relay — Expanded",
		"Wide mountain passes · eight resource fields · six capturable facilities",
		"192 × 156"
	],
	[
		"res://source/match/maps/ExpandedCoastalFoundry.tscn",
		"Coastal Foundry — Expanded",
		"Wide harbor routes · eight resource fields · six capturable facilities",
		"192 × 156"
	],
]
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
var _summary = null
var _cards = []
var _starting = false


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
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# --- TOP HEADER BAR ---
	var top_bar = HBoxContainer.new()
	page.add_child(top_bar)
	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	top_bar.add_child(title_box)

	var tag = Label.new()
	tag.text = tr("// THEATER OF OPERATIONS // TACTICAL SIMULATION")
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color("d8a846"))
	title_box.add_child(tag)

	_label(title_box, tr("SKIRMISH"), 28)
	_label(
		title_box,
		tr("Choose your battlefield. Build your army. Defeat the enemy command."),
		13,
		Color("9eb0b8")
	)

	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var top_telemetry = HBoxContainer.new()
	top_telemetry.add_theme_constant_override("separation", 14)
	top_bar.add_child(top_telemetry)
	_label(top_telemetry, tr("GRID: TACTICAL-01"), 11, Color("4da8cc"))
	_label(top_telemetry, "·", 11, Color("41545e"))
	_label(top_telemetry, tr("STATUS: BRIEFING READY"), 11, Color("7b929e"))
	_label(top_telemetry, "·", 11, Color("41545e"))
	_label(top_telemetry, tr("ORBITAL RECON: ACTIVE"), 11, Color("d8a846"))

	var top_line = ColorRect.new()
	top_line.custom_minimum_size.y = 1
	top_line.color = Color("ffffff15")
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(top_line)

	# --- BODY ---
	var body = HBoxContainer.new()
	var body_scroll = ScrollContainer.new()
	body_scroll.name = "SetupScroll"
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = true
	page.add_child(body_scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	body_scroll.add_child(body)

	var map_column = _panel(body)
	map_column.custom_minimum_size.x = 420
	map_column.get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER
	map_column.get_parent().size_flags_stretch_ratio = .9
	_label(map_column, tr("01 // BATTLEFIELD"), 13, Color("d8a846"))
	_map_list = OptionButton.new()
	_map_list.name = "MapList"
	_map_list.custom_minimum_size.y = 38
	map_column.add_child(_map_list)
	for entry in MAPS:
		_map_paths.append(entry[0])
		_map_list.add_item(tr(entry[1]))
	_map_list.item_selected.connect(_on_map_list_item_selected)

	var preview_frame = PanelContainer.new()
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color("060b10ea")
	preview_style.set_corner_radius_all(0)
	preview_style.set_border_width_all(1)
	preview_style.border_color = Color("233b4ac0")
	preview_style.set_content_margin_all(6)
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	map_column.add_child(preview_frame)

	_preview = load("res://source/main-menu/SkirmishMapPreview.gd").new()
	_preview.custom_minimum_size.y = clampf(get_viewport_rect().size.y * .42, 240, 460)
	resized.connect(
		func(): _preview.custom_minimum_size.y = clampf(get_viewport_rect().size.y * .42, 240, 460)
	)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_child(_preview)

	_map_details = _label(map_column, "", 13, Color("bac6ca"))
	_map_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var legend_panel = PanelContainer.new()
	var leg_style = StyleBoxFlat.new()
	leg_style.bg_color = Color("070d13b3")
	leg_style.set_corner_radius_all(0)
	leg_style.set_border_width_all(1)
	leg_style.border_color = Color("1e2f3bc0")
	leg_style.set_content_margin_all(8)
	legend_panel.add_theme_stylebox_override("panel", leg_style)
	map_column.add_child(legend_panel)

	_label(
		legend_panel,
		(
			"1  "
			+ tr("Your base")
			+ "    2  "
			+ tr("Enemy base")
			+ "\n"
			+ tr("Dots: resources · Small squares: relays")
			+ "\n"
			+ tr("Blocks: buildings · Lines: roads · Blue: water")
			+ "\n"
			+ tr("R: refinery · M: mercenary camp · +: repair shop")
		),
		12,
		Color("8296a6")
	)

	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)

	var faction_row = HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 16)
	right.add_child(faction_row)
	_player_faction = _faction_card(faction_row, tr("02 // YOUR FACTION"), 0)
	_enemy_faction = _faction_card(faction_row, tr("03 // ENEMY FACTION"), 1)

	var rules = _panel(right)
	_label(rules, tr("// ENGAGEMENT PARAMETERS"), 13, Color("d8a846"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	rules.add_child(grid)
	_label(grid, tr("AI difficulty"), 14, Color("bac6ca"))
	_difficulty = _option(grid, "Difficulty", ["Easy", "Normal", "Hard"])
	_label(grid, tr("Starting forces"), 14, Color("bac6ca"))
	_start_mode = _option(
		grid, "StartMode", ["Standard — build your base", "Advanced — armor and technology"]
	)
	_label(grid, tr("Tactical doctrine"), 14, Color("bac6ca"))
	_doctrine_selector = _option(
		grid,
		"TacticalDoctrine",
		["Standard Field Protocol", "Hit & Run Kiting", "Ironclad Defense"]
	)

	var summary_box = PanelContainer.new()
	var sum_style = StyleBoxFlat.new()
	sum_style.bg_color = Color("070d13b3")
	sum_style.set_corner_radius_all(0)
	sum_style.set_content_margin_all(10)
	sum_style.set_border_width_all(1)
	sum_style.border_color = Color("1e2f3bc0")
	summary_box.add_theme_stylebox_override("panel", sum_style)
	rules.add_child(summary_box)

	_summary = _label(summary_box, "", 13, Color("bac6ca"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty.item_selected.connect(func(_index): _update_summary())
	_start_mode.item_selected.connect(func(_index): _update_summary())

	# --- FOOTER BAR ---
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	page.add_child(footer)

	var back = Button.new()
	back.text = tr("Back")
	back.add_theme_font_size_override("font_size", 16)
	back.custom_minimum_size = Vector2(130, 46)
	back.add_theme_stylebox_override("normal", ArtTheme.secondary_button_style())
	back.add_theme_stylebox_override("hover", ArtTheme.secondary_button_hover_style())
	back.pressed.connect(_on_back_button_pressed)
	footer.add_child(back)

	var note = _label(
		footer, tr("1 vs 1 · Fog of war · Tactical pause · 100 units per side"), 13, Color("8ea0a8")
	)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.theme_type_variation = "BattlePrimaryButton"
	_start_button.add_theme_font_size_override("font_size", 16)
	_start_button.text = tr("START BATTLE  →")
	_start_button.custom_minimum_size = Vector2(250, 46)
	_start_button.add_theme_stylebox_override("normal", ArtTheme.primary_button_style())
	_start_button.add_theme_stylebox_override("hover", ArtTheme.primary_button_hover_style())
	_start_button.add_theme_stylebox_override("pressed", ArtTheme.primary_button_pressed_style())
	_start_button.add_theme_color_override("font_color", Color("142130"))
	_start_button.add_theme_color_override("font_hover_color", Color("142130"))
	_start_button.add_theme_color_override("font_pressed_color", Color("142130"))
	_start_button.pressed.connect(_on_start_button_pressed)
	footer.add_child(_start_button)


func _panel(parent):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = preload("res://source/match/hud/BattleTheme.gd").panel(20, 18)
	panel.add_theme_stylebox_override("panel", style)
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
	choice.custom_minimum_size.y = 36
	choice.add_theme_font_size_override("font_size", 14)
	for item in items:
		choice.add_item(tr(item))
	parent.add_child(choice)
	return choice


func _faction_card(parent, heading, index):
	var box = _panel(parent)
	_label(box, tr(heading), 13, Color("d8a846"))

	var portrait_box = PanelContainer.new()
	var port_style = StyleBoxFlat.new()
	port_style.bg_color = Color("060b10e0")
	port_style.set_corner_radius_all(0)
	port_style.set_border_width_all(1)
	port_style.border_color = Color("1e2f3bc0")
	port_style.set_content_margin_all(6)
	portrait_box.add_theme_stylebox_override("panel", port_style)
	box.add_child(portrait_box)

	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(140, 112)
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
	_cards[index].description.text = tr(FACTION_DESCRIPTIONS[selected])
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
		tr(opening)
		+ "\n"
		+ tr("Win by destroying the enemy HQ and preventing a rebuild for 60 seconds.")
	)
	_summary.tooltip_text = "Difficulty changes AI timing. No health, damage or resource bonuses."


func _on_map_list_item_selected(index):
	_preview.set_map(MAPS[index][0])
	_map_details.text = (
		tr(MAPS[index][2]) + "\n" + MAPS[index][3] + " · " + tr("Opposite starting positions")
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
		["map", _map_list, "res://source/match/maps/ExpandedDesertFrontier.tscn"],
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
			if not value is int:
				value = _map_paths.find(str(value))
				if value < 0:
					value = _map_paths.find("res://source/match/maps/ExpandedDesertFrontier.tscn")
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
