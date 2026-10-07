extends "res://tests/headless/AlpineRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	_check(await _menu_review() == true, "Menu review did not finish")
	print("Alpine menu: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
