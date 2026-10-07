extends "res://tests/headless/AttackArrivalProgressRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var entry = 4
	var trials = 20
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--entry="):
			entry = argument.trim_prefix("--entry=").to_int()
		if argument.begins_with("--trials="):
			trials = argument.trim_prefix("--trials=").to_int()
	current_case = LATE_CASES[entry]
	for repetition in trials:
		await _captured_attack(repetition)
	for message in errors:
		push_error(message)
	print("Arrival repeat audit: %d failures in %d replays" % [errors.size(), trials])
	quit(0 if errors.is_empty() else 1)
