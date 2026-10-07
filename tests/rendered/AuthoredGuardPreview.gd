extends "res://tests/headless/AuthoredGuardRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Authored guard preview timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await super()
	options.restore(original)


func _review(label):
	game.hud._toggle_pause()
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	guard.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(anchor + Vector3(5, 0, 0))
	await _frames(10)
	var overlay = load("res://source/match/hud/ProgramAssignments.gd").new()
	_check(overlay._shows_guard_area(guard), "Selected authored guard has no area boundary")
	overlay.free()
	var panel = game.find_child("UnitMenus")._program_panel
	_check(panel != null, "Authored guard has no controls")
	if panel != null:
		panel.refresh()
		_check(panel._radius.value == 6, "Authored guard shows wrong area radius")
		_check(panel._status.text.contains("Running"), "Authored guard lost running status")
	if not root.can_draw():
		root.grab_focus()
		for frame in 120:
			await process_frame
			if root.can_draw():
				break
	if not root.can_draw():
		_check(false, "Authored guard capture window is not drawable")
		game.hud._toggle_pause()
		return
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Authored guard capture resolution changed")
	frame.save_png(
		(
			"res://art/skirmish/authored-guard-%s-%s-%s.png"
			% [guard.player.faction, active_mode, label]
		)
	)
	_check(game.simulation_time == clock, "Capture advanced paused simulation")
	print("AUTHORED GUARD CAPTURE ", guard.player.faction, " ", active_mode, " ", label)
	game.hud._toggle_pause()
