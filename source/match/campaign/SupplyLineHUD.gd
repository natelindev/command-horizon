extends "res://source/match/hud/SkirmishHUD.gd"

var objective_panel
var _truck_labels = []
var _view_buttons = []
var _advance
var _hold
var _command_panel


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 340
	_style(objective_panel)
	add_child(objective_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	objective_panel.add_child(column)
	_label(column, "SUPPLY LINE · DELIVER 2 / 3", 16)
	var hint = _label(column, "At checkpoints: hold, defend, repair, then advance.", 12)
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
	var seconds = int(mission.simulation_time)
	_clock.text = (
		"%02d:%02d · %s"
		% [
			seconds / 60,
			seconds % 60,
			(
				"PAUSED · orders ready on resume"
				if get_tree().paused
				else "Supply Line · Convoy escort"
			)
		]
	)
	objective_panel.position = Vector2(14, _command_panel.position.y + _command_panel.size.y + 10)
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
