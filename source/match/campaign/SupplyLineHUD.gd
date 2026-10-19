extends "res://source/match/hud/SkirmishHUD.gd"

var objective_panel
var _truck_labels = []
var _view_buttons = []
var _advance
var _hold
var _repair
var _guidance: Label
var _command_panel
var _objective_scroll: ScrollContainer
var _objective_content: VBoxContainer


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 340
	_style(objective_panel)
	add_child(objective_panel)
	_objective_scroll = ScrollContainer.new()
	_objective_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_objective_scroll.follow_focus = true
	objective_panel.add_child(_objective_scroll)
	var column = VBoxContainer.new()
	_objective_content = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	_objective_scroll.add_child(column)
	_label(column, "SUPPLY LINE · DELIVER 2 / 3", 16)
	var hint = _label(
		column, "Save 2 trucks. Clear each checkpoint for 12 seconds, then advance again.", 12
	)
	hint.custom_minimum_size.x = 308
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance = _label(column, "", 12)
	_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.tooltip_text = (
		"Repair robots: right-click a damaged truck. Scout and screen with your escorts. "
		+ "Truck and escort orders remain separate. Use tactical pause to plan orders."
	)
	for index in 3:
		_truck_labels.append(_label(column, "", 12))
	var commands = HBoxContainer.new()
	commands.add_theme_constant_override("separation", 5)
	column.add_child(commands)
	_advance = _button(commands, "Advance convoy", func(): get_parent().advance_convoy())
	_hold = _button(commands, "Hold convoy", func(): get_parent().hold_convoy())
	_repair = _button(
		commands,
		"Repair support",
		func():
			_select(get_parent().escorts().filter(func(unit): return unit.type == "RepairRobot"))
	)
	_repair.tooltip_text = "Select repair robots, then right-click a damaged truck."
	_advance.tooltip_text = (
		"Send surviving trucks to their next checkpoint. " + "Escorts keep their own orders."
	)
	_hold.tooltip_text = "Stop trucks at the checkpoint so clearance can progress."
	var selection = HBoxContainer.new()
	selection.add_theme_constant_override("separation", 5)
	column.add_child(selection)
	_button(selection, "Select trucks", func(): _select(get_parent().trucks()))
	_button(selection, "Select escorts", func(): _select(get_parent().escorts()))
	for index in 3:
		var button = _button(selection, str(index + 1), _view.bind(index))
		button.tooltip_text = get_parent().map.NAMES[index]
		_view_buttons.append(button)
		var marker = ColorRect.new()
		marker.color = Color("e8ce93")
		marker.size = Vector2(6, 6)
		var point = get_parent().map.POINTS[index]
		marker.position = Vector2(point.x, point.z) * 2 - Vector2(3, 3)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.z_index = 2
		get_parent().find_child("MinimapViewport").add_child(marker)


func _label(parent, text, size):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _process(delta):
	super(delta)
	var mission = get_parent()
	_repair.disabled = not mission.escorts().any(func(unit): return unit.type == "RepairRobot")
	objective_panel.position = Vector2(0, _command_panel.position.y + _command_panel.size.y + 8)
	var available = (
		get_viewport().get_visible_rect().size.y
		- HudLayout.CONSOLE_HEIGHT
		- HudLayout.GAP
		- objective_panel.position.y
	)
	var margins = objective_panel.get_theme_stylebox("panel").get_minimum_size().y
	_objective_scroll.custom_minimum_size.y = minf(
		_objective_content.get_combined_minimum_size().y, maxf(80, available - margins)
	)
	objective_panel.size.y = _objective_scroll.custom_minimum_size.y + margins
	_guidance.text = mission.convoy_guidance()
	for index in mission.convoy.size():
		var entry = mission.convoy[index]
		var state = "Extracted" if entry.delivered else "Lost"
		_truck_labels[index].tooltip_text = ""
		if mission._alive(entry):
			var clearance = "%d/12 s" % int(entry.clearance)
			if (
				entry.unit.position.distance_to(mission.map.POINTS[entry.leg]) > 7
				and not entry.unit.get_node("Movement")._has_destination
			):
				clearance = "Order advance"
			if (
				entry.unit.position.distance_to(mission.map.POINTS[entry.leg]) <= 7
				and entry.unit.get_node("Movement")._has_destination
			):
				clearance = "Hold to clear"
			elif (
				entry.unit.position.distance_to(mission.map.POINTS[entry.leg]) <= 7
				and mission.checkpoint_contested(entry.leg)
			):
				clearance = "Contested · " + clearance
				_truck_labels[index].tooltip_text = (
					"Enemy ground units within 10 metres suspend clearance. "
					+ "Use your escorts to clear the checkpoint; progress is retained."
				)
			state = (
				"%d%% HP · %s · %s"
				% [100 * entry.unit.hp / entry.unit.hp_max, mission.map.NAMES[entry.leg], clearance]
			)
		_truck_labels[index].text = "Truck %d · %s" % [index + 1, state]
	_advance.disabled = mission.finished or mission.trucks().is_empty()
	_hold.disabled = _advance.disabled


func _select(units):
	if _overlay != null or get_parent().finished:
		return
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	if not units.is_empty():
		get_parent().get_node("IsometricCamera3D").set_position_safely(units[0].position)


func _view(index):
	get_parent().get_node("IsometricCamera3D").set_position_safely(get_parent().map.POINTS[index])
