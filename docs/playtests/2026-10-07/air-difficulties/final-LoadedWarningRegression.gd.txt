extends "res://tests/headless/SaveRestoreEdges.gd"


func _edge_cases():
	await super()
	_check(
		game.hud._assignment_hint.text.begins_with("Battle loaded. "),
		"Restore warning lost its load confirmation"
	)
	_check(
		"Invalid program memory discarded." in game.hud._assignment_hint.text,
		"Restore warning was hidden after resuming"
	)
	_check(not "paused" in game.hud._assignment_hint.text, "Restore warning claims stale pause")
