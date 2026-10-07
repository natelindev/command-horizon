extends "res://tests/headless/BattleDebriefRegression.gd"

var capture_prefix = ""
var automated = false


func _run():
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg == "--automated":
			automated = true
		if arg.begins_with("--captures="):
			capture_prefix = arg.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _review_result(label):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(12)
	var panels = game.hud._overlay.find_children("*", "PanelContainer", true, false)
	_check(panels.size() == 1, "Debrief panel unavailable")
	for panel in panels:
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Debrief leaves viewport")
	var buttons = game.hud._overlay.find_children("*", "Button", true, false)
	_check(buttons.size() == 4, "Debrief lost result navigation")
	await RenderingServer.frame_post_draw
	var file = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Debrief capture exists")
	root.get_texture().get_image().save_png(file)
	if label == "frontier-legacy":
		print("NATIVE DEBRIEF: Play again focused; Tab twice then Enter to Skirmish setup")
		if automated:
			buttons[2].pressed.emit()
		var deadline = Time.get_ticks_msec() + 600000
		while (
			is_instance_valid(game) and game.is_inside_tree() and Time.get_ticks_msec() < deadline
		):
			await _frames(1)
		await _frames(12)
		_check(
			(
				is_instance_valid(current_scene)
				and current_scene.scene_file_path == "res://source/main-menu/Play.tscn"
			),
			"Native result did not return to Skirmish setup"
		)
