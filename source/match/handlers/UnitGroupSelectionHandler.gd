extends Node3D

signal groups_changed

const Bindings = preload("res://source/input/KeyBindings.gd")

var subgroups = preload("res://source/match/handlers/SubgroupSelection.gd").new()

var _set_action_names = [null]
var _get_action_names = [null]
var _unit_group_names = [null]
var _last_access_id = -1
var _last_access_time = -1


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	MatchSignals.unit_selected.connect(subgroups.changed)
	MatchSignals.unit_deselected.connect(_selection_changed)
	MatchSignals.deselect_all_units.connect(subgroups.changed)
	for group_id in range(1, 10):
		_set_action_names.append("unit_groups_set_{0}".format([group_id]))
		_get_action_names.append("unit_groups_access_{0}".format([group_id]))
		_unit_group_names.append("unit_group_{0}".format([group_id]))


func _input(event):
	if _blocked():
		return
	var game = find_parent("Match")
	if Bindings.pressed(event, "cycle_subgroup"):
		# Tab traverses the docked research controls while they own keyboard focus.
		# Otherwise it retains its battlefield subgroup shortcut.
		var focus = get_viewport().gui_get_focus_owner()
		var menus = game.find_child("UnitMenus") if is_instance_valid(game) else null
		if is_instance_valid(menus) and is_instance_valid(menus._research_panel):
			if focus != null and menus._research_panel.is_ancestor_of(focus):
				return
		var message = subgroups.cycle(get_tree())
		if not message.is_empty():
			if is_instance_valid(game) and "hud" in game and is_instance_valid(game.hud):
				if game.hud.has_method("cancel_map_assignment"):
					game.hud.cancel_map_assignment()
				if game.hud.has_method("show_notice"):
					game.hud.show_notice(message)
			get_viewport().set_input_as_handled()
		return
	for group_id in range(1, 10):
		if Bindings.pressed(event, _set_action_names[group_id]):
			if "shift_pressed" in event and event.shift_pressed:
				append_to_group(group_id)
			else:
				set_group(group_id)
			get_viewport().set_input_as_handled()
			return
		if Bindings.pressed(event, _get_action_names[group_id]):
			access_group(group_id)
			get_viewport().set_input_as_handled()
			return


func _blocked():
	var globals = get_node_or_null("/root/Globals")
	var manager = get_node_or_null("/root/SaveManager")
	var focus = get_viewport().gui_get_focus_owner()
	var game = find_parent("Match")
	return (
		(globals != null and is_instance_valid(globals.settings_dialog))
		or (manager != null and is_instance_valid(manager.dialog))
		or focus is LineEdit
		or focus is TextEdit
		or (
			is_instance_valid(game)
			and (
				("finished" in game and game.finished)
				or (
					"hud" in game
					and is_instance_valid(game.hud)
					and "_overlay" in game.hud
					and game.hud._overlay != null
				)
			)
		)
	)


func _selection_changed(unit):
	# Losing a member while cycling must not discard the remaining full army.
	if (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and (not "hp" in unit or unit.hp == null or unit.hp > 0)
	):
		subgroups.changed(unit)


func access_group(group_id: int):
	subgroups.changed()
	var raw_nodes = get_tree().get_nodes_in_group(_unit_group_names[group_id])
	if raw_nodes.is_empty():
		return
	var units_in_group = Utils.Set.from_array(raw_nodes)
	Utils.Match.select_units(units_in_group)
	var now = Time.get_ticks_msec()
	if _last_access_id == group_id and (now - _last_access_time) < 400:
		_snap_camera_to_units(raw_nodes)
	_last_access_id = group_id
	_last_access_time = now


func _snap_camera_to_units(units):
	var center = Vector3.ZERO
	var valid_count = 0
	for unit in units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			center += unit.global_position
			valid_count += 1
	if valid_count > 0:
		center /= valid_count
		var camera = get_viewport().get_camera_3d()
		if camera != null and camera.has_method("set_position_safely"):
			camera.set_position_safely(center)


func set_group(group_id: int):
	for unit in get_tree().get_nodes_in_group(_unit_group_names[group_id]):
		unit.remove_from_group(_unit_group_names[group_id])
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("controlled_units"):
			unit.add_to_group(_unit_group_names[group_id])
	groups_changed.emit()


func append_to_group(group_id: int):
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("controlled_units"):
			if not unit.is_in_group(_unit_group_names[group_id]):
				unit.add_to_group(_unit_group_names[group_id])
	groups_changed.emit()
