extends "res://tests/headless/LowHealthSelectionRegression.gd"

var original_options = {}
var automated = false


func _run():
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg == "--automated":
			automated = true
		if arg.begins_with("--captures="):
			capture_prefix = arg.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original_options)


func _layout():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(12)
	var panel = game.hud.battle_plan
	var minimap = game.get_node("HUD/MarginContainer/Minimap")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Battle plan leaves viewport")
	_check(
		not panel.get_global_rect().intersects(minimap.get_global_rect()),
		"Battle plan covers minimap"
	)
	for control in [panel._idle, panel._army, panel._damaged]:
		if control.visible:
			_check(
				panel.get_global_rect().encloses(control.get_global_rect()), "Shortcut leaves panel"
			)


func _activate(button, label):
	await _layout()
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _capture(label + "-before")
	var deadline = Time.get_ticks_msec() + 180000
	if label == "frontier":
		button.grab_focus()
	print("NATIVE LOW HEALTH: activate ", label, " ", button.get_global_rect())
	if automated:
		button.pressed.emit()
	while get_nodes_in_group("selected_units").is_empty() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(
		not get_nodes_in_group("selected_units").is_empty(), "Native low-health selection timed out"
	)
	await _frames(12)
	await _capture(label + "-activated")


func _review(label):
	await _layout()
	await _capture(label)


func _capture(label):
	if capture_prefix == "":
		return
	await RenderingServer.frame_post_draw
	var menus = game.find_child("UnitMenus")
	if menus.visible:
		var clip = menus._scroll.get_global_rect()
		if menus._scroll.get_v_scroll_bar().visible:
			clip.size.x -= menus._scroll.get_v_scroll_bar().size.x
		for kind in menus._command_buttons:
			var button = menus._command_buttons[kind]
			if button.visible:
				print(
					"COHORT WIDTH ", label, " ", kind, " ", button.get_global_rect(), " clip=", clip
				)
				_check(
					button.get_global_rect().end.x <= clip.end.x + 1, label + ": clipped " + kind
				)
	var file = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Low-health capture exists")
	if not FileAccess.file_exists(file):
		root.get_texture().get_image().save_png(file)
