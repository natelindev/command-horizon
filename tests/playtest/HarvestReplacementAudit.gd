extends "res://tests/headless/HarvestTrafficRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest_script = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for repetition in 12:
		var previous_errors = errors.size()
		await _manual_replacement()
		print("HARVEST REPLACEMENT ", repetition, " failures=", errors.size() - previous_errors)
	for message in errors:
		push_error(message)
	print("Harvest replacement audit: %d failures in 12 replays" % errors.size())
	quit(0 if errors.is_empty() else 1)
