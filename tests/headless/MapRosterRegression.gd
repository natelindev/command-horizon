extends "res://tests/headless/ExpandedMapRegression.gd"


func _run():
	await _menu()
	for message in _errors:
		push_error(message)
	print("Map roster and legacy preference migration: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
