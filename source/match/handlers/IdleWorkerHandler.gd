extends Node

signal idle_workers_updated(count)

const Bindings = preload("res://source/input/KeyBindings.gd")

var _idle_index = 0


func _input(event):
	var globals = get_node_or_null("/root/Globals")
	if globals != null and is_instance_valid(globals.settings_dialog):
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if Bindings.pressed(event, "select_all_idle_workers"):
			select_all_idle_workers()
			get_viewport().set_input_as_handled()
		elif Bindings.pressed(event, "cycle_idle_worker"):
			cycle_idle_worker()
			get_viewport().set_input_as_handled()


func get_idle_workers() -> Array:
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return p.is_in_group("human_players")
	)
	if human_players.is_empty():
		return []
	var human = human_players[0]
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			return (
				is_instance_valid(u)
				and not u.is_queued_for_deletion()
				and u.player == human
				and u.type == "Worker"
				and u.hp != null
				and u.hp > 0
				and (u.action == null or (u.action.has_method("is_idle") and u.action.is_idle()))
			)
	)


func cycle_idle_worker():
	var idle = get_idle_workers()
	if idle.is_empty():
		return
	_idle_index = _idle_index % idle.size()
	var worker = idle[_idle_index]
	_idle_index = (_idle_index + 1) % idle.size()
	Utils.Match.select_units([worker])
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("set_position_safely"):
		camera.set_position_safely(worker.global_position)


func select_all_idle_workers():
	var idle = get_idle_workers()
	if idle.is_empty():
		return
	Utils.Match.select_units(idle)
	var camera = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("set_position_safely"):
		camera.set_position_safely(idle[0].global_position)
