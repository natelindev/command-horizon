extends "res://source/match/hud/SkirmishHUD.gd"

var objective_panel
var _command_panel
var _site_buttons = []
var _flight_labels = []
var _launch
var _finish
var _continue
var _status


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 350
	_style(objective_panel)
	add_child(objective_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	objective_panel.add_child(column)
	_label(column, "AIR CORRIDOR · EVACUATION", 16)
	var sites_row = HBoxContainer.new()
	column.add_child(sites_row)
	for index in 2:
		_site_buttons.append(_button(sites_row, "", _view.bind(get_parent().map.SITES[index])))
	_button(sites_row, "Escort position", _view.bind(get_parent().map.SCREEN))
	_button(sites_row, "Exit", _view.bind(get_parent().map.EXIT))
	for index in 3:
		_flight_labels.append(_label(column, "", 12))
	var commands = HBoxContainer.new()
	column.add_child(commands)
	_launch = _button(commands, "Launch flight", func(): get_parent().launch_flight())
	_continue = _button(commands, "Continue flight", func(): get_parent().continue_flight())
	_finish = _button(commands, "Finish operation", func(): get_parent().finish_evacuation())
	var selections = HBoxContainer.new()
	column.add_child(selections)
	_button(selections, "Ground screen", _select.bind("ground"))
	_button(selections, "Air wing", _select.bind("air"))
	_button(selections, "Active flight", _select.bind("flight"))
	_button(selections, "Hangar", _view.bind(Vector3(14, 0, 62)))
	_status = _label(column, "", 12)
	_status.custom_minimum_size.x = 320
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for point in get_parent().map.SITES + [get_parent().map.LAUNCH, get_parent().map.EXIT]:
		var marker = ColorRect.new()
		marker.size = Vector2(6, 6)
		marker.color = Color("edd9a2")
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
	objective_panel.position = Vector2(0, _command_panel.position.y + _command_panel.size.y + 8)
	for index in mission.sites.size():
		_site_buttons[index].text = (
			"%s · %s"
			% [
				["North AA", "South AA"][index],
				"Clear" if mission.sites[index].cleared else "Active"
			]
		)
	var holding = false
	for index in mission.flights.size():
		var flight = mission.flights[index]
		var text = {
			"ready": "Ready to board", "flying": "In flight", "extracted": "Safe", "lost": "Lost"
		}[flight.state]
		var stopped = (
			flight.state == "flying"
			and mission._alive(flight.unit)
			and not flight.unit.get_node("Movement")._has_destination
		)
		if stopped:
			text = "Holding"
			holding = true
		_flight_labels[index].tooltip_text = (
			"Holding position. Continue flight sends this transport to extraction."
			if stopped
			else ""
		)
		if mission._alive(flight.unit):
			text += " · %d%% HP" % (100 * flight.unit.hp / flight.unit.hp_max)
		if flight.response_left >= 0 and not flight.response_done:
			text += " · Response %ds" % ceili(flight.response_left)
		_flight_labels[index].text = "Flight %d · %s" % [index + 1, text]
	_launch.disabled = not mission.launch_reason().is_empty()
	_launch.tooltip_text = mission.launch_reason()
	_continue.disabled = (
		mission.finished or not mission.flights.any(func(flight): return flight.state == "flying")
	)
	_continue.tooltip_text = "Send the active transport to extraction, replacing its current orders."
	_finish.disabled = mission.finished or mission.rescued() < 2
	_status.text = "Ground screen counters AA; walkers cover air."
	_status.tooltip_text = (
		"Ground troops counter mobile anti-air; walkers protect against aircraft. "
		+ "Strike aircraft can return to the flight hangar for stationary repairs. "
		+ "Programs and direct orders both work. All three flights saved earns operation 05 support."
	)
	if holding:
		_status.text = "Flight holding. Use Continue flight when ready."
	if mission.rescued() >= 2:
		_status.text = (
			"All three flights safe."
			if mission.rescued() == 3
			else (
				"Two flights safe." if mission.finished else "Two safe · Finish, or save all three."
			)
		)

	# Reflow can reduce the label height after a load or a change of flight state.
	objective_panel.size.y = objective_panel.get_combined_minimum_size().y


func _select(kind):
	if _overlay != null or get_parent().finished:
		return
	var units = get_parent()._get_human_player().get_children().filter(
		func(unit):
			if not unit.is_in_group("units") or not get_parent()._alive(unit):
				return false
			if kind == "flight":
				return unit.type == "EvacTransport"
			if kind == "air":
				return load("res://source/match/BastionCatalog.gd").is_aircraft(unit.type)
			return unit.movement_speed > 0 and unit.movement_domain == 1 and unit.type != "Worker"
	)
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	if not units.is_empty():
		_view(units[0].global_position_yless)


func _view(point):
	get_parent().get_node("IsometricCamera3D").set_position_safely(point)
