extends Node

var restoring = false


func _to_string():
	var action_script_path = get_script().resource_path
	var action_file_name = action_script_path.substr(action_script_path.rfind("/") + 1)
	var action_name = action_file_name.split(".")[0]
	return action_name


func _enter_tree():
	if not child_entered_tree.is_connected(_fixed_action_clock):
		child_entered_tree.connect(_fixed_action_clock)


func _fixed_action_clock(child):
	if child is Timer:
		var game = find_parent("Match")
		if game != null and game.has_meta("network_session"):
			child.process_callback = Timer.TIMER_PROCESS_PHYSICS
