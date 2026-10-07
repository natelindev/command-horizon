extends SceneTree

var _game = null
var _stage = "starting"


func _initialize():
	create_timer(120).timeout.connect(
		func():
			push_error("Skirmish preview timed out at " + _stage)
			quit(1)
	)
	call_deferred("_run")


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.find_child("VBoxContainer").get_child(0).pressed.emit()
	await _frames(5)
	var setup = current_scene
	setup._player_faction.select(1)
	setup._enemy_faction.select(0)
	setup._start_mode.select(1)
	setup._map_list.select(0)
	setup._on_map_list_item_selected(0)
	setup._update_faction(0, 1)
	setup._update_faction(1, 0)
	setup._update_summary()
	await _capture("setup")
	setup._start_button.pressed.emit()
	await _frames(120)
	_game = current_scene
	assert(_game.settings.skirmish)
	var human = _game._get_human_player()
	assert(human.faction == "helix")
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(17, 0, 19))
	var units = human.get_children().filter(func(node): return "type" in node)
	var factory = units.filter(func(node): return node.type == "VehicleFactory")[0]
	factory.get_node("Selection").select()
	factory.production_queue.produce(load("res://source/match/units/CombatRobot.tscn"))
	await _capture("helix-factory")
	root.get_node("MatchSignals").deselect_all_units.emit()
	var worker = units.filter(func(node): return node.type == "Worker")[0]
	worker.get_node("Selection").select()
	await _capture("helix-construction")
	var placement = human.get_node("StructurePlacementHandler")
	placement._start_structure_placement(load("res://source/match/units/PowerPlant.tscn"))
	placement._active_blueprint_node.position = Vector3(5, 0, 5)
	var placement_event = InputEventMouseButton.new()
	placement_event.position = camera.unproject_position(Vector3(23, 0, 28))
	placement._handle_lmb_down_event(placement_event)
	assert(
		placement._active_blueprint_node.position.distance_to(Vector3(23, 0, 28)) < 0.1,
		"Placement used stale mouse coordinates"
	)
	placement._finish_blueprint_rotation()
	placement._cancel_structure_placement()
	root.get_node("MatchSignals").deselect_all_units.emit()
	var tank = units.filter(func(node): return node.type == "Tank")[0]
	tank.get_node("Selection").select()
	_game.hud._toggle_pause()
	_game.hud._arm_attack()
	var point = camera.unproject_position(Vector3(25, 0, 21))
	var event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_game.hud._unhandled_input(event)
	event.pressed = false
	_game.hud._unhandled_input(event)
	assert(tank.is_in_group("selected_units"), "Attack move deselected units")
	assert(tank.action != null, "No attack move order")
	var start = tank.global_position
	await _frames(10)
	assert(tank.global_position.is_equal_approx(start), "Movement during pause")
	_game.hud._toggle_pause()
	await _frames(120)
	assert(tank.global_position.distance_to(start) > 0.5, "Attack move failed to resume")
	_game.hud._open_menu()
	await _capture("pause-menu")
	_game.hud._close_menu()
	_game.hud.show_result("Victory")
	await _capture("result")
	_stage = "returning to setup"
	_game.hud._back_to_setup()
	await _frames(10)
	_stage = "resizing setup"
	assert(not paused and current_scene.has_method("_create_match_settings"))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await _capture("setup-1280")
	current_scene.queue_free()
	await _frames(5)
	print(
		"PASS: rendered menu/setup/Helix production/construction, paused attack move, result and return"
	)
	quit()


func _capture(label):
	_stage = "capturing " + label
	await _frames(8)
	await RenderingServer.frame_post_draw
	var path = "res://art/skirmish/" + label + ".png"
	DirAccess.make_dir_recursive_absolute("res://art/skirmish")
	root.get_texture().get_image().save_png(path)


func _frames(count):
	for _index in range(count):
		await process_frame
