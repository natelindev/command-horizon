extends "res://tests/playtest/HorizonDeploymentRecovery.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await super()
	options.restore(original)


func _review_restored():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(10)
	var before = game.simulation_time
	var buttons = game.hud.find_children("*", "Button", true, false)
	var deployment = buttons.filter(func(button): return button.text == "Deployment")[0]
	deployment.grab_focus()
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
		viewed != null and viewed.distance_to(game.map.DEPLOYMENT) < 0.1,
		"Keyboard deployment locator did not focus recovery"
	)
	var infantry = buttons.filter(func(button): return button.text == "Infantry")[0]
	var point = root.get_final_transform() * infantry.get_global_rect().get_center()
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
		(
			get_nodes_in_group("selected_units").size()
			== _units(game._get_human_player(), "Infantry").size()
		),
		"Mouse infantry selection missed recovery survivors"
	)
	_check(paused and game.simulation_time == before, "Recovery inspection advanced time")
	_check(
		game.hud._objective.text == "Command destroyed · retake deployment with infantry",
		"Restored recovery objective not visible"
	)
	_check(
		game.hud.get_child(0).get_global_rect().encloses(game.hud._objective.get_global_rect()),
		"Recovery objective escaped command panel"
	)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Recovery objective panel overlaps minimap"
	)
	print("HORIZON RECOVERY INPUT mouse=1 enter=1")
	await _capture("paused")


func _review_finished():
	_check(
		game.objective_text() == "Command destroyed · deployment secured",
		"Rendered victory still asks for recovery"
	)
	await _capture("result")


func _capture(label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Recovery preview resolution changed")
	var destination = evidence_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Recovery preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
