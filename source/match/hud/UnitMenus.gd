# gdlint: disable=max-file-lines,max-returns
extends PanelContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")
const HudLayout = preload("res://source/match/hud/HudLayout.gd")

const Bindings = preload("res://source/input/KeyBindings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const RosterInfo = preload("res://source/match/hud/RosterInfo.gd")
const RosterButton = preload("res://source/match/hud/RosterButton.gd")
const CommandCard = preload("res://source/match/hud/CommandCard.gd")
const UnitCounters = preload("res://source/match/combat/UnitCounters.gd")

const BUILD_KEYS = {
	KEY_C: "CommandCenter",
	KEY_F: "ForwardRefinery",
	KEY_B: "Barracks",
	KEY_V: "VehicleFactory",
	KEY_A: "AircraftFactory",
	KEY_P: "PowerPlant",
	KEY_L: "CommandLab",
	KEY_R: "RepairDepot",
	KEY_T: "AntiGroundTurret",
	KEY_M: "AntiAirTurret",
}

var _camp = null
var _commander_open = false
var _commander_panel = null
var _camp_buttons = []
var _selection = []
var _stop_button = null
var _buttons = []
var _title = null
var _status = null
var _content = null
var _command_bay: MarginContainer
var _pages: TabContainer
var _research_player = null
var _research_script = load("res://source/match/hud/ResearchPanel.gd")
var _commands: VBoxContainer
var _support: VBoxContainer
var _minimap: Control
var _queue: Control
var _refresh_elapsed = 0.0
var _health_dirty = false
var _orders_panel = null
var _behavior_panel = null
var _research_panel = null
var _was_under_construction = false
var _formation_controls = null
var _weapon_modes = null
var _signature_panel = null
var _direct_orders = null
var _command_buttons = {}
var _engineering_buttons = []
var _return_cargo = null
var _recover_health = null
var _command_mouse_held = false
var _selection_roster = null
var _discard_control_release = false
var _command_card = null
var _menu_reset_queued = false
## Left bay of the deck: portrait, name, health and status of the selection.
var _info: VBoxContainer
var _info_bay: MarginContainer
var _health: ProgressBar
var _health_fill: StyleBox
var _health_label: Label
var _shields: ProgressBar
var _orders_spacer: Control


func _ready():
	# A content-sized bottom console beside the minimap: selection on the left,
	# direct orders and behaviors side by side, with separate build/produce pages.
	BattleTheme.apply_housing(self, 16, 12)
	custom_minimum_size = Vector2(
		HudLayout.deck_width(get_viewport_rect().size.x), HudLayout.CONSOLE_HEIGHT
	)
	var deck = HBoxContainer.new()
	deck.name = "Deck"
	deck.add_theme_constant_override("separation", 8)
	add_child(deck)
	_info_bay = MarginContainer.new()
	_info_bay.name = "InfoBay"
	_info_bay.custom_minimum_size.x = HudLayout.info_bay(get_viewport_rect().size.x)
	deck.add_child(_info_bay)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 6)
	_info_bay.add_child(_info)
	_info.minimum_size_changed.connect(_fit_menu)
	deck.add_child(VSeparator.new())
	_command_bay = MarginContainer.new()
	_command_bay.name = "CommandBay"
	_command_bay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.add_child(_command_bay)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_command_bay.add_child(_content)
	_content.minimum_size_changed.connect(_fit_menu)
	get_viewport().size_changed.connect(_fit_menu)
	_queue = get_node_or_null("../ProductionQueue")
	if _queue != null:
		_queue.minimum_size_changed.connect(_fit_menu)
		_queue.visibility_changed.connect(_fit_menu)
	MatchSignals.deselect_all_units.connect(_clear_camp)
	MatchSignals.unit_selected.connect(func(_unit): _queue_menu_reset())
	MatchSignals.unit_deselected.connect(func(_unit): _queue_menu_reset())
	MatchSignals.unit_died.connect(_on_selected_unit_died)
	_minimap = find_parent("Match").find_child("Minimap", true, false)
	if is_instance_valid(_minimap):
		_minimap.resized.connect(_fit_menu)
	_reset_menus()


func _fit_menu():
	var viewport = get_viewport().get_visible_rect().size
	var width = HudLayout.deck_width(viewport.x)
	if is_instance_valid(_minimap) and _minimap.is_visible_in_tree():
		width = viewport.x - _minimap.get_global_rect().end.x
	var showing_orders = (
		is_instance_valid(_pages)
		and _pages.get_current_tab_control() != null
		and _pages.get_current_tab_control().name == "Orders"
	)
	if is_instance_valid(_selection_roster):
		_selection_roster.visible = showing_orders
	var wide_deck = width >= 1100.0
	if showing_orders and wide_deck:
		_info_bay.custom_minimum_size.x = (
			clampf(width * 0.32, 380.0, 480.0)
			if _selection.size() > 1
			else clampf(width * 0.25, 300.0, 380.0)
		)
	else:
		_info_bay.custom_minimum_size.x = (
			371 if _selection.size() > 1 and showing_orders else HudLayout.info_bay(viewport.x)
		)
	if is_instance_valid(_commands):
		_commands.custom_minimum_size.x = 278 if wide_deck else 252
		_commands.size_flags_horizontal = (
			Control.SIZE_SHRINK_END if wide_deck else Control.SIZE_EXPAND_FILL
		)
	if is_instance_valid(_support):
		_support.custom_minimum_size.x = 264 if wide_deck else 200
		_support.size_flags_horizontal = (
			Control.SIZE_SHRINK_BEGIN if wide_deck else Control.SIZE_EXPAND_FILL
		)
	if is_instance_valid(_orders_spacer):
		_orders_spacer.visible = (
			wide_deck
			and is_instance_valid(_commands)
			and _commands.visible
			and is_instance_valid(_support)
			and _support.visible
		)
	for grid in _content.find_children("Roster", "GridContainer", true, false):
		var available_width = width - _info_bay.custom_minimum_size.x - 54
		grid.columns = clampi(
			maxi(floori(available_width / 156), ceili(grid.get_child_count() / 3.0)),
			1,
			mini(6, maxi(1, floori(available_width / 132)))
		)
	if is_instance_valid(_status):
		_status.custom_minimum_size.x = _info_bay.custom_minimum_size.x - 12
	var margins = get_theme_stylebox("panel").get_minimum_size().y
	var content_height = maxf(
		_content.get_combined_minimum_size().y, _info.get_combined_minimum_size().y
	)
	var height = clampf(
		content_height + margins, HudLayout.DECK_MIN_HEIGHT, HudLayout.CONSOLE_HEIGHT
	)
	var available = maxf(1, height - margins)
	_command_bay.custom_minimum_size.y = available
	_info_bay.custom_minimum_size.y = available
	custom_minimum_size = Vector2(width, height)
	# Containers grow automatically; explicitly release height after a smaller selection.
	reset_size()


func _process(delta):
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.25:
		_refresh_elapsed = 0.0
		_refresh_buttons()
	if _health_dirty:
		_refresh_health()


