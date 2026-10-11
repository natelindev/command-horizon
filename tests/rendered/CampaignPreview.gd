extends "res://tests/rendered/LuaEditorPreview.gd"


func _run():
	root.get_node("SaveManager").slots.directory = (
		"user://campaign-ui-saves-%d" % OS.get_process_id()
	)
	create_timer(180).timeout.connect(
		func():
			push_error("Campaign UI timed out")
			quit(1)
	)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(4)
	await _click(_button_named(menu, "02    CAMPAIGN"))
	await _frames(5)
	var campaign = current_scene
	_check(campaign.has_method("_start"), "Campaign entry did not open briefing")
	_check(campaign._start_button.get_global_rect().end.y <= 710, "Briefing clipped at 720p")
	await _click(campaign._operation_buttons[1])
	await _capture("campaign-briefing-720p")
	await _click(campaign._start_button)
	for frame in range(180):
		await process_frame
		if is_instance_valid(current_scene) and "phase" in current_scene:
			break
	_game = current_scene
	_check(_game.settings.mission_id == "first_orders", "Campaign loaded ordinary skirmish")
	_game.progress_path = "user://campaign-ui-progress-%d.json" % OS.get_process_id()
	var human = _game._get_human_player()
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	await _frames(35)
	await _capture("first-orders-start-720p")
	await _click(_game.hud._find_button)
	camera.set_position_safely(Vector3(26, 0, 8))
	await _frames(4)
	var build = _game.find_child("BuildCommandLab", true, false)
	await _click(build)
	await _world_click(camera.unproject_position(Vector3(26, 0, 8)))
	var labs = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandLab"
	)
	_check(labs.size() == 1, "Actual construction UI did not place the lab")
	if labs.is_empty():
		await _capture("first-orders-placement-failure")
		for message in _errors:
			push_error(message)
		quit(1)
		return
	var construction_started = _game.simulation_time
	while _game.phase == 0 and _game.simulation_time - construction_started < 75:
		await process_frame
	_check(_game.phase == 1, "Constructed lab did not unlock second lesson")
	await _click(_game.hud._find_button)
	camera.set_position_safely(Vector3(19, 0, 25))
	await _frames(5)
	var panel = _game.find_child("UnitMenus")._program_panel
	_check(is_instance_valid(panel), "Find repair robot did not expose programming")
	if not is_instance_valid(panel):
		for message in _errors:
			push_error(message)
		quit(1)
		return
	panel.library_path = "user://campaign-ui-program-%d.json" % OS.get_process_id()
	panel._preset.select(panel._preset_ids.find("hold_service"))
	panel._preset.item_selected.emit(panel._preset.selected)
	await _click(_button_named(panel, "Assign area / route"))
	await _world_click(camera.unproject_position(Vector3(19, 0, 26)))
	await _click(_button_named(panel, "Apply & run"))
	await _frames(40)
	_check(_game.phase == 2, "UI preset Apply did not advance mission")
	panel._retreat.value = 40
	panel._name.text = "First Orders support"
	await _click(_button_named(panel, "Save version"))
	panel._load_saved(1)
	await _click(_button_named(panel, "Apply & run"))
	await _frames(40)
	_check(_game.reuse_badge, "Saved threshold reuse was not recognized")
	var menus = _game.find_child("UnitMenus")
	_check(
		not _game.hud.lesson_panel.get_global_rect().intersects(menus.get_global_rect()),
		"Lesson covers program controls"
	)
	_check(_game.hud.lesson_panel.get_global_rect().end.y < 505, "Lesson covers minimap at 720p")
	await _capture("first-orders-program-720p")
	await _click(_button_named(_game.hud, "View relay"))
	await _frames(4)
	root.get_node("MatchSignals").deselect_all_units.emit()
	_check(
		(
			_game.hud._relay_marker.visible
			and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
				_game.hud._relay_marker.get_global_rect()
			)
		),
		"Public objective position is missing under fog"
	)
	await _capture("first-orders-relay-720p")
	_game.hud._open_menu()
	await _frames(3)
	_check(_button_named(_game.hud, "Campaign") != null, "Mission menu links to skirmish setup")
	_game.hud._close_menu()
	_game._finish("Victory")  # Full combat victory is exercised by CampaignRegression.
	await _frames(4)
	await _capture("first-orders-victory-720p")
	await _click(_button_named(_game.hud, "Play again"))
	await _frames(90)
	_game = current_scene
	_check(
		_game.settings.mission_id == "first_orders" and _game.phase == 0 and not paused,
		"Mission replay lost mission settings or retained its result"
	)
	_game._finish("Defeat")
	await _frames(4)
	await _capture("first-orders-defeat-720p")
	await _click(_button_named(_game.hud, "Campaign"))
	await _frames(8)
	_check(not paused and current_scene.has_method("_start"), "Campaign return left game paused")
	DirAccess.remove_absolute("user://campaign-ui-program-%d.json" % OS.get_process_id())
	DirAccess.remove_absolute("user://campaign-ui-progress-%d.json" % OS.get_process_id())
	var saves = root.get_node("SaveManager")
	saves.autosaves_enabled = false
	for file in DirAccess.get_files_at(saves.slots.directory):
		DirAccess.remove_absolute(saves.slots.directory.path_join(file))
	DirAccess.remove_absolute(saves.slots.directory)
	current_scene.queue_free()
	await _frames(4)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			"PASS: campaign entry/briefing, real build/assignment/preset/reuse input, 720p layout and return"
		)
	quit(0 if _errors.is_empty() else 1)


func _world_click(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(3)


func _click(button):
	await _frames(3)
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(3)
