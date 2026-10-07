extends "res://tests/headless/GuardEndpointRegression.gd"

var captures = ""


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _endpoint_case(faction, mode):
	if faction != "frontier":
		return
	await super(faction, mode)


func _review_endpoint(unit, label):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(18)
	camera.set_position_safely(unit.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	await _frames(15)
	var menus = game.find_child("UnitMenus")
	_check(root.get_visible_rect().encloses(menus.get_global_rect()), "Guard menu leaves viewport")
	if captures != "":
		await RenderingServer.frame_post_draw
		var file = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(file), "Guard capture already exists")
		if not FileAccess.file_exists(file):
			root.get_texture().get_image().save_png(file)
