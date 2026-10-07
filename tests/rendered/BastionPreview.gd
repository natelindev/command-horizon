extends SceneTree

var _game = null


func _initialize():
	call_deferred("_run")


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("FeatureFlags").handle_match_end = false
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var buttons = menu.find_child("VBoxContainer").get_children()
	assert(buttons[0].text == "SKIRMISH")
	buttons.filter(func(button): return button.text == "BASTION DEMO")[0].pressed.emit()
	await process_frame
	await process_frame
	_game = current_scene
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(27)
	camera.set_position_safely(Vector3(16, 0, 17))
	await _frames(90)
	var human = _game._get_human_player()
	var units = human.get_children().filter(func(node): return "type" in node)
	var factory = units.filter(func(node): return node.type == "VehicleFactory")[0]
	factory.get_node("Selection").select()
	factory.production_queue.produce(load("res://source/match/units/CombatRobot.tscn"))
	await _capture("factory")
	root.get_node("MatchSignals").deselect_all_units.emit()
	var worker = units.filter(func(node): return node.type == "Worker")[0]
	worker.get_node("Selection").select()
	await _capture("construction")
	root.get_node("MatchSignals").deselect_all_units.emit()
	var hud_script = load("res://source/match/hud/BastionDemoHUD.gd")
	var hud = _game.get_children().filter(func(node): return node.get_script() == hud_script)[0]
	hud._toggle_pause()
	var tank = units.filter(func(node): return node.type == "Tank")[0]
	var point = camera.unproject_position(tank.global_position + Vector3.UP * 0.5)
	hud._selection_start = point
	hud._select_while_paused(point)
	assert(tank.is_in_group("selected_units"), "Paused picking failed")
	var target_position = camera.unproject_position(Vector3(27, 0, 22))
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = target_position
	hud._unhandled_input(event)
	var start = tank.global_position
	await _frames(30)
	assert(tank.global_position.is_equal_approx(start), "Paused order moved a unit")
	hud._toggle_pause()
	await _frames(90)
	assert(tank.global_position.distance_to(start) > 0.5, "Paused move did not execute on resume")
	await _capture("battlefield")
	_game.queue_free()
	await _frames(5)
	print(
		"PASS: main-menu entry, rendered production/construction UI, paused picking and move orders"
	)
	quit()


func _capture(label):
	await _frames(4)
	await RenderingServer.frame_post_draw
	var screenshot = root.get_texture().get_image()
	screenshot.resize(1440, 900)
	var directory = "res://art/bastion/demo/gameplay"
	DirAccess.make_dir_recursive_absolute(directory)
	screenshot.save_png(directory + "/" + label + ".png")


func _frames(count):
	for _index in range(count):
		await physics_frame
