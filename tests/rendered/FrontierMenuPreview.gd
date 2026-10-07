extends "res://tests/headless/FrontierRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _frontier_menu()
	print("Frontier menu input: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
