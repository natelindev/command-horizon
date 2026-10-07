extends Node3D

const Bindings = preload("res://source/input/KeyBindings.gd")

var _set_action_names = [null]
var _get_action_names = [null]
var _unit_group_names = [null]


func _ready():
	for group_id in range(1, 10):
		_set_action_names.append("unit_groups_set_{0}".format([group_id]))
		_get_action_names.append("unit_groups_access_{0}".format([group_id]))
		_unit_group_names.append("unit_group_{0}".format([group_id]))


func _input(event):
	if is_instance_valid(Globals.settings_dialog):
		return
	var manager = get_node_or_null("/root/SaveManager")
	if manager != null and is_instance_valid(manager.dialog):
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var game = find_parent("Match")
	if (
		is_instance_valid(game)
		and "hud" in game
		and is_instance_valid(game.hud)
		and "_overlay" in game.hud
		and (game.hud._overlay != null or is_instance_valid(game.hud.program_editor))
	):
		return
	for group_id in range(1, 10):
		if Bindings.pressed(event, _set_action_names[group_id]):
			set_group(group_id)
			get_viewport().set_input_as_handled()
			return
		if Bindings.pressed(event, _get_action_names[group_id]):
			access_group(group_id)
			get_viewport().set_input_as_handled()
			return


func access_group(group_id: int):
	var units_in_group = Utils.Set.from_array(
		get_tree().get_nodes_in_group(_unit_group_names[group_id])
	)
	Utils.Match.select_units(units_in_group)


func set_group(group_id: int):
	for unit in get_tree().get_nodes_in_group(_unit_group_names[group_id]):
		unit.remove_from_group(_unit_group_names[group_id])
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("controlled_units"):
			unit.add_to_group(_unit_group_names[group_id])
