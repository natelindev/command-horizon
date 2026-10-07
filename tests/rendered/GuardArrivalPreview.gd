extends "res://tests/headless/GuardArrivalRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Guard arrival preview timed out")
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
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _group_case(faction, "preset")
		await _group_case(faction, "visual")
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered guard arrival: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_group(group, label):
	game.hud._toggle_pause()
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in group:
		unit.get_node("Selection").select()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(26)
	camera.set_position_safely(group[0].program.anchor + Vector3(4, 0, 0))
	await _frames(12)
	_check(get_nodes_in_group("selected_units").size() == 8, "Formation selection lost guards")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Guard arrival resolution changed")
	frame.save_png("res://art/skirmish/guard-arrival-%s-%s.png" % [group[0].player.faction, label])
	_check(game.simulation_time == clock, "Guard review advanced paused simulation")
	print("GUARD ARRIVAL CAPTURE ", group[0].player.faction, " ", label)
	game.hud._toggle_pause()
