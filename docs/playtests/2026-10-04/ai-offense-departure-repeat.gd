extends "res://tests/headless/SkirmishOffenseRegression.gd"

func _run():
	attack_move = load("res://source/match/units/actions/AttackMoving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for index in 4:
		print("DEPARTURE REPETITION ", index)
		await _archived_wave("desert")
		if not errors.is_empty():
			break
	manager.autosaves_enabled = autosaves
	print("Departure repetitions: ", errors)
	quit(0 if errors.is_empty() else 1)
