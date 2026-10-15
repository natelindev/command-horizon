extends "res://source/match/hud/SkirmishHUD.gd"

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

var objective_panel: PanelContainer
var _score: ProgressBar
var _status: Label
var _optional: Label
var _relay_labels = []
var _markers = []
var _command_panel: Control
var _relay_buttons = []
var _infantry_buttons = []


func _ready():
	super()
	_command_panel = get_child(0)
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size.x = 310
	_style(objective_panel)
	add_child(objective_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	objective_panel.add_child(column)
	var title = _label(column, "LINK TWO RELAYS", 16)
	title.tooltip_text = (
		"Infantry capture in 10 seconds; enemy ground forces contest. "
		+ "Uplink progress is retained when a relay is lost. "
		+ "Try two Guard areas with Service area support. Manual orders always take priority."
	)
	_label(column, "Hold any two. Keep your accumulated progress.", 13)
	_score = ProgressBar.new()
	_score.max_value = 120
	_score.show_percentage = false
	_score.custom_minimum_size.y = 10
	column.add_child(_score)
	_status = _label(column, "", 13)
	var mission = get_parent()
	var markers = CanvasLayer.new()
	markers.layer = -1
	add_child(markers)
	for index in 3:
		# The mission locator owns the relay title; the panel owns its live status.
		# Avoid drawing the shared 3D label underneath the same screen-space title.
		mission.map.relays[index]._label.hide()
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var label = _label(row, mission.map.NAMES[index], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_relay_labels.append(label)
		_relay_buttons.append(_button(row, "View", _view_relay.bind(index)))
		_infantry_buttons.append(_button(row, "Find infantry", _find_capture_unit.bind(index)))
		var marker = _label(markers, "◆  " + (tr("%s relay") % tr(mission.map.NAMES[index])), 14)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_theme_color_override("font_shadow_color", Color.BLACK)
		marker.add_theme_constant_override("shadow_offset_x", 2)
		marker.add_theme_constant_override("shadow_offset_y", 2)
		_markers.append(marker)
		var minimap_marker = ColorRect.new()
		minimap_marker.color = Color("e3e9ed")
		minimap_marker.size = Vector2(6, 6)
		minimap_marker.position = mission.map.POINTS[index] * 2 - Vector2(3, 3)
		minimap_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap_marker.z_index = 2
		mission.find_child("MinimapViewport").add_child(minimap_marker)
	_optional = _label(column, "", 12)


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
	_score.value = mission.control_seconds
	_status.text = (
		"%d / 120 s · Responses %d / 6" % [int(mission.control_seconds), mission.waves_sent]
	)
	_optional.text = (
		"Optional · full network %d / 20 s%s"
		% [int(mission.network_seconds), " · earned" if mission.network_badge else ""]
	)
	var camera = get_viewport().get_camera_3d()
	for index in 3:
		var relay = mission.map.relays[index]
		var human = mission._get_human_player()
		_relay_labels[index].text = mission.map.NAMES[index] + " · " + relay.capture_status(human)
		_relay_labels[index].tooltip_text = relay.capture_help(human)
		_relay_buttons[index].accessibility_description = (
			_relay_labels[index].text + ". " + _relay_labels[index].tooltip_text
		)
		var recovery = _infantry_buttons[index]
		recovery.visible = relay.needs_infantry(human) and not mission.finished
		if recovery.visible:
			var target = _capture_unit(index)
			recovery.disabled = target == null
			recovery.text = (
				"Find barracks" if target != null and target.type == "Barracks" else "Find infantry"
			)
			recovery.tooltip_text = (
				"Select infantry for this relay; idle units come first. Existing orders are preserved."
				if target != null and InfantryRoster.is_infantry(target.type)
				else "Select your barracks to train replacement infantry."
			)
			if target == null:
				recovery.tooltip_text = (
					"No infantry or completed barracks remain. "
					+ "Build a barracks to replace infantry."
				)
			recovery.accessibility_description = (
				mission.map.NAMES[index] + " relay. " + recovery.tooltip_text
			)
		_markers[index].text = "◆  " + (tr("%s relay") % tr(mission.map.NAMES[index]))
		var point = relay.global_position + Vector3.UP * 4.5
		_markers[index].position = camera.unproject_position(point) - _markers[index].size * 0.5
		_markers[index].visible = (
			not camera.is_position_behind(point)
			and get_viewport().get_visible_rect().encloses(_markers[index].get_rect())
		)


func _view_relay(index):
	var mission = get_parent()
	mission.get_node("IsometricCamera3D").set_position_safely(mission.map.relays[index].position)


func _capture_unit(index):
	var mission = get_parent()
	var units = mission._get_human_player().get_children().filter(
		func(unit):
			return unit.is_in_group("units") and unit.hp > 0 and not unit.is_queued_for_deletion()
	)
	var candidates = units.filter(func(unit): return InfantryRoster.is_infantry(unit.type))
	if candidates.is_empty():
		candidates = units.filter(
			func(unit): return unit.type == "Barracks" and not unit.is_under_construction()
		)
	var point = mission.map.relays[index].position
	candidates.sort_custom(
		func(a, b):
			if _capture_idle(a) != _capture_idle(b):
				return _capture_idle(a)
			return a.position.distance_squared_to(point) < b.position.distance_squared_to(point)
	)
	return candidates[0] if not candidates.is_empty() else null


func _capture_idle(unit):
	if not InfantryRoster.is_infantry(unit.type):
		return false
	if not unit.manual_orders.pending.is_empty() or not unit.manual_orders.current.is_empty():
		return false
	return (
		not is_instance_valid(unit.action)
		or (unit.action.has_method("is_idle") and unit.action.is_idle())
	)


func _find_capture_unit(index):
	if get_parent().finished:
		return
	var unit = _capture_unit(index)
	if unit == null:
		return
	MatchSignals.deselect_all_units.emit()
	unit.get_node("Selection").select()
	get_parent().get_node("IsometricCamera3D").set_position_safely(unit.position)
