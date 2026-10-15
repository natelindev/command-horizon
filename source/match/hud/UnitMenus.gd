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
const HudKey = preload("res://source/match/hud/HudKey.gd")
const ORDER_GLYPHS = {"move": "move", "attack": "attack", "attack_move": "attack_move"}

var _selection = []
var _stop_button = null
var _buttons = []
var _title = null
var _status = null
var _content = null
var _scroll: ScrollContainer
var _pages: TabContainer
var _commands: VBoxContainer
var _queue: Control
var _refresh_elapsed = 0.0
var _squad_panel = null
var _orders_panel = null
var _program_panel = null
var _chip_option = null
var _research_panel = null
var _factory_program_panel = null
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
## Left bay of the deck: portrait, name, health and status of the selection.
var _info: VBoxContainer
var _info_scroll: ScrollContainer
var _health: ProgressBar
var _health_fill: StyleBox


func _ready():
	# The command deck: a heavy housing flush in the bottom-right corner with an
	# info bay (selection) beside the command bay (pages of orders and rosters).
	BattleTheme.apply_housing(self, 20, 18)
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
	_info.add_theme_constant_override("separation", 8)
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
	MatchSignals.unit_selected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_deselected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_died.connect(func(_unit): _reset_menus())
	_reset_menus()


func _fit_menu():
	# The deck fills the console; taller pages raise it, but never over the top
	# plates or a paid production queue.
	var viewport = get_viewport().get_visible_rect().size
	custom_minimum_size.x = HudLayout.deck_width(viewport.x)
	_info_scroll.custom_minimum_size.x = HudLayout.info_bay(viewport.x)
	if is_instance_valid(_status):
		_status.custom_minimum_size.x = _info_scroll.custom_minimum_size.x - 12
	var housing = get_theme_stylebox("panel").get_minimum_size().y
	var reserved = HudLayout.DECK_TOP_LIMIT + housing
	if is_instance_valid(_queue) and _queue.is_visible_in_tree():
		reserved += (
			_queue.get_combined_minimum_size().y + get_parent().get_theme_constant("separation")
		)
	var available = maxf(1, viewport.y - reserved)
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y, available)
	_info_scroll.custom_minimum_size.y = minf(_info.get_combined_minimum_size().y, available)


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


func _reset_menus():
	if _content == null or not is_inside_tree():
		return
	if (
		_command_mouse_held
		or (is_instance_valid(_selection_roster) and _selection_roster.has_active_mouse_press())
	):
		_discard_control_release = true
	var previous_selection = _selection.duplicate()
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
	_buttons.clear()
	_command_buttons.clear()
	_return_cargo = null
	_recover_health = null
	_direct_orders = null
	_squad_panel = null
	_orders_panel = null
	_program_panel = null
	_chip_option = null
	_research_panel = null
	_factory_program_panel = null
	_weapon_modes = null
	_signature_panel = null
	_selection_roster = null
	_command_card = null
	_stop_button = null
	_selection = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and not unit.is_queued_for_deletion()
	)
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
		if not selected_unit.tree_exited.is_connected(_reset_menus):
			selected_unit.tree_exited.connect(_reset_menus)
		if selected_unit is Structure and not selected_unit.constructed.is_connected(_reset_menus):
			selected_unit.constructed.connect(_reset_menus)
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
		else load(Factions.icon(unit.player.faction, unit.type))
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
	if builds and _selection.all(func(member): return member is Structure or member is Worker):
		roster_page = _page(roster_title)
	_commands = _page("Orders")
	if builds and roster_page == null:
		roster_page = _page(roster_title)
	if _selection.size() > 1:
		_selection_roster = load("res://source/match/hud/SelectionRoster.gd").new()
		_selection_roster.name = "SelectionRoster"
		_selection_roster.selection = _selection.duplicate()
		_selection_roster.subset_requested.connect(_select_subset)
		_commands.add_child(_selection_roster)
	_add_direct_buttons(unit)
	var grid = GridContainer.new()
	grid.name = "Roster"
	grid.columns = HudLayout.roster_columns(get_viewport_rect().size.x)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	(roster_page if roster_page != null else _commands).add_child(grid)
	for role in production_roles:
		_add_roster_button(grid, role, false)
	if _selection.size() == 1 and unit is Structure and unit.is_constructed():
		if unit.type == "VehicleFactory" and unit.player.get_meta("skirmish", false):
			var fit = CheckBox.new()
			_chip_option = fit
			fit.text = (
				"Fit chips to new tanks · +%d E / +%d s"
				% [
					Factions.chip_cost(unit.player.faction),
					Factions.chip_seconds(unit.player.faction)
				]
			)
			fit.button_pressed = unit.production_queue.fit_chips
			fit.disabled = not unit.player.basic_programs_unlocked()
			fit.toggled.connect(
				func(enabled):
					unit.production_queue.fit_chips = enabled
					_refresh_buttons()
			)
			_page("Programs").add_child(fit)
		if unit.player.get_meta("skirmish", false):
			if unit.type == "CommandLab":
				_research_panel = load("res://source/match/hud/ResearchPanel.gd").new()
				_research_panel.lab = unit
				_commands.add_child(_research_panel)
			if unit.type in ["VehicleFactory", "AircraftFactory"]:
				_factory_program_panel = load("res://source/match/hud/FactoryProgramPanel.gd").new()
				_factory_program_panel.queue = unit.production_queue
				_page("Programs").add_child(_factory_program_panel)
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
	# Stop / cancel / clear rally applies to the whole selection: keep it on every page.
	_info.add_child(stop)
	if not conventional and _selection.any(func(member): return member.signature != null):
		_signature_panel = load("res://source/match/hud/SignaturePanel.gd").new()
		_signature_panel.selection = _selection.duplicate()
		_commands.add_child(_signature_panel)
	if _selection.any(
		func(member): return member.type == "CombatRobot" and member.can_switch_weapon()
	):
		_weapon_modes = load("res://source/match/hud/WeaponModes.gd").new()
		_weapon_modes.selection = _selection.duplicate()
		_commands.add_child(_weapon_modes)
	if _selection.any(func(member): return member.manual_orders != null):
		_orders_panel = load("res://source/match/hud/OrdersPanel.gd").new()
		_orders_panel.selection = _selection.duplicate()
		_commands.add_child(_orders_panel)
		if conventional:
			_orders_panel._resume.hide()
	if (
		not conventional
		and unit.player.squad_roster != null
		and _selection.all(func(member): return member.movement_speed > 0)
	):
		_squad_panel = load("res://source/match/hud/SquadPanel.gd").new()
		_squad_panel.selection = _selection.duplicate()
		_page("Squads").add_child(_squad_panel)
	if not conventional and _selection.any(func(member): return member.program != null):
		_program_panel = load("res://source/match/hud/ProgramPanel.gd").new()
		_program_panel.selection = _selection.duplicate()
		_page("Programs").add_child(_program_panel)
	if previous_selection == _selection:
		for index in _pages.get_tab_count():
			if _pages.get_child(index).name == page_name:
				_pages.current_tab = index
	_pages.tabs_visible = _pages.get_tab_count() > 1
	# An empty roster would still claim page spacing.
	grid.visible = grid.get_child_count() > 0
	_refresh_buttons()
	# Rebuilding an identical selection can return to the same content minimum.
	# Refit after layout settles even when no final minimum-size signal is emitted.
	_fit_menu.call_deferred()