func _input(event):
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_command_mouse_held = false
	if not _discard_control_release:
		return
	# A unit can die while a roster or command button is held. Its release belongs
	# to that removed control. A new press starts a fresh gesture instead.
	_discard_control_release = false
	if not event.is_pressed():
		get_viewport().set_input_as_handled()


func _on_selected_unit_died(unit):
	if unit in _selection:
		_queue_menu_reset()


func _queue_menu_reset():
	_camp = null
	_research_player = null
	if _content == null or not is_inside_tree():
		return
	# Preserve the press before removing its control, including when several
	# selection signals arrive before the matching mouse release.
	if (
		_command_mouse_held
		or (is_instance_valid(_selection_roster) and _selection_roster.has_active_mouse_press())
	):
		_discard_control_release = true
	if _menu_reset_queued:
		return
	_menu_reset_queued = true
	# Old commands must not accept input for a selection that has already changed.
	_content.hide()
	_info.hide()
	_flush_menu_reset.call_deferred()


func _flush_menu_reset():
	_menu_reset_queued = false
	if is_inside_tree() and not is_queued_for_deletion():
		_reset_menus()


func _reset_menus():
	if _content == null or not is_inside_tree():
		return
	_content.show()
	_info.show()
	if (
		_command_mouse_held
		or (is_instance_valid(_selection_roster) and _selection_roster.has_active_mouse_press())
	):
		_discard_control_release = true
	var hud = find_parent("Match").get("hud")
	if is_instance_valid(hud):
		hud.technology_panel = null
	var previous_selection = _selection.duplicate()
	for previous_unit in previous_selection:
		if not is_instance_valid(previous_unit):
			continue
		for signal_name in ["hp_changed", "shields_changed"]:
			if previous_unit.is_connected(signal_name, _queue_health_refresh):
				previous_unit.disconnect(signal_name, _queue_health_refresh)
		if previous_unit.tree_exited.is_connected(_queue_menu_reset):
			previous_unit.tree_exited.disconnect(_queue_menu_reset)
		if previous_unit is Structure and previous_unit.constructed.is_connected(_queue_menu_reset):
			previous_unit.constructed.disconnect(_queue_menu_reset)
	var page_name = "Orders"
	if is_instance_valid(_pages) and _pages.current_tab >= 0:
		page_name = _pages.get_current_tab_control().name
	for container in [_content, _info]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_health = null
	_health_label = null
	_shields = null
	_orders_spacer = null
	_buttons.clear()
	_command_buttons.clear()
	_engineering_buttons.clear()
	_return_cargo = null
	_recover_health = null
	_direct_orders = null
	_orders_panel = null
	_behavior_panel = null
	_research_panel = null
	_weapon_modes = null
	_formation_controls = null
	_signature_panel = null
	_selection_roster = null
	_command_card = null
	_stop_button = null
	_selection = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and not unit.is_queued_for_deletion()
	)
	if _commander_open:
		_build_commander()
		return
	if is_instance_valid(_research_player):
		_build_research()
		return
	if is_instance_valid(_camp):
		_build_camp()
		return
	var opening = not visible and not _selection.is_empty()
	visible = not _selection.is_empty()
	if _selection.is_empty():
		return
	if opening:
		# The deck opens out of the console shutter, also during a tactical pause.
		modulate.a = 0.0
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(
			self, "modulate:a", 1.0, .14
		)
	for selected_unit in _selection:
		for signal_name in ["hp_changed", "shields_changed"]:
			if not selected_unit.is_connected(signal_name, _queue_health_refresh):
				selected_unit.connect(signal_name, _queue_health_refresh)
		if not selected_unit.tree_exited.is_connected(_queue_menu_reset):
			selected_unit.tree_exited.connect(_queue_menu_reset)
		if (
			selected_unit is Structure
			and not selected_unit.constructed.is_connected(_queue_menu_reset)
		):
			selected_unit.constructed.connect(_queue_menu_reset)
	var unit = _selection[0]
	var conventional = (
		unit._match.settings.mission_id == "supply_line"
		or _selection.all(func(member): return member.type in Catalog.MISSION_NAMES)
	)
	_was_under_construction = unit is Structure and unit.is_under_construction()
	_title = Label.new()
	_title.text = (
		Factions.title(unit.player.faction, unit.type)
		if _selection.size() == 1
		else "%d units selected" % _selection.size()
	)
	var heading_icon = (
		null
		if unit.type in Catalog.MISSION_NAMES
		else Factions.portrait(unit.player.faction, unit.type)
	)
	_build_info(heading_icon)
	_content.tooltip_text = tr(Factions.TECH_SUMMARY.get(unit.player.faction, ""))
	_pages = TabContainer.new()
	_pages.name = "CommandPages"
	_pages.use_hidden_tabs_for_min_size = false
	_pages.add_theme_stylebox_override("panel", BattleTheme.surface(Color.TRANSPARENT, 0, 0))
	# The housing already supplies padding. Keep the restored tab row shallow
	# enough for three rows of labelled choices at the largest interface scale.
	var tab_bar = _pages.get_tab_bar()
	_pages.add_theme_font_size_override("font_size", 14)
	tab_bar.add_theme_font_size_override("font_size", 14)
	for style_name in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var style = _pages.get_theme_stylebox(style_name).duplicate()
		style.set_content_margin(SIDE_TOP, 1)
		style.set_content_margin(SIDE_BOTTOM, 1)
		_pages.add_theme_stylebox_override(style_name, style)
		tab_bar.add_theme_stylebox_override(style_name, style)
	_pages.tab_changed.connect(func(_index): _fit_menu.call_deferred())
	_content.add_child(_pages)
	var production_roles = []
	for producer in _selection:
		if producer is Structure and producer.is_constructed():
			for role in Factions.production_options(producer.player.faction, producer.type):
				if role not in production_roles:
					production_roles.append(role)
	# The selection's primary choices open immediately, with direct labelled tabs.
	# Mixed selections lead with orders and the selection roster.
	var roster_page = null
	var roster_title = "Produce" if not production_roles.is_empty() else "Build"
	var has_workers = _selection.any(func(member): return member is Worker)
	var builds = not production_roles.is_empty() or has_workers
	var researches = (
		_selection.size() == 1
		and unit is Structure
		and unit.is_constructed()
		and unit.type == "CommandLab"
		and unit.player.get_meta("skirmish", false)
	)
	if researches:
		roster_page = _page("Research")
	if builds and _selection.all(func(member): return member is Structure or member is Worker):
		roster_page = _page(roster_title)
	var orders_page = _page("Orders")
	var columns = HBoxContainer.new()
	columns.name = "OrderColumns"
	columns.add_theme_constant_override("separation", 12)
	orders_page.add_child(columns)
	_support = VBoxContainer.new()
	_support.name = "UnitBehaviorAndOrders"
	_support.custom_minimum_size.x = 240
	_support.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_support.add_theme_constant_override("separation", 6)
	columns.add_child(_support)
	columns.add_child(VSeparator.new())
	_orders_spacer = Control.new()
	_orders_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_orders_spacer)
	_commands = VBoxContainer.new()
	_commands.name = "DirectCommands"
	_commands.custom_minimum_size.x = 278
	_commands.size_flags_horizontal = Control.SIZE_SHRINK_END
	_commands.add_theme_constant_override("separation", 3)
	columns.add_child(_commands)
	if builds and roster_page == null:
		roster_page = _page(roster_title)
	if _selection.size() > 1:
		_selection_roster = load("res://source/match/hud/SelectionRoster.gd").new()
		_selection_roster.name = "SelectionRoster"
		_selection_roster.selection = _selection.duplicate()
		_selection_roster.subset_requested.connect(_select_subset)
		_info.add_child(_selection_roster)
	_add_direct_buttons(unit)
	var grid = _roster_grid(roster_page if roster_page != null else _commands)
	for role in production_roles:
		_add_roster_button(grid, role, false)
	if researches:
		_research_panel = _research_script.new()
		_research_panel.lab = unit
		roster_page.add_child(_research_panel)
	if (
		_selection.size() == 1
		and unit is Structure
		and unit.is_constructed()
		and unit.type == "CommandLab"
		and unit.player.faction == "frontier"
	):
		var market = load("res://source/match/hud/MarketPanel.gd").new()
		market.player = unit.player
		_page("Black Market").add_child(market)
	if has_workers:
		# Mixed worker/producer selections keep both rosters one click away;
		# do not combine two full menus into an over-height Produce grid.
		if not production_roles.is_empty():
			grid = _roster_grid(_page("Build"))
		for unit_type in Catalog.STRUCTURES:
			if not Factions.roster(unit.player.faction).allows(unit_type, true):
				continue
			_add_roster_button(grid, unit_type, true)
		if unit.player.faction == "bastion":
			_add_engineering_button(grid, "field_barricade", "Field barricade", "Q", "plan", 10)
		elif unit.player.faction == "frontier":
			_add_engineering_button(grid, "scrap_mine", "Scrap mine", "W", "attack", 8)
	if (
		(
			_selection
			. filter(
				func(member): return member.manual_orders != null and member.movement_speed > 0
			)
			. size()
		)
		> 1
	):
		_formation_controls = load("res://source/match/hud/FormationControls.gd").new()
		_formation_controls.selection = _selection.duplicate()
		_formation_controls.hud = unit._match.hud
		_page("Formations").add_child(_formation_controls)
	if _selection.size() == 1 and unit.garrison_mount != null:
		var passengers = load("res://source/match/hud/PassengerPanel.gd").new()
		passengers.host = unit
		_page("Passengers").add_child(passengers)
	var stop = Button.new()
	_stop_button = stop
	stop.theme_type_variation = "BattleQuietButton"
	stop.text = (
		"Cancel construction"
		if unit is Structure and unit.is_under_construction()
		else "Stop current orders"
	)
	stop.icon = BattleTheme.icon("stop")
	stop.add_theme_constant_override("icon_max_width", 14)
	stop.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stop.pressed.connect(_stop_orders)
	# Cancel construction and Clear rally apply to the whole selection on every page.
	# A unit's Stop already sits in the command grid, so it is not repeated here.
	stop.visible = stop.text != "Stop current orders" or not is_instance_valid(_command_card)
	_info.add_child(stop)
	if not conventional and _selection.any(func(member): return member.signature != null):
		_signature_panel = load("res://source/match/hud/SignaturePanel.gd").new()
		_signature_panel.selection = _selection.duplicate()
		_support.add_child(_signature_panel)
	if _selection.any(
		func(member): return member.type == "CombatRobot" and member.can_switch_weapon()
	):
		_weapon_modes = load("res://source/match/hud/WeaponModes.gd").new()
		_weapon_modes.selection = _selection.duplicate()
		_support.add_child(_weapon_modes)
	if _selection.any(func(member): return member.manual_orders != null):
		_orders_panel = load("res://source/match/hud/OrdersPanel.gd").new()
		_orders_panel.selection = _selection.duplicate()
		_support.add_child(_orders_panel)
	if _selection.all(func(member): return member.manual_orders != null):
		_behavior_panel = load("res://source/match/hud/BehaviorPanel.gd").new()
		_behavior_panel.selection = _selection.duplicate()
		_behavior_panel.hud = unit._match.hud
		_support.add_child(_behavior_panel)

	# An empty roster would still claim page spacing.
	grid.visible = grid.get_child_count() > 0
	_commands.visible = _commands.get_children().any(func(item): return item.visible)
	_support.visible = _support.get_children().any(func(item): return item.visible)
	columns.visible = _commands.visible or _support.visible
	# A page with nothing to show (an idle producer's Orders) is not offered as a tab.
	for page in _pages.get_children():
		if (
			_pages.get_child_count() > 1
			and page.get_children().all(func(item): return not item.visible)
		):
			_pages.remove_child(page)
			page.queue_free()
	_pages.current_tab = 0
	if previous_selection == _selection:
		for index in _pages.get_tab_count():
			if _pages.get_child(index).name == page_name:
				_pages.current_tab = index
	_pages.tabs_visible = _pages.get_tab_count() > 1
	_refresh_buttons()
	# Rebuilding an identical selection can return to the same content minimum.
	# Refit after layout settles even when no final minimum-size signal is emitted.
	_fit_menu.call_deferred()


