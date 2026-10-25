extends "res://tests/headless/RecoveryCoverageRegression.gd"

var capture_prefix = ""


func _run():
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			capture_prefix = arg.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _activate_coverage(faction, button):
	if faction != "helix":
		await super(faction, button)
		return
	var deadline = Time.get_ticks_msec() + 180000
	print("NATIVE COVERAGE: activate partial Recover health ", button.get_global_rect())
	while patient.manual_orders.pending.is_empty() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(not patient.manual_orders.pending.is_empty(), "Native partial recovery timed out")
	await _frames(5)


func _review_coverage(label, menus):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(12)
	_check(
		root.get_visible_rect().encloses(menus.get_global_rect()), "Coverage panel outside viewport"
	)
	_check(
		menus._command_bay.get_global_rect().encloses(menus._recover_health.get_global_rect()),
		"Recovery button clipped"
	)
	if not label.begins_with("helix") or capture_prefix == "":
		return
	await RenderingServer.frame_post_draw
	var file = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Coverage capture exists")
	if not FileAccess.file_exists(file):
		root.get_texture().get_image().save_png(file)
