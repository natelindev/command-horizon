extends "res://tests/headless/SupportDiscoveryRegression.gd"

var captures = ""
var automated = false


func _run():
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg == "--automated":
			automated = true
		if arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _layout():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(12)
	var panel = game.hud.battle_plan
	var minimap = game.get_node("HUD/MarginContainer/Minimap")
	_check(
		root.get_visible_rect().encloses(panel.get_global_rect()), "Support panel leaves viewport"
	)
	_check(
		not panel.get_global_rect().intersects(minimap.get_global_rect()),
		"Support panel covers minimap"
	)
	var button = _support_button()
	if button.visible:
		_check(
			panel.get_global_rect().encloses(button.get_global_rect()),
			"Support button leaves panel"
		)
		_check(button.get_minimum_size().x <= 324, "Support label widens the panel")


func _activate_support(button, label):
	await _layout()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture(label + "-before")
	if label == "frontier":
		button.grab_focus()
	print("NATIVE SUPPORT: activate ", label, " ", button.get_global_rect())
	var deadline = Time.get_ticks_msec() + 180000
	if automated:
		button.pressed.emit()
	while get_nodes_in_group("selected_units").is_empty() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(
		not get_nodes_in_group("selected_units").is_empty(), "Native support activation timed out"
	)
	await _frames(12)
	await _capture(label + "-selected")


func _review_support(label):
	await _layout()
	await _capture(label)


func _capture(label):
	if captures == "":
		return
	await RenderingServer.frame_post_draw
	var path = captures + "-" + label + ".png"
	_check(not FileAccess.file_exists(path), "Support capture already exists")
	if not FileAccess.file_exists(path):
		root.get_texture().get_image().save_png(path)
