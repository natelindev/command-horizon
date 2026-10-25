# gdlint: disable=max-file-lines
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

var _camp = null
var _camp_buttons = []
var _selection = []
var _stop_button = null
var _buttons = []
var _title = null
var _status = null
var _content = null
var _scroll: ScrollContainer
var _pages: TabContainer
var _commands: VBoxContainer
var _support: VBoxContainer
var _minimap: Control
var _queue: Control
var _refresh_elapsed = 0.0
var _orders_panel = null
var _behavior_panel = null
var _research_panel = null
var _was_under_construction = false
var _weapon_modes = null
var _signature_panel = null
var _direct_orders = null
var _command_buttons = {}
var _return_cargo = null
var _recover_health = null
var _command_mouse_held = false
var _selection_roster = null
var _discard_control_release = false
var _command_card = null
var _menu_reset_queued = false
## Left bay of the deck: portrait, name, health and status of the selection.
var _info: VBoxContainer
var _info_scroll: ScrollContainer
var _health: ProgressBar
var _health_fill: StyleBox
var _shields: ProgressBar


func _ready():
	# A content-sized bottom console beside the minimap: selection on the left,
	# direct orders and behaviors side by side, with separate build/produce pages.
	BattleTheme.apply_housing(self, 16, 12)
	custom_minimum_size = Vector2(
		HudLayout.deck_width(get_viewport_rect().size.x), HudLayout.CONSOLE_HEIGHT
	)
	var deck = HBoxContainer.new()
	deck.name = "Deck"
	deck.add_theme_constant_override("separation", 12)
	add_child(deck)
	_info_scroll = ScrollContainer.new()
	_info_scroll.name = "InfoBay"
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.custom_minimum_size.x = HudLayout.info_bay(get_viewport_rect().size.x)
	_info_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	deck.add_child(_info_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 6)
	_info_scroll.add_child(_info)
	_info.minimum_size_changed.connect(_fit_menu)
	deck.add_child(VSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.name = "CommandBay"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_scroll.get_v_scroll_bar().custom_step = 24
	deck.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 9)
	_scroll.add_child(_content)
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
	_info_scroll.custom_minimum_size.x = (
		384 if _selection.size() > 1 else HudLayout.info_bay(viewport.x)
	)
	if is_instance_valid(_status):
		_status.custom_minimum_size.x = _info_scroll.custom_minimum_size.x - 12
	var margins = get_theme_stylebox("panel").get_minimum_size().y
	var content_height = maxf(
		_content.get_combined_minimum_size().y, _info.get_combined_minimum_size().y
	)
	var height = clampf(
		content_height + margins, HudLayout.DECK_MIN_HEIGHT, HudLayout.CONSOLE_HEIGHT
	)
	var available = maxf(1, height - margins)
	_scroll.custom_minimum_size.y = available
	_info_scroll.custom_minimum_size.y = available
	custom_minimum_size = Vector2(width, height)
	# Containers grow automatically; explicitly release height after a smaller selection.
	reset_size()


