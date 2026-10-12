extends "res://tests/headless/ExpandedMapRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	progress_path = "user://expanded-field-approach-%d.json" % OS.get_process_id()
	root.get_node("SaveManager").autosaves_enabled = false
	# Preserve sequential earlier-field harvesting: a fresh fifth-field fixture
	# alone passed while the complete Frontier sequence exposed the route issue.
	var choices = factions.IDS
	for faction in factions.IDS:
		if ("--" + faction) in OS.get_cmdline_user_args():
			choices = [faction]
			break
	for faction in choices:
		await _create("ExpandedAlpineRelay", faction)
		await _geometry("ExpandedAlpineRelay")
		_check(await _fields() == true, "Sequential Alpine field approach aborted")
		await _close()
	DirAccess.remove_absolute(progress_path)
	for message in _errors:
		push_error(message)
	print("Expanded field approach: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
