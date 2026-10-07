extends "res://source/match/hud/SkirmishHUD.gd"

var objective_panel
var _command_panel
var _node_labels = []
var _capture
var _response
var _score


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 360
	_style(objective_panel)
	add_child(objective_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	objective_panel.add_child(column)
	var title = _label(column, "BROKEN FOUNDRY", 16)
	title.tooltip_text = (
		"Warehouses block sight and ground movement. Protect repair support; "
		+ "repair channels do not stack. Guard areas limit pursuit. "
		+ "Infantry capture in 10 seconds, then stay for 30 uncontested seconds. "
		+ "Secured time is retained when you leave or lose control."
	)
	for index in 2:
		var row = HBoxContainer.new()
		column.add_child(row)
		var label = _label(row, "", 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_node_labels.append(label)
		_button(row, "View", _view.bind(get_parent().map.NODES[index]))
	_capture = _label(column, "", 12)
	_score = ProgressBar.new()
	_score.max_value = 30
	_score.show_percentage = false
	_score.custom_minimum_size.y = 8
	column.add_child(_score)
	_response = _label(column, "", 12)
	var row = HBoxContainer.new()
	column.add_child(row)
	_button(row, "Foundry", _view.bind(get_parent().map.CONTROL))
	_button(row, "Infantry", _select.bind("Infantry"))
	_button(row, "Repairs", _select.bind("RepairRobot"))
	for point in get_parent().map.NODES + [get_parent().map.CONTROL]:
		var marker = ColorRect.new()
		marker.size = Vector2(6, 6)
		marker.color = Color("edd9a2")
		marker.position = Vector2(point.x, point.z) * 2 - Vector2(3, 3)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.z_index = 2
		get_parent().find_child("MinimapViewport").add_child(marker)


func _label(parent, text, size):
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _process(delta):
	super(delta)
	var mission = get_parent()
	objective_panel.position = Vector2(14, _command_panel.position.y + _command_panel.size.y + 10)
	for index in mission.nodes.size():
		var entry = mission.nodes[index]
		var status = "Disabled"
		if not entry.disabled:
			var queued = (
				entry.unit.get_node("ProductionQueue").size() if mission._alive(entry.unit) else 0
			)
			status = "%d / 3 batches · %d queued" % [entry.batches, queued]
			if mission.alarm and entry.batches < 3:
				status += " · %ds" % ceili(entry.left) if entry.left > 0 else " · Waiting"
		_node_labels[index].tooltip_text = ""
		if not entry.disabled and mission.alarm and entry.batches < 3 and entry.left == 0:
			_node_labels[index].tooltip_text = (
				mission.batch_wait_reason(entry)
				+ (
					". The next %d-unit batch is retained; already paid jobs keep their place."
					% mission.batch_size()
				)
			)
		_node_labels[index].text = "%s · %s" % [["North", "South"][index], status]
	_capture.text = mission.control_status()
	_capture.tooltip_text = mission.control_help()
	_score.value = mission.hold_seconds
	_response.text = "Production waits until you enter the district."
	if mission.alarm:
		_response.text = "Three paid batches per node. Destroy nodes to stop them."
	if mission.response_left >= 0:
		_response.text = (
			"Final response resolved."
			if mission.response_done
			else "East response in %ds" % ceili(mission.response_left)
		)


func _view(point):
	get_parent().get_node("IsometricCamera3D").set_position_safely(point)


func _select(role):
	if _overlay != null or get_parent().finished:
		return
	MatchSignals.deselect_all_units.emit()
	var units = get_parent()._get_human_player().get_children().filter(
		func(unit):
			return unit.is_in_group("units") and unit.type == role and get_parent()._alive(unit)
	)
	for unit in units:
		unit.get_node("Selection").select()
	if not units.is_empty():
		_view(units[0].global_position_yless)