func _process(delta):
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.25:
		_refresh_elapsed = 0.0
		_refresh_buttons()


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
	var previous_selection = _selection.duplicate()
	for previous_unit in previous_selection:
		if not is_instance_valid(previous_unit):
			continue
		if previous_unit.tree_exited.is_connected(_queue_menu_reset):
			previous_unit.tree_exited.disconnect(_queue_menu_reset)
		if previous_unit is Structure and previous_unit.constructed.is_connected(_queue_menu_reset):
			previous_unit.constructed.disconnect(_queue_menu_reset)
	var page_name = "Orders"
	if is_instance_valid(_pages) and _pages.current_tab >= 0:
		page_name = _pages.get_current_tab_control().name
	_scroll.scroll_vertical = 0
	_info_scroll.scroll_vertical = 0
	for container in [_content, _info]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_health = null
	_shields = null
	_buttons.clear()
	_command_buttons.clear()
	_return_cargo = null
	_recover_health = null
	_direct_orders = null
	_orders_panel = null
	_behavior_panel = null
	_research_panel = null
	_weapon_modes = null
	_signature_panel = null
	_selection_roster = null
	_command_card = null
	_stop_button = null
	_selection = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and not unit.is_queued_for_deletion()
	)
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
	_pages.add_theme_stylebox_override("panel", BattleTheme.surface(Color.TRANSPARENT, 0, 12))
	_pages.tab_changed.connect(func(_index): _fit_menu.call_deferred())
	_content.add_child(_pages)
	var production_roles = []
	for producer in _selection:
		if producer is Structure and producer.is_constructed():
			for role in Catalog.PRODUCES.get(producer.type, []):
				if role not in production_roles:
					production_roles.append(role)
	# Rosters lead for pure worker or producer selections; their main job is building.
	# Mixed selections lead with orders and the selection roster.
	var roster_page = null
	var roster_title = "Produce" if not production_roles.is_empty() else "Build"
	var builds = not production_roles.is_empty() or unit is Worker
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
	_commands = VBoxContainer.new()
	_commands.name = "DirectCommands"
	_commands.custom_minimum_size.x = 266
	_commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_commands.add_theme_constant_override("separation", 6)
	columns.add_child(_commands)
	columns.add_child(VSeparator.new())
	_support = VBoxContainer.new()
	_support.name = "UnitBehaviorAndOrders"
	_support.custom_minimum_size.x = 210
	_support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support.add_theme_constant_override("separation", 6)
	columns.add_child(_support)
	if builds and roster_page == null:
		roster_page = _page(roster_title)
	if _selection.size() > 1:
		_selection_roster = load("res://source/match/hud/SelectionRoster.gd").new()
		_selection_roster.name = "SelectionRoster"
		_selection_roster.selection = _selection.duplicate()
		_selection_roster.subset_requested.connect(_select_subset)
		_info.add_child(_selection_roster)
	_add_direct_buttons(unit)
	var grid = GridContainer.new()
	grid.name = "Roster"
	grid.columns = HudLayout.roster_columns(get_viewport_rect().size.x)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	(roster_page if roster_page != null else _commands).add_child(grid)
	for role in production_roles:
		_add_roster_button(grid, role, false)
	if researches:
		_research_panel = load("res://source/match/hud/ResearchPanel.gd").new()
		_research_panel.lab = unit
		roster_page.add_child(_research_panel)
	elif unit is Worker:
		for unit_type in Catalog.STRUCTURES:
			_add_roster_button(grid, unit_type, true)
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
	if portrait != null and _selection.size() == 1:
		var frame = PanelContainer.new()
		frame.name = "Portrait"
		frame.custom_minimum_size = Vector2(64, 64)
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
	names.add_theme_constant_override("separation", 6)
	header.add_child(names)
	_title.theme_type_variation = "HudHeading"
	_title.uppercase = true
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", BattleTheme.IVORY)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	names.add_child(_title)
	_shields = ProgressBar.new()
	_shields.name = "Shields"
	_shields.custom_minimum_size.y = 5
	_shields.show_percentage = false
	_shields.add_theme_stylebox_override("fill", BattleTheme.bar_fill(Color("68cee8")))
	_shields.mouse_filter = Control.MOUSE_FILTER_PASS
	_shields.hide()
	names.add_child(_shields)
	_health = ProgressBar.new()
	_health.name = "Health"
	_health.custom_minimum_size.y = 8
	_health.show_percentage = false
	_health_fill = BattleTheme.bar_fill(BattleTheme.HEALTH_OK)
	_health.add_theme_stylebox_override("fill", _health_fill)
	_health.mouse_filter = Control.MOUSE_FILTER_PASS
	names.add_child(_health)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("b9bfba"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = _info_scroll.custom_minimum_size.x - 12
	_info.add_child(_status)


func _refresh_health():
	if not is_instance_valid(_health):
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
	_health_fill.modulate = (
		BattleTheme.HEALTH_OK
		if ratio > .6
		else (BattleTheme.SIGNAL_WARN if ratio > .3 else BattleTheme.SIGNAL_BAD)
	)
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
	if (
		_direct_orders == null
		or not _selection.any(func(member): return member.manual_orders != null)
	):
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
	_command_card = preload("res://source/match/hud/CommandCard.gd").new()
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
	# Console tiles: the role's portrait on the left, name and price glyphs on the right.
	button.custom_minimum_size = Vector2(112, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.show_role(
		Factions.portrait(player.faction, unit_type),
		Factions.title(player.faction, unit_type),
		cost
	)
	button.tooltip_text = info.text
	button.accessibility_name = tr(Factions.title(player.faction, unit_type))
	button.accessibility_description = info.text
	button.disabled = not info.allowed
	button.pressed.connect(_activate.bind(unit_type, construction))
	grid.add_child(button)
	_buttons.append(
		{"button": button, "type": unit_type, "construction": construction, "cost": cost}
	)


func _refresh_buttons():
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
			_stop_button.text = (
				"Cancel construction · %d M / %d E back" % [refund.resource_a, refund.resource_b]
			)
			_stop_button.tooltip_text = (
				"Refunds unused construction costs, rounded down to whole resources."
				if unit.player.get_meta("skirmish", false)
				else "Refunds the full construction cost."
			)
			_stop_button.accessibility_description = (
				_stop_button.text + ". " + _stop_button.tooltip_text
			)
	# The grid resets its keys first; order keys then take their armed state and hints.
	if is_instance_valid(_command_card):
		_command_card.update_layout(_selection, _direct_orders)
	if is_instance_valid(_direct_orders):
		for kind in _command_buttons:
			var button = _command_buttons[kind]
			var spec = _direct_orders.COMMANDS[kind]
			button.set_pressed_no_signal(_direct_orders.kind == kind)
			button.disabled = _direct_orders.eligible(kind).is_empty()
			# The badge and tooltip both follow the player's configured binding.
			button.badge = Bindings.label(spec.action)
			button.tooltip_text = (
				Bindings.hint(spec.title, spec.action)
				+ "\n"
				+ spec.description
				+ " Hold %s to queue." % Bindings.label("shift_selecting")
			)
			button.accessibility_name = Bindings.hint(spec.title, spec.action)
			button.accessibility_description = button.tooltip_text
		if is_instance_valid(_return_cargo):
			var state = _direct_orders.cargo_return_state()
			_return_cargo.disabled = state.orders.is_empty()
			_return_cargo.tooltip_text = state.description
			_return_cargo.accessibility_description = state.description
		if is_instance_valid(_recover_health):
			var state = _direct_orders.recovery_state()
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
	# The bay lists only what changes or needs action. Stable facts (class, weapons,
	# upgrades, service rules) live in the identity tooltip over portrait and name.
	var lines = []
	var facts = []
	if unit is Structure:
		if unit.is_under_construction():
			lines.append("Under construction")
		else:
			if unit.player.production_factor() < 1.0:
				lines.append("Low power — production at 35%")
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
	_status.text = "\n".join(lines.map(func(line): return tr(line)))
	_status.visible = not lines.is_empty()
	_health.tooltip_text = tr(health)
	var identity = _info.get_node_or_null("Identity")
	if identity != null:
		identity.tooltip_text = "\n".join(
			[tr(_title.text), tr(health)] + facts.map(func(fact): return tr(fact))
		)
		identity.accessibility_description = identity.tooltip_text
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
		entry.button.tooltip_text = info.text
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


func _activate(unit_type, construction):
	if _selection.is_empty() or not is_instance_valid(_selection[0]):
		return
	var scene = load(Catalog.scene_path(unit_type))
	if construction:
		MatchSignals.place_structure.emit(scene)
	else:
		var producer = _production_target(unit_type)
		if producer != null:
			producer.production_queue.produce(scene)
	_refresh_buttons()


func _production_target(role):
	var best = null
	var shortest = INF
	for producer in _selection:
		if (
			not is_instance_valid(producer)
			or producer.is_queued_for_deletion()
			or not producer is Structure
			or not producer.is_constructed()
			or role not in Catalog.PRODUCES.get(producer.type, [])
		):
			continue
		var info = RosterInfo.inspect(producer, role, false)
		var workload = 0.0
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
	_camp = site
	_reset_menus()


func _build_camp():
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
		button.custom_minimum_size = Vector2(112, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost = Sites.price(role)
		button.show_role(
			Factions.portrait("bastion", role), tr(Factions.title("bastion", role)), cost
		)
		button.tooltip_text = (
			tr(Factions.title("bastion", role))
			+ "\n"
			+ tr(Factions.description("bastion", role))
			+ "\n"
			+ (
				tr("%d s production; queue wait extra.")
				% ceili(Factions.duration(_camp.player, role))
			)
		)
		button.accessibility_name = tr(Factions.title("bastion", role))
		button.accessibility_description = button.tooltip_text
		button.pressed.connect(
			func():
				if is_instance_valid(_camp):
					_camp.hire(find_parent("Match")._get_human_player(), role)
					_refresh_camp()
		)
		grid.add_child(button)
		_camp_buttons.append({"button": button, "cost": cost})
	_queue.show_camp(_camp)
	_refresh_camp()
	_fit_menu.call_deferred()


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
