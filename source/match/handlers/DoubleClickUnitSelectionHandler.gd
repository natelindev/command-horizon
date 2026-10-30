extends Node3D


func _ready():
	MatchSignals.unit_spawned.connect(_connect_unit)
	for unit in get_tree().get_nodes_in_group("units"):
		_connect_unit(unit)


func _connect_unit(unit):
	var callback = _on_unit_input.bind(unit)
	if not unit.input_event.is_connected(callback):
		unit.input_event.connect(callback)


func handle_double_click(unit_type):
	var units_to_select = Utils.Set.new()
	var camera = get_viewport().get_camera_3d()
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		if not unit.visible or not camera.is_position_in_frustum(unit.global_position):
			continue
		if unit.type == unit_type:
			units_to_select.add(unit)
	Utils.Match.select_units(units_to_select)


func _handle_double_click(unit_type):
	handle_double_click(unit_type)


func _on_unit_input(_camera, event, _click_position, _click_normal, _shape_index, unit):
	# Selection signals also come from panels, control groups and box selection.
	# Only a double-click on a world unit requests all visible units of its type.
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
		and unit.is_in_group("controlled_units")
	):
		_handle_double_click(unit.type)
