extends "res://tests/rendered/PreviewFixture.gd"

var _deadline = 0


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 90000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Skirmish loop UI timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for faction in ["bastion", "helix"]:
		await _start_loop(faction, false)
		var human = _game._get_human_player()
		var engineers = human.get_children().filter(
			func(unit): return "type" in unit and unit.type == "Worker"
		)
		for engineer in engineers:
			engineer.get_node("Selection").select()
		await _frames(4)
		_check(
			get_nodes_in_group("selected_units").size() == engineers.size(),
			"Opening engineers were not selected"
		)
		var worker = engineers[0]
		_check(worker.action == null, "Selecting engineers issued an order")
		await _capture("loop-%s-economy-720p" % faction)
		var camera = _game.get_node("IsometricCamera3D")
		var materials = get_nodes_in_group("resource_units").filter(
			func(unit): return "resource_a" in unit
		)
		var deposit = materials[0]
		camera.set_position_safely(deposit.global_position)
		await _frames(4)
		await _right_click(camera.unproject_position(deposit.global_position + Vector3.UP * 0.5))
		await _frames(20)
		_check(worker.action != null, "World right-click failed to start harvesting")
		_game.hud._toggle_pause()
		var time = _game.simulation_time
		await _frames(8)
		_check(_game.simulation_time == time, "Tactical pause advanced the battle")
		_game.hud._toggle_pause()
		_game.queue_free()
		await _frames(6)
		await _start_loop(faction, true)
		# Assign the opening economy through ordinary orders.
		human = _game._get_human_player()
		engineers = human.get_children().filter(
			func(unit): return "type" in unit and unit.type == "Worker"
		)
		deposit = get_nodes_in_group("resource_units")[0]
		engineers[0].issue_manual_order(
			load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
		)
		await _frames(4)
		await _capture("loop-%s-advanced-720p" % faction)
		_game.queue_free()
		await _frames(6)
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Skirmish loop UI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _start_loop(faction, advanced):
	var setup = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(setup)
	setup._player_faction.select(0 if faction == "bastion" else 1)
	setup._enemy_faction.select(1 if faction == "bastion" else 0)
	setup._start_mode.select(1 if advanced else 0)
	setup._map_list.select(0)
	var settings = setup._create_match_settings()
	setup.queue_free()
	await _frames(2)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(45)


func _right_click(point):
	await _mouse_click(point, MOUSE_BUTTON_RIGHT)


func _mouse_click(point, button):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(4)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)