func _build_info(portrait):
	var header = HBoxContainer.new()
	header.name = "Identity"
	# Hovering portrait or name shows the full identity and reference facts.
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", 10)
	_info.add_child(header)
	if portrait != null and (_selection.size() == 1 or is_instance_valid(_research_player)):
		var frame = PanelContainer.new()
		frame.name = "Portrait"
		frame.custom_minimum_size = Vector2(74, 74)
		frame.add_theme_stylebox_override("panel", BattleTheme.socket(4, 4))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(frame)
		var icon = TextureRect.new()
		icon.texture = portrait
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
	var names = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 4)
	header.add_child(names)
	_title.theme_type_variation = "HudHeading"
	_title.uppercase = true
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", BattleTheme.IVORY)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_title.show()
	names.add_child(_title)
	_shields = ProgressBar.new()
	_shields.name = "Shields"
	_shields.custom_minimum_size.y = 5
	_shields.show_percentage = false
	_shields.add_theme_stylebox_override("fill", BattleTheme.bar_fill(Color("68cee8")))
	_shields.mouse_filter = Control.MOUSE_FILTER_PASS
	_shields.hide()
	names.add_child(_shields)
	var health_row = HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 6)
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(health_row)
	_health = ProgressBar.new()
	_health.name = "Health"
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health.custom_minimum_size.y = 8
	_health.show_percentage = false
	_health_fill = BattleTheme.bar_fill(BattleTheme.HEALTH_OK)
	_health.add_theme_stylebox_override("fill", _health_fill)
	_health.mouse_filter = Control.MOUSE_FILTER_PASS
	health_row.add_child(_health)
	_health_label = Label.new()
	_health_label.name = "HealthNumeric"
	_health_label.add_theme_font_override("font", BattleTheme.numeral_font())
	_health_label.add_theme_font_size_override("font_size", 12)
	_health_label.add_theme_color_override("font_color", BattleTheme.HEALTH_OK)
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(_health_label)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("b9bfba"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 3
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size.x = _info_bay.custom_minimum_size.x - 12
	_info.add_child(_status)
	_health_dirty = true


func _queue_health_refresh():
	# A shield recharge or burst of impacts can notify every selected body in
	# one tick. Aggregate once for the next displayed frame, also while paused.
	_health_dirty = true


func _refresh_health():
	_health_dirty = false
	if not is_instance_valid(_health):
		return
	# Tech retains the army selection, but its identity is not a selected unit.
	if is_instance_valid(_research_player):
		_health.hide()
		if is_instance_valid(_health_label):
			_health_label.hide()
		_shields.hide()
		return
	var hp = 0.0
	var hp_max = 0.0
	var shields = 0.0
	var shields_max = 0.0
	for member in _selection:
		if is_instance_valid(member) and member.hp != null:
			hp += member.hp
			hp_max += member.hp_max
			shields += member.shields
			shields_max += member.shields_max
	_shields.visible = shields_max > 0
	_shields.max_value = maxf(1.0, shields_max)
	_shields.value = shields
	_shields.tooltip_text = tr("%d / %d shields") % [ceili(shields), ceili(shields_max)]
	_shields.accessibility_name = tr("Plasma Shields")
	_shields.accessibility_description = _shields.tooltip_text
	_health.visible = hp_max > 0
	_health.max_value = maxf(1.0, hp_max)
	_health.value = hp
	var ratio = hp / maxf(1.0, hp_max)
	var hp_col = (
		BattleTheme.HEALTH_OK
		if ratio > .6
		else (BattleTheme.SIGNAL_WARN if ratio > .3 else BattleTheme.SIGNAL_BAD)
	)
	_health_fill.modulate = hp_col
	if is_instance_valid(_health_label):
		_health_label.visible = hp_max > 0
		_health_label.text = "%d / %d" % [ceili(hp), ceili(hp_max)]
		_health_label.add_theme_color_override("font_color", hp_col)
	_health.queue_redraw()


func _order_key(button, glyph):
	# A fixed-size glyph counts towards the key's minimum width, so tight rows keep it.
	button.icon = BattleTheme.icon(glyph)
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 32


func _add_direct_buttons(unit):
	var hud = unit._match.get("hud")
	if not is_instance_valid(hud):
		return
	_direct_orders = hud.get_node_or_null("DirectOrders")
	if _direct_orders == null:
		return
	if not _selection.any(func(member): return member.manual_orders != null):
		if _selection.any(
			func(member):
				return member.abilities != null and not member.abilities.abilities.is_empty()
		):
			_command_card = CommandCard.new()
			_command_card.name = "CommandCard"
			_command_card.abilities_only = true
			_commands.add_child(_command_card)
			_command_card.update_layout(_selection, _direct_orders)
		return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_commands.add_child(row)
	if _selection.any(func(member): return member is Worker):
		_return_cargo = Button.new()
		_return_cargo.name = "ReturnCargo"
		_return_cargo.text = "Return cargo"
		_order_key(_return_cargo, "return")
		_return_cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_return_cargo.gui_input.connect(_cargo_input)
		_return_cargo.pressed.connect(
			func(): _direct_orders.return_cargo(Globals.options.selection_modifier_pressed())
		)
		row.add_child(_return_cargo)

	_recover_health = Button.new()
	_recover_health.name = "RecoverHealth"
	_recover_health.text = "Recover health"
	_order_key(_recover_health, "recover")
	_recover_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recover_health.gui_input.connect(_recovery_input)
	_recover_health.pressed.connect(
		func(): _direct_orders.recover_health(Globals.options.selection_modifier_pressed())
	)
	# Service orders with their own feedback sit above the grid, which holds every other
	# order once: Move, Attack target and Attack move there arm the direct orders.
	row.add_child(_recover_health)
	_command_card = CommandCard.new()
	_command_card.name = "CommandCard"
	_command_card.stop_override = _stop_units
	_commands.add_child(_command_card)
	_command_card.update_layout(_selection, _direct_orders)
	for kind in _direct_orders.COMMANDS:
		var key = _command_card.order_slot(kind)
		if key == null:
			continue
		key.toggle_mode = true
		key.gui_input.connect(_remember_command_mouse)
		_command_buttons[kind] = key


func _remember_command_mouse(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_command_mouse_held = event.pressed


func _cargo_input(event):
	_service_input(event, _return_cargo, _direct_orders.return_cargo)


func _recovery_input(event):
	_service_input(event, _recover_health, _direct_orders.recover_health)


func _service_input(event, button, command):
	_remember_command_mouse(event)
	if not event is InputEventKey:
		return
	var queue_key = Bindings.from_event(InputMap.action_get_events("shift_selecting")[0])
	var modifiers = {
		KEY_SHIFT: event.shift_pressed,
		KEY_CTRL: event.ctrl_pressed,
		KEY_ALT: event.alt_pressed,
		KEY_META: event.meta_pressed
	}
	# BaseButton's default accept binding excludes modified Enter. Keep queued
	# service orders available from the focused button with the player's queue key held.
	# Modifier flags belong to this event even when physical polling lags behind.
	if (
		event.is_action_pressed("ui_accept", false, false)
		and modifiers.get(queue_key, Globals.options.selection_modifier_pressed())
		and not button.disabled
	):
		button.accept_event()
		command.call(true)


func _add_roster_button(grid, unit_type, construction):
	var player = _selection[0].player
	var producer = _selection[0] if construction else _production_target(unit_type)
	var info = RosterInfo.inspect(producer, unit_type, construction)
	var cost = info.cost
	var button = RosterButton.new()
	button.set_meta(
		"armed",
		(
			unit_type
			in [
				"Infantry",
				"RocketInfantry",
				"SniperInfantry",
				"AssaultInfantry",
				"Hero",
				"Tank",
				"AdvancedTank",
				"AntiAirVehicle",
				"CombatRobot",
				"Drone",
				"Helicopter",
				"Fighter",
				"Bomber",
				"AntiGroundTurret",
				"AntiAirTurret"
			]
		)
	)
	button.name = "Build" + unit_type if construction else "Produce" + unit_type
	# Keep the portrait, name and price visible without hovering.
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.show_role(
		Factions.portrait(player.faction, unit_type),
		Factions.title(player.faction, unit_type),
		cost
	)
	button.tooltip_text = _roster_tooltip(info.text, unit_type, construction)
	if construction:
		button.show_hotkey(OS.get_keycode_string(BUILD_KEYS.find_key(unit_type)))
	button.accessibility_name = tr(Factions.title(player.faction, unit_type))
	button.accessibility_description = info.text
	button.disabled = not info.allowed
	button.gui_input.connect(_roster_input.bind(button))
	button.pressed.connect(_activate_roster.bind(unit_type, construction, button))
	grid.add_child(button)
	_buttons.append(
		{"button": button, "type": unit_type, "construction": construction, "cost": cost}
	)


func _roster_grid(parent):
	var grid = GridContainer.new()
	grid.name = "Roster"
	grid.columns = HudLayout.roster_columns(get_viewport_rect().size.x)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


func _refresh_buttons():
	if _commander_open:
		if is_instance_valid(_commander_panel):
			_commander_panel.refresh()
		return
	if is_instance_valid(_research_player):
		if is_instance_valid(_research_panel):
			_research_panel.refresh()
		return
	if is_instance_valid(_camp):
		_refresh_camp()
		return
	var rally = _selected_rally()
	if is_instance_valid(_stop_button) and rally != null:
		_stop_button.text = "Clear rally"
		_stop_button.disabled = not rally.is_assigned()
		# Without a rally there is nothing to clear; the destination is in the tooltip.
		_stop_button.visible = rally.is_assigned()
		_stop_button.tooltip_text = (
			tr("Rally ·")
			+ " "
			+ tr(_rally_destination(rally))
			+ "\n"
			+ tr(
				(
					"Removes the destination for new units. Paid production and existing unit orders continue.\n"
					+ "Right-click ground, resources or a friendly unit to set a new rally."
				)
			)
		)
		_stop_button.accessibility_description = _stop_button.tooltip_text
	if is_instance_valid(_stop_button) and _selection.size() == 1:
		var unit = _selection[0]
		if is_instance_valid(unit) and unit is Structure and unit.is_under_construction():
			var refund = unit.construction_refund()
			_stop_button.text = "Cancel construction"
			_stop_button.tooltip_text = (
				(
					tr("%d M / %d E") % [refund.resource_a, refund.resource_b]
					+ "\n"
					+ "Refunds unused construction costs, rounded down to whole resources."
				)
				if unit.player.get_meta("skirmish", false)
				else "Refunds the full construction cost."
			)
			_stop_button.accessibility_description = (
				_stop_button.text + ". " + _stop_button.tooltip_text
			)
	# The grid retains unchanged controls; order keys take fresh state and hints.
	var eligibility = (
		_direct_orders.eligibility_state() if is_instance_valid(_direct_orders) else {}
	)
	if is_instance_valid(_command_card):
		_command_card.update_layout(_selection, _direct_orders, eligibility)
	_refresh_engineering_buttons()
	if is_instance_valid(_direct_orders):
		for kind in _command_buttons:
			var button = _command_buttons[kind]
			var spec = _direct_orders.COMMANDS[kind]
			button.set_pressed_no_signal(_direct_orders.kind == kind)
			button.disabled = not _direct_orders.has_eligible(kind, eligibility)
			# The badge and tooltip both follow the player's configured binding.
			var badge = Bindings.label(spec.action)
			if button.badge != badge:
				button.badge = badge
			button.tooltip_text = (
				Bindings.hint(spec.title, spec.action)
				+ "\n"
				+ spec.description
				+ " Hold %s to queue." % Bindings.label("shift_selecting")
			)
			button.accessibility_name = Bindings.hint(spec.title, spec.action)
			button.accessibility_description = button.tooltip_text
		if is_instance_valid(_return_cargo):
			var state = _direct_orders.cargo_return_state(eligibility)
			_return_cargo.disabled = state.orders.is_empty()
			_return_cargo.tooltip_text = state.description
			_return_cargo.accessibility_description = state.description
		if is_instance_valid(_recover_health):
			var state = _direct_orders.recovery_state(eligibility)
			_recover_health.text = state.label
			_recover_health.disabled = state.orders.is_empty()
			_recover_health.tooltip_text = state.description
			_recover_health.accessibility_description = state.description
	if is_instance_valid(_selection_roster):
		_selection_roster.refresh()
	if is_instance_valid(_signature_panel):
		_signature_panel.refresh()
	if is_instance_valid(_weapon_modes):
		_weapon_modes.refresh()
	if is_instance_valid(_research_panel):
		_research_panel.refresh()
	if is_instance_valid(_orders_panel):
		_orders_panel.refresh()
	if is_instance_valid(_behavior_panel):
		_behavior_panel.refresh()
	if _selection.is_empty() or not is_instance_valid(_selection[0]):
		return
	var unit = _selection[0]
	if unit is Structure and unit.is_under_construction() != _was_under_construction:
		_reset_menus()
		return
	if unit.hp == null:
		return
	# Resolve each role against the current eligible producer before refreshing.
	if (
		_selection.size() == 1
		and unit is Structure
		and unit.is_constructed()
		and _buttons.is_empty()
		and Catalog.PRODUCES.has(unit.type)
	):
		_reset_menus()
		return
	var health = "%d / %d HP" % [ceili(unit.hp), ceili(unit.hp_max)]
	# Show a short role description when there is no urgent status to display.
	# Detailed weapons, upgrades and service rules remain in the identity tooltip.
	var lines = []
	var facts = []
	if unit is Structure:
		if unit.is_under_construction():
			lines.append("Under construction")
		else:
			if unit.player.production_factor() < 1.0:
				lines.append("Low power — production at 25%")
			var service = {
				"CommandLab": "Research and advanced units unlocked",
				"RepairDepot": "Ground service: 2 slots · 5 m",
				"Barracks": "Infantry recovery: 2 slots · stationary within 5 m",
				"AircraftFactory": "Aircraft service: 4 jet stands, 2 helipads · rearm and repair",
			}
			if service.has(unit.type):
				facts.append(service[unit.type])
	if _selection.size() > 1:
		# The title counts the selection and the roster counts damaged units.
		lines.clear()
	if _selection.size() == 1:
		if unit.suppression != null and unit.suppression.band > 0:
			lines.append(
				(
					tr("%s · %d/100")
					% [
						tr("Pinned" if unit.suppression.band == 2 else "Suppressed"),
						roundi(unit.suppression.meter)
					]
				)
			)
		if unit.permanent_scrap_rank > 0:
			lines.append(
				(
					tr("Scrap armor %d · −%d%% damage")
					% [unit.permanent_scrap_rank, unit.permanent_scrap_rank * 5]
				)
			)
		if unit.regarrison_lock_left > 0:
			lines.append(tr("Re-garrison · %.1f s") % unit.regarrison_lock_left)
		if unit._match.commander_support != null and unit._match.commander_support.emp.has(unit):
			lines.append(tr("EMP · %.1f s") % unit._match.commander_support.emp[unit])
		if unit.type == "PowerPlant" and unit.player.faction == "helix":
			var support = unit._match.helix_support
			if support.overdrive_status(unit) == "suspended":
				lines.append(tr("Overdrive suspended · low power"))
			elif support.operating(unit):
				lines.append(tr("Overdrive · %d shields supported") % support.affected_count(unit))
		if unit.type == "CommandCenter" and unit.player.faction == "helix":
			lines.append(
				tr("Nexus energy · %d / %d") % [floori(unit.energy), int(unit.ENERGY_CAPACITY)]
			)
			facts.append(
				"Nexus Energy regenerates at 0.5 per second. Flux Resonance costs 25 Energy."
			)
		var queue = unit.get_node_or_null("ProductionQueue")
		if queue != null and queue.has_assembly_line() and queue.completed_streak > 0:
			lines.append(
				(
					tr("Assembly streak · +%d%%")
					% roundi(queue.next_assembly_bonus(queue.last_completed_role) * 100)
				)
			)
		if "scrap_hardened_tiers" in unit and unit.scrap_hardened_tiers > 0:
			lines.append(
				(
					tr("Scrap Hardened %d · %ds")
					% [unit.scrap_hardened_tiers, ceili(unit.scrap_hardened_left)]
				)
			)
		if unit.has_method("can_scavenge") and unit.can_scavenge():
			facts.append("Right-click wrecks to repair and gain Scrap Hardened.")
		facts.push_front(load("res://source/match/combat/CombatRules.gd").describe(unit))
		for fact in UnitCounters.format_facts(unit.type, unit.player.faction):
			facts.append(fact)
		if unit.player.technology != null:
			var upgrades = unit.player.technology.summary(unit.type)
			if upgrades != "":
				facts.append(upgrades)
		if unit.type == "RepairRobot":
			facts.append("Right-click an ally to repair")
			facts.append("Repair: 1 target · 3 m (building edge)")
		if unit is Worker:
			if unit.resource_a > 0 or unit.resource_b > 0:
				lines.append("Cargo: %d M / %d E" % [unit.resource_a, unit.resource_b])
			if unit.action != null and unit.action.has_method("harvest_status"):
				lines.append(unit.action.harvest_status())
	elif _selection.all(func(member): return member is Worker):
		var gathering = 0
		var waiting = 0
		for member in _selection:
			if member.action != null and member.action.has_method("harvest_status"):
				if member.action.is_waiting():
					waiting += 1
				else:
					gathering += 1
		lines.append(
			(
				"Economy: %d gathering / %d waiting / %d other"
				% [gathering, waiting, _selection.size() - gathering - waiting]
			)
		)
	if _selection.size() > 1:
		var affected = (
			_selection
			. filter(
				func(member): return member.suppression != null and member.suppression.band > 0
			)
			. size()
		)
		if affected > 0:
			lines.append(tr("Suppressed · %d units") % affected)
	if lines.is_empty() and _selection.size() == 1:
		var description = Factions.description(unit.player.faction, unit.type)
		if not description.is_empty():
			lines.append(description)
	_status.text = "\n".join(lines.map(func(line): return tr(line)))
	_status.tooltip_text = _status.text
	_status.visible = not lines.is_empty()
	_health.tooltip_text = tr(health)
	var identity = _info.get_node_or_null("Identity")
	if identity != null:
		identity.tooltip_text = "\n".join(
			[tr(_title.text), tr(health)] + facts.map(func(fact): return tr(fact))
		)
		identity.accessibility_description = identity.tooltip_text
	if _health_dirty:
		_refresh_health()
	for entry in _buttons:
		var producer = unit if entry.construction else _production_target(entry.type)
		if producer == null:
			entry.button.disabled = true
			continue
		var info = RosterInfo.inspect(producer, entry.type, entry.construction)
		entry.cost = info.cost
		entry.button.show_role(
			entry.button.portrait(), Factions.title(unit.player.faction, entry.type), entry.cost
		)
		var became_available = entry.button.disabled and info.allowed
		entry.button.disabled = not info.allowed
		if became_available:
			load("res://source/match/hud/HudMotion.gd").play(entry.button)
		entry.button.tooltip_text = _roster_tooltip(info.text, entry.type, entry.construction)
		entry.button.accessibility_description = info.text


func _select_subset(members, remove):
	var current = _selection.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	var wanted = members.filter(func(unit): return unit in current and unit.hp > 0)
	if wanted.is_empty():
		return
	# Every requested unit is already selected. Deselect only the unwanted members;
	# selection never changes orders, production, camera or pause ownership.
	for unit in current:
		if (unit in wanted) == remove:
			unit.get_node("Selection").deselect()


func _roster_input(event, button):
	_remember_command_mouse(event)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			button.set_meta("production_batch", 5 if event.shift_pressed else 1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var quantity = 5 if event.shift_pressed else 1
			_dequeue_roster(button, quantity)
			button.accept_event()


func _dequeue_roster(button, quantity: int = 1):
	if is_instance_valid(_camp):
		var match_node = find_parent("Match")
		if match_node != null:
			var human_player = match_node._get_human_player()
			for item in _camp_buttons:
				if item.button == button:
					var role = button.name.trim_prefix("Produce")
					var canceled = 0
					for i in range(_camp.jobs.size() - 1, -1, -1):
						if canceled >= quantity:
							break
						if _camp.jobs[i].role == role and _camp.jobs[i].employer == human_player:
							_camp.cancel_hire(human_player, i)
							canceled += 1
					_refresh_camp()
					return

	var target_entry = null
	for entry in _buttons:
		if entry.button == button:
			target_entry = entry
			break
	if target_entry == null or target_entry.construction:
		return
	var unit_type = target_entry.type
	var batch_size = (
		Factions.batch_size(_selection[0].player.faction, unit_type)
		if not _selection.is_empty() and _selection[0].player.get_meta("skirmish", false)
		else 1
	)
	var cycles = floori(float(quantity) / batch_size) if quantity > 1 else 1

	for step in cycles:
		var best_producer = null
		var best_element = null
		var best_index = -1
		for producer in _selection:
			if (
				not is_instance_valid(producer)
				or producer.is_queued_for_deletion()
				or not producer is Structure
				or not "production_queue" in producer
				or producer.production_queue == null
			):
				continue
			var elements = producer.production_queue.get_elements()
			for i in range(elements.size() - 1, -1, -1):
				var el = elements[i]
				if Catalog.type_from_path(el.unit_prototype.resource_path) == unit_type:
					if i > best_index:
						best_index = i
						best_producer = producer
						best_element = el
					break
		if best_producer != null and best_element != null:
			best_producer.production_queue.cancel(best_element)
		else:
			break
	_refresh_buttons()


func _activate_roster(unit_type, construction, button):
	var quantity = button.get_meta("production_batch", 1)
	button.set_meta("production_batch", 1)
	_activate(unit_type, construction, quantity)


func _activate(unit_type, construction, quantity = 1):
	if _selection.is_empty() or not is_instance_valid(_selection[0]):
		return
	var scene = load(Factions.scene_path(_selection[0].player.faction, unit_type))
	if construction:
		MatchSignals.place_structure.emit(scene)
	else:
		# Resolve each job again so selected factories share the batch. Existing
		# affordability, queue, population and unique-hero checks apply to each unit.
		var batch_size = (
			Factions.batch_size(_selection[0].player.faction, unit_type)
			if _selection[0].player.get_meta("skirmish", false)
			else 1
		)
		var cycles = floori(float(quantity) / batch_size) if quantity > 1 else 1
		var admitted_work = {}
		for index in cycles:
			var producer = _production_target(unit_type, admitted_work)
			if producer == null:
				break
			var result = producer.production_queue.produce(scene)
			if result == null:
				break
			if result is Dictionary and result.get("network_pending", false):
				admitted_work[producer] = (
					admitted_work.get(producer, 0.0) + Factions.duration(producer.player, unit_type)
				)
	_refresh_buttons()


func _production_target(role, admitted_work: Dictionary = {}):
	var best = null
	var shortest = INF
	for producer in _selection:
		if (
			not is_instance_valid(producer)
			or producer.is_queued_for_deletion()
			or not producer is Structure
			or not producer.is_constructed()
			or role not in Factions.production_options(producer.player.faction, producer.type)
		):
			continue
		var info = RosterInfo.inspect(producer, role, false)
		var workload = admitted_work.get(producer, 0.0)
		for job in producer.production_queue.get_elements():
			workload += job.time_left
		# Keep a disabled candidate for cost/tooltips when all queues are unavailable.
		if not info.allowed:
			workload += 1e12
		elif not producer.production_queue.blocked_reason().is_empty():
			workload += 1e9
		if workload < shortest:
			shortest = workload
			best = producer
	return best


func _stop_orders():
	var rally = _selected_rally()
	if rally != null:
		rally.clear_assignment()
		_refresh_buttons()
		return
	for unit in _selection.duplicate():
		if not is_instance_valid(unit):
			continue
		if unit is Structure and unit.is_under_construction():
			unit.cancel_construction()
		else:
			unit.issue_manual_order(null)
			MatchSignals.unit_order_issued.emit(unit, "stop")


func _stop_units():
	# The grid's Stop halts units only; construction sites and rallies have own keys.
	for unit in _selection.duplicate():
		if is_instance_valid(unit) and not unit is Structure:
			unit.issue_manual_order(null)
			MatchSignals.unit_order_issued.emit(unit, "stop")


func _selected_rally():
	if _selection.size() != 1:
		return null
	var unit = _selection[0]
	if (
		not is_instance_valid(unit)
		or unit.is_queued_for_deletion()
		or not unit is Structure
		or not unit.is_constructed()
	):
		return null
	return unit.get_node_or_null("RallyPoint")


func _rally_destination(rally):
	var target = rally.target_unit
	if not is_instance_valid(target):
		return "Map destination" if rally.is_assigned() else "At producer"
	if target.is_in_group("salvage_wrecks"):
		return "Salvage"
	if "resource_a" in target and target.is_in_group("resource_units"):
		return "Materials"
	if "resource_b" in target and target.is_in_group("resource_units"):
		return "Electronics"
	return Factions.title(target.player.faction, target.type)


func _roster_tooltip(details, role, construction):
	if not construction:
		return (
			details
			+ "\n"
			+ tr("Shift-click to queue 5 units.")
			+ "\n"
			+ tr("Right-click to cancel / dequeue (Shift for 5).")
		)
	var lines = details.split("\n")
	lines[0] += " [%s]" % OS.get_keycode_string(BUILD_KEYS.find_key(role))
	return "\n".join(lines)


func open_page(title: String):
	if not is_instance_valid(_pages):
		return
	for index in _pages.get_tab_count():
		if _pages.get_child(index).name == title:
			_pages.current_tab = index
			return


func handle_menu_input(event):
	if event is InputEventKey and Bindings.pressed(event, "commander_support"):
		var game = find_parent("Match")
		var saves = get_node_or_null("/root/SaveManager")
		if (
			is_instance_valid(game.get("hud"))
			and game.hud._overlay == null
			and not is_instance_valid(Globals.settings_dialog)
			and (saves == null or not is_instance_valid(saves.dialog))
		):
			open_commander()
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventKey and is_instance_valid(_formation_controls):
		var saves = get_node_or_null("/root/SaveManager")
		var game = find_parent("Match")
		var focus = get_viewport().gui_get_focus_owner()
		var building = (
			is_instance_valid(_pages) and _pages.get_current_tab_control().name == "Build"
		)
		if (
			not building
			and not focus is LineEdit
			and not focus is TextEdit
			and not is_instance_valid(Globals.settings_dialog)
			and (saves == null or not is_instance_valid(saves.dialog))
			and game.hud._overlay == null
			and game.hud.direct_orders.kind.is_empty()
		):
			if _formation_controls.handle_input(event):
				get_viewport().set_input_as_handled()
				return true
	if (
		not event is InputEventKey
		or not event.pressed
		or event.echo
		or event.ctrl_pressed
		or event.alt_pressed
		or event.meta_pressed
	):
		return false
	var manager = get_node_or_null("/root/SaveManager")
	if (
		is_instance_valid(Globals.settings_dialog)
		or (manager != null and is_instance_valid(manager.dialog))
	):
		return false
	var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var hud = find_parent("Match").get("hud")
	var player = find_parent("Match")._get_human_player()
	if not is_instance_valid(player):
		return false
	var placement = player.get_node("StructurePlacementHandler")
	# Restoring Build as the initial worker tab must not steal a player's
	# remapped battle, camera or control-group key for a fixed building shortcut.
	var defaults = Bindings.definitions()
	for action in defaults:
		var events = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		if events.is_empty() or not events[0] is InputEventKey:
			continue
		if (
			Bindings.from_event(events[0]) != defaults[action][2]
			and Bindings.pressed(event, action)
		):
			return false
	if is_instance_valid(hud.direct_orders) and not hud.direct_orders.kind.is_empty():
		return false
	if _commander_open and code == KEY_ESCAPE:
		close_commander()
	elif _commander_open and code == KEY_Q:
		hud.direct_orders.arm_commander()
	elif _commander_open:
		return false
	elif code == KEY_ESCAPE and placement._structure_placement_started():
		placement._cancel_structure_placement()
	elif code == KEY_ESCAPE and is_instance_valid(_research_player):
		close_research()
	elif not is_visible_in_tree() or not is_instance_valid(_pages):
		return false
	elif (
		_pages.get_current_tab_control().name == "Build"
		and (
			code in [KEY_Q, KEY_W]
			or (
				code == KEY_T
				and is_instance_valid(hud.direct_orders)
				and hud.direct_orders.ability_for_key("T") != ""
			)
		)
	):
		if is_instance_valid(hud.direct_orders):
			var ability_key: String = {KEY_Q: "Q", KEY_W: "W", KEY_T: "T"}.get(code, "")
			var ability_id: String = hud.direct_orders.ability_for_key(ability_key)
			if ability_id.is_empty():
				ability_id = (
					"field_barricade"
					if code == KEY_Q
					else ("scrap_mine" if code == KEY_W else "field_bunker")
				)
			hud.direct_orders.activate_ability(ability_id)
	elif _pages.get_current_tab_control().name == "Build" and BUILD_KEYS.has(code):
		for entry in _buttons:
			if entry.construction and entry.type == BUILD_KEYS[code]:
				if not entry.button.disabled:
					_activate(entry.type, true)
				break
	elif code == KEY_B and _pages.get_node_or_null("Build") != null:
		hud.cancel_map_assignment()
		placement._cancel_structure_placement()
		open_page("Build")
	else:
		return false
	get_viewport().set_input_as_handled()
	return true


func open_research(player):
	if _research_player == player:
		return
	_camp = null
	_commander_open = false
	_research_player = player
	_reset_menus()


func close_research():
	_research_player = null
	_reset_menus()
	_queue._reset()


func _build_research():
	visible = true
	modulate.a = 1.0
	_title = Label.new()
	_title.text = tr("Technology")
	_build_info(_research_script.Presentation.icon_for("coordination"))
	_health.hide()
	_status.text = tr(Factions.NAMES[_research_player.faction])
	_status.show()
	var back = Button.new()
	back.icon = BattleTheme.icon("return")
	back.add_theme_constant_override("icon_max_width", 18)
	back.tooltip_text = tr("Back to battle") + " [Esc]"
	back.accessibility_name = back.tooltip_text
	back.pressed.connect(close_research)
	_info.add_child(back)
	_research_panel = _research_script.new()
	_research_panel.player = _research_player
	_content.add_child(_research_panel)
	find_parent("Match").hud.technology_panel = _research_panel
	_queue.hide()
	back.grab_focus()
	_fit_menu.call_deferred()


func _page(title: String) -> VBoxContainer:
	for child in _pages.get_children():
		if child.name == title:
			return child
	var page = VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 8)
	_pages.add_child(page)
	return page


func open_camp(site):
	_commander_open = false
	_camp = site
	_reset_menus()


func _build_camp():
	if not is_instance_valid(_camp) or _camp.player == null:
		_camp = null
		return
	visible = true
	modulate.a = 1.0
	_camp_buttons.clear()
	_title = Label.new()
	_title.text = tr(_camp.label_title)
	_build_info(Factions.portrait("bastion", "Barracks"))
	_health.hide()
	var heading = Label.new()
	heading.text = tr("Produce")
	heading.theme_type_variation = "HudHeading"
	_content.add_child(heading)
	var grid = GridContainer.new()
	grid.name = "Roster"
	grid.columns = HudLayout.roster_columns(get_viewport_rect().size.x)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	var Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
	for role in Sites.ROLES:
		var button = RosterButton.new()
		button.set_meta("armed", role not in ["Worker", "RepairRobot"])
		button.name = "Produce" + role
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost = Sites.price(role)
		button.show_role(
			Factions.portrait("bastion", role), tr(Factions.title("bastion", role)), cost
		)
		var counter_info = UnitCounters.format_tooltip(role, _camp.player.faction)
		button.tooltip_text = (
			tr(Factions.title("bastion", role))
			+ "\n"
			+ tr(Factions.description("bastion", role))
			+ ("\n" + counter_info if not counter_info.is_empty() else "")
			+ "\n"
			+ (
				tr("%d s production; queue wait extra.")
				% ceili(Factions.duration(_camp.player, role))
			)
		)
		button.tooltip_text += "\n" + tr("Shift-click to queue 5 units.")
		button.tooltip_text += "\n" + tr("Right-click to cancel / dequeue (Shift for 5).")
		button.accessibility_name = tr(Factions.title("bastion", role))
		button.accessibility_description = button.tooltip_text
		button.gui_input.connect(_roster_input.bind(button))
		button.pressed.connect(_hire_camp.bind(role, button))
		grid.add_child(button)
		_camp_buttons.append({"button": button, "cost": cost})
	_queue.show_camp(_camp)
	_refresh_camp()
	_fit_menu.call_deferred()


func _hire_camp(role, button):
	var quantity = button.get_meta("production_batch", 1)
	button.set_meta("production_batch", 1)
	if not is_instance_valid(_camp):
		return
	for index in quantity:
		if not _camp.hire(find_parent("Match")._get_human_player(), role):
			break
	_refresh_camp()


func _refresh_camp():
	var viewer = find_parent("Match")._get_human_player()
	if _camp.player != viewer:
		_camp = null
		_queue._reset()
		_reset_menus()
		return
	_status.text = tr(_camp.capture_status(viewer)) + "\n" + tr("%d / 3 queued") % _camp.jobs.size()
	_status.tooltip_text = _camp.capture_help(viewer)
	for entry in _camp_buttons:
		entry.button.disabled = (
			not _camp.operational()
			or _camp.jobs.size() >= 3
			or viewer.population(true) >= Catalog.POPULATION_LIMIT
			or not viewer.has_resources(entry.cost)
		)


func _clear_camp():
	if is_instance_valid(_camp):
		_camp = null
		_queue._reset()
		_queue_menu_reset()


func open_commander():
	var game = find_parent("Match")
	if game.commander_support == null or not is_instance_valid(game._get_human_player()):
		return
	game.hud.cancel_map_assignment()
	game._get_human_player().get_node("StructurePlacementHandler")._cancel_structure_placement()
	_commander_open = true
	_research_player = null
	_camp = null
	_reset_menus()


func close_commander():
	_commander_open = false
	_commander_panel = null
	find_parent("Match").hud.direct_orders.cancel()
	_reset_menus()
	if is_instance_valid(_queue):
		_queue._reset()


func _build_commander():
	visible = true
	modulate.a = 1.0
	_title = Label.new()
	_title.text = tr("Commander support")
	_build_info(BattleTheme.icon("attack"))
	_title.show()
	_health.hide()
	_status.hide()
	var back = Button.new()
	back.icon = BattleTheme.icon("return")
	back.add_theme_constant_override("icon_max_width", 18)
	back.tooltip_text = tr("Back to battle") + " [Esc]"
	back.accessibility_name = back.tooltip_text
	back.pressed.connect(close_commander)
	_info.add_child(back)
	_commander_panel = load("res://source/match/hud/CommanderPanel.gd").new()
	_commander_panel.game = find_parent("Match")
	_content.add_child(_commander_panel)
	_queue.hide()
	_fit_menu.call_deferred()


func _add_engineering_button(grid, id, title, key, glyph, cost):
	var button = RosterButton.new()
	button.show_role(BattleTheme.icon(glyph), title, {"resource_a": cost, "resource_b": 0})
	button.show_hotkey(key)
	button.accessibility_name = tr(title) + " [%s]" % key
	button.pressed.connect(func(): find_parent("Match").hud.direct_orders.arm_ability(id))
	grid.add_child(button)
	_engineering_buttons.append(
		{"button": button, "id": id, "title": title, "key": key, "cost": cost}
	)
	_refresh_engineering_buttons()


func _refresh_engineering_buttons():
	for entry in _engineering_buttons:
		var units = _selection.filter(
			func(unit):
				return (
					is_instance_valid(unit)
					and unit.abilities != null
					and unit.abilities.get_ability(entry.id) != null
				)
		)
		entry.button.disabled = not units.any(
			func(unit): return unit.abilities.availability_issue(entry.id).is_empty()
		)
		entry.button.tooltip_text = tr(entry.title) + " [%s]\n%d M" % [entry.key, entry.cost]
		if not units.is_empty():
			entry.button.tooltip_text += (
				"\n" + tr(units[0].abilities.get_ability(entry.id).description)
			)
			if entry.button.disabled:
				entry.button.tooltip_text += (
					"\n" + tr(units[0].abilities.availability_issue(entry.id))
				)
		entry.button.accessibility_description = entry.button.tooltip_text
