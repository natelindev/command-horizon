extends SceneTree

var _game
var _path
var _errors = []


func _initialize():
	call_deferred("_run")


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "helix" if side == 0 else "bastion"
		player.color = Color("38c8ce") if side == 0 else Color("e3ad48")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(18, 0, 20))
	await _frames(60)
	var human = _game._get_human_player()
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	for tank in tanks:
		_check(
			tank.program.installed and tank.program.ready_to_run(),
			"Advanced tank missing active chip"
		)
		tank.get_node("Selection").select()
	await _frames(3)
	var menu = _game.find_child("UnitMenus")
	var panel = menu._program_panel
	_path = "user://program-ui-test-%d.json" % OS.get_process_id()
	panel.library_path = _path
	panel._preset.select(1)
	panel._retreat.value = 35
	panel._name.text = "Perimeter guard"
	panel._save()
	_check(panel._library.versions.size() == 1, "UI failed to save preset")
	panel._load_saved(1)
	_game.hud._toggle_pause()
	panel._assign_area()
	var point = Vector3(22, 0, 22)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = camera.unproject_position(point)
	event.pressed = true
	_game.hud._unhandled_input(event)
	event.pressed = false
	_game.hud._unhandled_input(event)
	_check(tanks[0].program.anchor.distance_to(point) < 0.1, "Map assignment missed click position")
	_check(tanks[0].is_in_group("selected_units"), "Assignment deselected units")
	panel._arm("safe")
	_game.hud.accept_program_assignment(Vector3(10, 0, 18), null)
	panel._run.pressed.emit()
	var time = _game.simulation_time
	await _frames(12)
	_check(
		_game.simulation_time == time and tanks[0].program.mode == "Ready",
		"Paused edit advanced program"
	)
	await _capture("program-paused")
	_game.hud._toggle_pause()
	await _frames(120)
	_check(tanks[0].program.mode == "Running", "Run button did not activate program")
	_check(
		tanks[0].program.saved_record == panel._library.versions[0],
		"Applying a loaded preset lost its exact saved record"
	)
	panel._retreat.value = 40
	panel._apply()
	_check(
		tanks[0].program.saved_record.is_empty(), "Edited preset retained stale version identity"
	)
	panel._load_saved(1)
	panel._apply()
	await _capture("program-running")
	# A real human terrain command must suspend the assigned program.
	root.get_node("MatchSignals").terrain_targeted.emit(Vector3(16, 0, 23))
	await _frames(30)
	_check(tanks[0].program.mode == "Manual", "Right-click command lost authority")
	await _capture("program-manual")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _frames(10)
	await _capture("program-720p")
	_check(menu.get_global_rect().position.y >= 0, "Program panel exceeds 720p height")
	_check(menu.get_global_rect().end.x <= 1280, "Program panel exceeds 720p width")
	panel._resume()
	await _frames(20)
	_check(tanks[0].program.mode == "Running", "Resume button failed")
	# Air collision layer must be pickable for escort assignments and paused selection.
	var drone = load("res://source/match/units/Drone.tscn").instantiate()
	_game._setup_and_spawn_unit(drone, Transform3D(Basis(), Vector3(8, 0, 25)), human, false)
	await _frames(30)
	var air_point = camera.unproject_position(drone.global_position + Vector3.UP * 0.25)
	_check(_game.hud._pick_unit(air_point) == drone, "Aircraft excluded from world picking")
	_game.hud.arm_program_assignment("escort", tanks)
	event.position = air_point
	event.pressed = true
	_game.hud._unhandled_input(event)
	event.pressed = false
	_game.hud._unhandled_input(event)
	_check(tanks[0].program.escort == drone, "Aircraft escort assignment failed")
	_game.hud._selection_start = air_point
	paused = true
	_game.hud._select_while_paused(air_point)
	_check(drone.is_in_group("selected_units"), "Paused aircraft selection failed")
	paused = false
	root.get_node("MatchSignals").deselect_all_units.emit()
	var factories = human.get_children().filter(
		func(node): return "type" in node and node.type == "VehicleFactory"
	)
	var factory = factories[0]
	factory.get_node("Selection").select()
	await _frames(3)
	factory.production_queue.program_library_path = _path
	menu._factory_program_panel.reload_library()
	menu._factory_program_panel._options.select(1)
	menu._factory_program_panel._select(1)
	menu._chip_option.button_pressed = true
	menu.find_child("ProduceTank", true, false).pressed.emit()
	await _frames(3)
	var job = factory.production_queue.get_elements()[0]
	_check(job.fitted_chip and job.paid_cost.resource_b == 14, "Factory chip toggle failed")
	_check(job.program_snapshot.title == "Perimeter guard · v1", "Factory dropdown missed version")
	await _capture("program-factory")
	menu._chip_option.button_pressed = false
	_check(job.fitted_chip, "Changing factory toggle mutated an existing job")
	_check(
		"22 M · 10 E" in menu.find_child("ProduceTank", true, false).text,
		"Chip toggle left stale unit price"
	)
	factory.production_queue.cancel(job)
	root.get_node("MatchSignals").deselect_all_units.emit()
	var labs = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandLab"
	)
	labs[0].get_node("Selection").select()
	await _frames(3)
	menu._research_panel._start.pressed.emit()
	await _frames(60)
	_check(human.coordination_left > 0, "Research button did not start timer")
	await _capture("coordination-research-720p")
	_check(menu.get_global_rect().position.y >= 0, "Research panel exceeds 720p height")
	menu._research_panel._cancel.pressed.emit()
	_check(human.coordination_left < 0, "Research cancel button failed")
	DirAccess.remove_absolute(_path)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: rendered advanced Helix chips; save/load version; map assignment; "
				+ "paused Apply; manual override/resume; 1440x900 and 1280x720 layout"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _capture(title):
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)


func _frames(count):
	for frame in range(count):
		await process_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