func _build_info(portrait):
	var header = HBoxContainer.new()
	header.name = "Identity"
	header.add_theme_constant_override("separation", 10)
	_info.add_child(header)
	if portrait != null:
		var frame = PanelContainer.new()
		frame.name = "Portrait"
		frame.custom_minimum_size = Vector2(78, 70)
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
	_title.tooltip_text = _title.text
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	names.add_child(_title)
	_health = ProgressBar.new()
	_health.name = "Health"
	_health.custom_minimum_size.y = 12
	_health.show_percentage = false
	_health_fill = BattleTheme.bar_fill(BattleTheme.HEALTH_OK)
	_health.add_theme_stylebox_override("fill", _health_fill)
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for member in _selection:
		if is_instance_valid(member) and member.hp != null:
			hp += member.hp
			hp_max += member.hp_max
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
	button.custom_minimum_size.y = 54


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
	for kind in _direct_orders.COMMANDS:
		# Icon keys: the binding sits in the badge and the full hint in the tooltip.
		var button = HudKey.new()
		button.name = "Order" + kind.capitalize().replace(" ", "")
		button.glyph = BattleTheme.icon(ORDER_GLYPHS.get(kind, "move"))
		button.caption = _direct_orders.COMMANDS[kind].title
		button.custom_minimum_size = Vector2(66, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.gui_input.connect(_remember_command_mouse)
		button.pressed.connect(_direct_orders.arm.bind(kind))
		row.add_child(button)
		_command_buttons[kind] = button
		if kind != "move" and _selection.all(func(member): return member is Worker):
			button.hide()
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
	# One row of order keys keeps the deck within the console height.
	row.add_child(_recover_health)
	_command_card = preload("res://source/match/hud/CommandCard.gd").new()
	_command_card.name = "CommandCard"
	_commands.add_child(_command_card)
	_command_card.update_layout(_selection, _direct_orders)


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
	button.name = "Build" + unit_type if construction else "Produce" + unit_type
	# Compact console tiles: the unit's plate on the left, name and cost on the right.
	button.custom_minimum_size = Vector2(104, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = "BattleCardButton"
	button.icon = load(Factions.icon(player.faction, unit_type))
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 40)
	button.add_theme_constant_override("h_separation", 6)
	button.add_theme_font_size_override("font_size", 13)
	button.text = (
		"%s\n%d M · %d E"
		% [Factions.title(player.faction, unit_type), cost.resource_a, cost.resource_b]
	)
	button.tooltip_text = info.text
	button.accessibility_name = Factions.title(player.faction, unit_type)
	button.accessibility_description = info.text
	button.disabled = not info.allowed
	button.pressed.connect(_activate.bind(unit_type, construction))
	grid.add_child(button)
	_buttons.append(
		{"button": button, "type": unit_type, "construction": construction, "cost": cost}
	)


func _refresh_buttons():
	var rally = _selected_rally()
	if is_instance_valid(_stop_button) and rally != null:
		_stop_button.text = "Clear rally"
		_stop_button.disabled = not rally.is_assigned()
		_stop_button.tooltip_text = (
			"Removes the destination for new units. Paid production and existing unit orders continue.\n"
			+ "Right-click ground, resources or a friendly unit to set a new rally."
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
	if is_instance_valid(_direct_orders):
		for kind in _command_buttons:
			var button = _command_buttons[kind]
			var spec = _direct_orders.COMMANDS[kind]
			button.badge = Bindings.label(spec.action)
			button.set_pressed_no_signal(_direct_orders.kind == kind)
			button.disabled = _direct_orders.eligible(kind).is_empty()
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
	if is_instance_valid(_command_card):
		_command_card.update_layout(_selection, _direct_orders)
	if is_instance_valid(_signature_panel):
		_signature_panel.refresh()
	if is_instance_valid(_weapon_modes):
		_weapon_modes.refresh()
	if is_instance_valid(_research_panel):
		_research_panel.refresh()
	if is_instance_valid(_squad_panel):
		_squad_panel.refresh()
	if is_instance_valid(_orders_panel):
		_orders_panel.refresh()
	if is_instance_valid(_program_panel):
		_program_panel.refresh()
	if _selection.is_empty() or not is_instance_valid(_selection[0]):
		return
	var unit = _selection[0]
	if unit is Structure and unit.is_under_construction() != _was_under_construction:
		_reset_menus()
		return
	if is_instance_valid(_chip_option):
		_chip_option.disabled = not unit.player.basic_programs_unlocked()
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
	var details = "%d / %d HP" % [ceili(unit.hp), ceili(unit.hp_max)]
	if unit is Structure:
		if unit.is_under_construction():
			details += "   ·   Under construction"
		else:
			if unit.player.production_factor() < 1.0:
				details += "   ·   Low power — production at 35%"
			if unit.type == "CommandLab":
				details += "\nBasic programs and walkers unlocked"
			elif unit.type == "RepairDepot":
				details += "\nGround service: 2 slots · 5 m"
			elif unit.type == "Barracks":
				details += "\nInfantry recovery: 2 slots · stationary within 5 m"
			elif unit.type == "AircraftFactory":
				details += "\nAircraft service: 2 slots · stationary within 5 m"
	elif unit.type == "RepairRobot":
		details += "   ·   Right-click an ally to repair"
	if _selection.size() > 1:
		var damaged = (
			_selection
			. filter(func(member): return member.hp != null and member.hp < member.hp_max)
			. size()
		)
		details = "%d selected · %d damaged" % [_selection.size(), damaged]
	if _selection.size() == 1:
		details += "\n" + load("res://source/match/combat/CombatRules.gd").describe(unit)
		if rally != null:
			details += "\nRally · " + _rally_destination(rally)
		if unit.player.technology != null:
			var upgrades = unit.player.technology.summary(unit.type)
			if upgrades != "":
				details += "\n" + upgrades
		if unit.type == "RepairRobot":
			details += "\nRepair: 1 target · 3 m (building edge)"
		if unit is Worker:
			details += "\nCargo: %d M / %d E" % [unit.resource_a, unit.resource_b]
			if unit.action != null and unit.action.has_method("harvest_status"):
				details += "\n" + unit.action.harvest_status()
	elif _selection.all(func(member): return member is Worker):
		var gathering = 0
		var waiting = 0
		for member in _selection:
			if member.action != null and member.action.has_method("harvest_status"):
				if member.action.is_waiting():
					waiting += 1
				else:
					gathering += 1
		details += (
			"\nEconomy: %d gathering / %d waiting / %d other"
			% [gathering, waiting, _selection.size() - gathering - waiting]
		)
	_status.text = details
	_refresh_health()
	for entry in _buttons:
		var producer = unit if entry.construction else _production_target(entry.type)
		if producer == null:
			entry.button.disabled = true
			continue
		var info = RosterInfo.inspect(producer, entry.type, entry.construction)
		entry.cost = info.cost
		entry.button.text = (
			"%s\n%d M · %d E"
			% [
				Factions.title(unit.player.faction, entry.type),
				entry.cost.resource_a,
				entry.cost.resource_b
			]
		)
		entry.button.disabled = not info.allowed
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
	# selection never changes orders, squads, production, camera or pause ownership.
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
