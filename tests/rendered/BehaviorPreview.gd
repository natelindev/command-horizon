extends "res://tests/headless/BehaviorRegression.gd"


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	Engine.max_fps = 60
	await super()
	preferences.restore(original)


func _behaviors():
	await super()
	var tank = _units(game._get_human_player(), "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(tank.position)
	camera.set_size_safely(26)
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	paused = true
	await _frames(4)
	var panel = game.find_child("UnitMenus")._behavior_panel
	_check(panel._buttons.size() == 5, "Behavior deck does not show exactly five choices")
	for button in panel._buttons.values():
		_check(button.is_visible_in_tree() and button.size.x >= 80, "Behavior key is clipped")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/hud-console")
	root.get_texture().get_image().save_png(
		"res://art/hud-console/%s-behaviors.png" % game._get_human_player().faction
	)
	paused = false
