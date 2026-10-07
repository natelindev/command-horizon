extends "res://tests/headless/SupplyContestRegression.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _review_contest():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(5)
	game.hud._view_buttons[0].grab_focus()
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(2)
	var camera = game.get_node("IsometricCamera3D")
	var viewed = camera.get_ray_intersection(root.get_visible_rect().size / 2.0)
	_check(
		viewed != null and viewed.distance_to(game.map.POINTS[0]) < 0.1,
		"Contested checkpoint locator did not focus ground target"
	)
	var buttons = game.hud.find_children("*", "Button", true, false)
	var escorts = buttons.filter(func(button): return button.text == "Select escorts")[0]
	var point = root.get_final_transform() * escorts.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(2)
	_check(
		get_nodes_in_group("selected_units").size() == game.escorts().size(),
		"Contested checkpoint escort selector missed survivors"
	)
	print("CONTEST INPUT mouse=1 enter=1")
	await _capture("contested")


func _review_recovered():
	game.hud._toggle_pause()
	await _capture("cleared")


func _capture(label):
	root.size = Vector2i(1280, 720)
	await _frames(5)
	for row in game.hud._truck_labels:
		_check(
			game.hud.objective_panel.get_global_rect().encloses(row.get_global_rect()),
			"Convoy status escaped its panel"
		)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Convoy status overlaps minimap"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Contest preview resolution changed")
	var destination = (
		"res://docs/playtests/2026-10-07/supply-difficulties/contest-" + label + ".png"
	)
	_check(not FileAccess.file_exists(destination), "Contest preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
