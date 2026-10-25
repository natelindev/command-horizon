extends "res://tests/headless/RosterLayoutRegression.gd"

var capture_prefix = ""


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await super()
	options.restore(original)


func _review_layout(menus, label):
	await RenderingServer.frame_post_draw
	var viewport = root.get_visible_rect()
	_check(viewport.encloses(menus.get_global_rect()), label + ": panel outside viewport")
	for entry in menus._buttons:
		var button = entry.button
		print(
			"TILE ",
			label,
			" ",
			entry.type,
			" rect=",
			button.get_global_rect(),
			" panel=",
			menus.get_global_rect(),
			" scroll=",
			menus._command_bay.get_global_rect(),
			" minimum=",
			button.get_combined_minimum_size(),
			" icon=",
			button.icon.get_size()
		)
		_check(
			button.get_global_rect().end.x <= menus.get_global_rect().end.x,
			label + ": tile extends beyond panel " + entry.type
		)
	if (
		capture_prefix != ""
		and (
			label.ends_with("Worker")
			or label.ends_with("VehicleFactory")
			or label.ends_with("AircraftFactory")
		)
	):
		var destination = capture_prefix + "-" + label + ".png"
		_check(not FileAccess.file_exists(destination), "Capture already exists")
		if not FileAccess.file_exists(destination):
			root.get_texture().get_image().save_png(destination)
