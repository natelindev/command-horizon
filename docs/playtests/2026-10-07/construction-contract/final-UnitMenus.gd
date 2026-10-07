extends PanelContainer

const Bindings = preload("res://source/input/KeyBindings.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const RosterInfo = preload("res://source/match/hud/RosterInfo.gd")
const RosterButton = preload("res://source/match/hud/RosterButton.gd")

var _selection = []
var _stop_button = null
var _buttons = []
var _title = null
var _status = null
var _content = null
var _scroll: ScrollContainer
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


func _ready():
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("19212beb")
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	add_theme_stylebox_override("panel", panel)
	custom_minimum_size.x = 510
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	_scroll.get_v_scroll_bar().custom_step = 24
	add_child(_scroll)
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
	# Keep the top resource/alert strip and any paid production queue unobscured.
	var reserved = 72 + 5 + get_theme_stylebox("panel").get_minimum_size().y
	if is_instance_valid(_queue) and _queue.is_visible_in_tree():
		reserved += (
			_queue.get_combined_minimum_size().y + get_parent().get_theme_constant("separation")
		)
	_scroll.custom_minimum_size.y = minf(
		_content.get_combined_minimum_size().y,
		maxf(1, get_viewport().get_visible_rect().size.y - reserved)
	)


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
	_scroll.scroll_vertical = 0
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
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
	_stop_button = null
	_selection = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and not unit.is_queued_for_deletion()
	)
	visible = not _selection.is_empty()
	if _selection.is_empty():
		return
	for selected_unit in _selection:
		if not selected_unit.tree_exited.is_connected(_reset_menus):
			selected_unit.tree_exited.connect(_reset_menus)
	var unit = _selection[0]
	var conventional = (
		unit._match.settings.mission_id == "supply_line"
		or _selection.all(func(member): return member.type in Catalog.MISSION_NAMES)
	)
	_was_under_construction = unit is Structure and unit.is_under_construction()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.text = (
		Factions.title(unit.player.faction, unit.type)
		if _selection.size() == 1
		else "%d units selected" % _selection.size()
	)
	_content.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("bcc7d3"))
	_content.add_child(_status)
	if _selection.size() > 1:
		_selection_roster = load("res://source/match/hud/SelectionRoster.gd").new()
		_selection_roster.name = "SelectionRoster"
		_selection_roster.selection = _selection.duplicate()
		_selection_roster.subset_requested.connect(_select_subset)
		_content.add_child(_selection_roster)
	_add_direct_buttons(unit)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	_content.add_child(grid)
	if _selection.size() == 1 and unit is Structure and unit.is_constructed():
		for unit_type in Catalog.PRODUCES.get(unit.type, []):
			_add_roster_button(grid, unit_type, false)
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
			_content.add_child(fit)
		if unit.player.get_meta("skirmish", false):
			if unit.type == "CommandLab":
				_research_panel = load("res://source/match/hud/ResearchPanel.gd").new()
				_research_panel.lab = unit
				_content.add_child(_research_panel)
			if unit.type in ["VehicleFactory", "AircraftFactory"]:
				_factory_program_panel = load("res://source/match/hud/FactoryProgramPanel.gd").new()
				_factory_program_panel.queue = unit.production_queue
				_content.add_child(_factory_program_panel)
	elif unit is Worker:
		for unit_type in Catalog.STRUCTURES:
			_add_roster_button(grid, unit_type, true)
	var stop = Button.new()
	_stop_button = stop
	stop.text = (
		"Cancel construction"
		if unit is Structure and unit.is_under_construction()
		else "Stop current orders"
	)
	stop.pressed.connect(_stop_orders)
	_content.add_child(stop)
	if not conventional and _selection.any(func(member): return member.signature != null):
		_signature_panel = load("res://source/match/hud/SignaturePanel.gd").new()
		_signature_panel.selection = _selection.duplicate()
		_content.add_child(_signature_panel)
	if _selection.any(
		func(member): return member.type == "CombatRobot" and member.can_switch_weapon()
	):
		_weapon_modes = load("res://source/match/hud/WeaponModes.gd").new()
		_weapon_modes.selection = _selection.duplicate()
		_content.add_child(_weapon_modes)
	if _selection.any(func(member): return member.manual_orders != null):
		_orders_panel = load("res://source/match/hud/OrdersPanel.gd").new()
		_orders_panel.selection = _selection.duplicate()
		_content.add_child(_orders_panel)
		if conventional:
			_orders_panel._resume.hide()
	if (
		not conventional
		and unit.player.squad_roster != null
		and _selection.all(func(member): return member.movement_speed > 0)
	):
		_squad_panel = load("res://source/match/hud/SquadPanel.gd").new()
		_squad_panel.selection = _selection.duplicate()
		_content.add_child(_squad_panel)
	if not conventional and _selection.any(func(member): return member.program != null):
		_program_panel = load("res://source/match/hud/ProgramPanel.gd").new()
		_program_panel.selection = _selection.duplicate()
		_content.add_child(_program_panel)
	_refresh_buttons()
	# Rebuilding an identical selection can return to the same content minimum.
	# Refit after layout settles even when no final minimum-size signal is emitted.
	_fit_menu.call_deferred()


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
	_content.add_child(row)
	for kind in _direct_orders.COMMANDS:
		var button = Button.new()
		button.name = "Order" + kind.capitalize().replace(" ", "")
		button.custom_minimum_size.y = 32
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
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
		_return_cargo.custom_minimum_size.y = 32
		_return_cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_return_cargo.add_theme_font_size_override("font_size", 13)
		_return_cargo.gui_input.connect(_cargo_input)
		_return_cargo.pressed.connect(
			func(): _direct_orders.return_cargo(Globals.options.selection_modifier_pressed())
		)
		row.add_child(_return_cargo)

	_recover_health = Button.new()
	_recover_health.name = "RecoverHealth"
	_recover_health.text = "Recover health"
	_recover_health.custom_minimum_size.y = 32
	_recover_health.add_theme_font_size_override("font_size", 13)
	_recover_health.gui_input.connect(_recovery_input)
	_recover_health.pressed.connect(
		func(): _direct_orders.recover_health(Globals.options.selection_modifier_pressed())
	)
	_content.add_child(_recover_health)


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
	var info = RosterInfo.inspect(_selection[0], unit_type, construction)
	var cost = info.cost
	var button = RosterButton.new()
	button.name = "Build" + unit_type if construction else "Produce" + unit_type
	button.custom_minimum_size = Vector2(154, 74)
	button.icon = load(Factions.icon(player.faction, unit_type))
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 42)
	button.add_theme_font_size_override("font_size", 12)
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
			button.text = Bindings.hint(spec.title, spec.action)
			button.set_pressed_no_signal(_direct_orders.kind == kind)
			button.disabled = _direct_orders.eligible(kind).is_empty()
			button.tooltip_text = (
				spec.description + " Hold %s to queue." % Bindings.label("shift_selecting")
			)
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
	# Mixed selections intentionally have no production grid to rebuild.
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
	for entry in _buttons:
		var info = RosterInfo.inspect(unit, entry.type, entry.construction)
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
		_selection[0].production_queue.produce(scene)
	_refresh_buttons()


func _stop_orders():
	for unit in _selection.duplicate():
		if not is_instance_valid(unit):
			continue
		if unit is Structure and unit.is_under_construction():
			unit.cancel_construction()
		else:
			unit.issue_manual_order(null)
