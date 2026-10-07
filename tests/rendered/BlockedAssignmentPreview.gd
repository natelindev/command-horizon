extends "res://tests/headless/BlockedAssignmentRegression.gd"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _review_recovery(faction)
	preferences.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered blocked assignment: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_recovery(faction):
	var unit = await _open_capture(faction)
	unit.program.run()
	paused = false
	await _frames(720)
	_check(unit.program.mode == "Blocked", "Rendered guard did not block")
	paused = true
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(unit)
	var restore = Restore.new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Rendered blocked restore failed")
	if not result.ok:
		return
	game = result.game
	unit = restore.entities[id]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(23)
	camera.set_position_safely(unit.program.anchor + Vector3(3, 0, 3))
	await _frames(10)
	var panel = game.find_child("UnitMenus")._program_panel
	panel.refresh()
	_check(panel._reason.text.contains("friendly structure"), "Rendered reason lost obstruction")
	var overlay = Areas.new()
	_check(overlay._shows_guard_area(unit), "Rendered restored guard has no boundary")
	overlay.free()
	game.find_child("UnitMenus")._scroll.ensure_control_visible(panel._reason)
	await _capture(faction, "blocked")
	var buttons = panel.find_children("*", "Button", true, false)
	var assign = buttons.filter(func(button): return button.text == "Assign area / route")[0]
	var resume = buttons.filter(func(button): return button.text == "Resume")[0]
	var clock = game.simulation_time
	await _click_control(assign)
	_check(game.hud._assignment_kind == "anchor", "Assign area mouse click failed")
	var point = Vector3(47, 0, 26) if faction == "helix" else Vector3(25, 0, 38)
	await _click(root.get_final_transform() * camera.unproject_position(point))
	_check(unit.program.anchor.distance_to(point) < 0.2, "Map click failed to replace anchor")
	_check(unit.is_in_group("selected_units"), "Assignment release lost selected guard")
	await _click_control(resume)
	_check(unit.program.mode == "Ready", "Resume mouse click failed")
	_check(game.simulation_time == clock, "Paused reassignment advanced simulation")
	await _capture(faction, "ready")
	paused = false
	await _frames(600)
	_check(unit.program.mode == "Running", "Rendered guard failed to recover")
	_check(unit.position.distance_to(point) < 1.2, "Rendered guard missed clear point")
	paused = true
	game.find_child("UnitMenus")._scroll.ensure_control_visible(panel._reason)
	await _capture(faction, "recovered")
	print("CHECKED rendered ", faction, " input recovery at ", unit.position)
	game.queue_free()
	await _frames(5)


func _click_control(button):
	game.find_child("UnitMenus")._scroll.ensure_control_visible(button)
	await _frames(3)
	await _click(root.get_final_transform() * button.get_global_rect().get_center())


func _click(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, false)
	await _frames(3)


func _capture(faction, label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Blocked preview resolution changed")
	frame.save_png("res://art/skirmish/blocked-assignment-%s-%s.png" % [faction, label])
