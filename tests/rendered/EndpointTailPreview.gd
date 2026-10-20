extends "res://tests/headless/EndpointTailRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Endpoint preview timed out")
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
	await _open_capture()
	game.visible_player = watched.player
	await _review("before")
	await _arrival("captured")
	await _close()
	for faction in ["bastion", "helix"]:
		await _fresh(faction)
		game.visible_player = watched.player
		await _arrival("fresh-" + faction)
		await _close()
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered endpoint tail: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _arrival(label, require_path_bend = false):
	if game.hud._pause_owned:
		game.hud._toggle_pause()
	await super(label, require_path_bend)


func _review(label):
	var was_paused = paused
	if not was_paused:
		game.hud._toggle_pause()
	var clock = game.simulation_time
	# Diagnostic spectator view: expose the scene while keeping both sides'
	# gameplay observation and orders unchanged, including during paused load.
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(20)
	camera.set_position_safely(watched.position + Vector3(2, 0, 0))
	root.get_node("MatchSignals").deselect_all_units.emit()
	watched.get_node("Selection").select()
	await _frames(12)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Endpoint preview resolution changed")
	frame.save_png("res://art/skirmish/endpoint-tail-%s.png" % label)
	_check(game.simulation_time == clock, "Endpoint review advanced paused time")
	print("ENDPOINT CAPTURE ", label, " action=", watched.action)
	if not was_paused:
		game.hud._toggle_pause()
