extends "res://tests/headless/ArrivalWindowRegression.gd"

func _run():
	await _held_window()
	for message in errors:
		push_error(message)
	print("Held window probe: ", errors.size(), " failures")
	quit(0 if errors.is_empty() else 1)
