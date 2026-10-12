extends "res://source/match/hud/SkirmishHUD.gd"

var objective_panel
var _command_panel
var _zone
var _score
var _waves
var _route
var _boss


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 355
	_style(objective_panel)
	add_child(objective_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	objective_panel.add_child(column)
	_label(column, "COMMAND HORIZON", 16)
	_zone = _label(column, "", 12)
	_score = ProgressBar.new()
	_score.max_value = 30
	_score.show_percentage = false
	_score.custom_minimum_size.y = 8
	column.add_child(_score)
	_waves = _label(column, "", 12)
	_route = _label(column, "", 12)
	_boss = _label(column, "", 12)
	var row = HBoxContainer.new()
	column.add_child(row)
	_button(row, "Deployment", _view.bind(get_parent().map.DEPLOYMENT))
	_button(row, "Command", _view.bind(get_parent().map.TARGET))
	_button(row, "South pass", _view.bind(get_parent().map.SOUTH))
	var north = _button(row, "North", _view.bind(get_parent().map.NORTH))
	north.tooltip_text = "Northern ground passage opened by Broken Foundry completion."
	row = HBoxContainer.new()
	column.add_child(row)
	_button(row, "Infantry", _select.bind("infantry"))
	_button(row, "Armor", _select.bind("armor"))
	_button(row, "Air wing", _select.bind("air"))
	_button(row, "Repairs", _select.bind("repair"))
	for point in [get_parent().map.DEPLOYMENT, get_parent().map.TARGET]:
		var marker = ColorRect.new()
		marker.color = Color("edd9a2")
		marker.size = Vector2(6, 6)
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
	var minimap = mission.find_child("Minimap").get_global_rect()
	if objective_panel.get_global_rect().intersects(minimap):
		objective_panel.position = Vector2(
			_command_panel.position.x + _command_panel.size.x + 10, _command_panel.position.y
		)
	_zone.text = mission.deployment_status()
	_zone.tooltip_text = mission.deployment_help()
	_score.value = mission.hold_seconds
	if mission.opposition != null:
		_boss.text = mission.opposition.boss_status()
	_waves.text = "Responses · %d / 4" % mission.waves_sent
	if mission.waves_warned > mission.waves_sent:
		_waves.text += (
			" · next in %ds"
			% ceili(maxf(0, mission.WAVE_TIMES[mission.waves_sent] - mission.defence_time))
		)
	_route.text = (
		"North passage open · Foundry support"
		if mission.alternate_route
		else "Ground route · south pass"
	)
	if mission.settings.campaign_challenge != "":
		_route.text += (
			" · " + ("Lean" if mission.settings.campaign_challenge == "lean" else "Reinforced")
		)


func _view(point):
	get_parent().get_node("IsometricCamera3D").set_position_safely(point)


func _select(kind):
	if _overlay != null or get_parent().finished:
		return
	var roles = {
		"infantry": load("res://source/match/BastionCatalog.gd").INFANTRY_ROLES,
		"armor": ["Tank", "AdvancedTank", "CombatRobot"],
		"air": ["Drone", "Helicopter"],
		"repair": ["RepairRobot"]
	}[kind]
	var units = get_parent()._get_human_player().get_children().filter(
		func(unit):
			return unit.is_in_group("units") and unit.type in roles and get_parent()._alive(unit)
	)
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	if not units.is_empty():
		_view(units[0].global_position_yless)
