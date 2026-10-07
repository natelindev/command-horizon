extends "res://tests/rendered/TechnologyPreview.gd"

var archive_path = ""
var capture_prefix = ""
var preview_deadline = 0
var interactive = false


func _initialize():
	preview_deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > preview_deadline:
		push_error("Paid progression preview timed out")
		quit(1)
	return false


func _run():
	Engine.max_fps = 60
	interactive = "--interactive" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive_path = argument.trim_prefix("--archive=")
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if archive_path == "" or capture_prefix == "":
		push_error("Supply --archive=<earned technology save> and --captures=<new image prefix>")
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	var archive = FileStore.new().read_file(archive_path)
	var result = await Restore.new().restore(self, archive)
	_check(result.ok, "Earned technology archive failed to restore: " + result.get("error", ""))
	if result.ok:
		game = result.game
		human = game._get_human_player()
		lab = _units(human, "CommandLab")[0]
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await _earned_interface()
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Paid progression native: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _earned_interface():
	_check(paused and human.coordination_unlocked, "Archive lacks earned Coordination")
	_check(human.technology.active == "weapons_1", "Archive lacks paid Weapon systems I")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(25)
	camera.set_position_safely(lab.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	lab.get_node("Selection").select()
	await _frames(10)
	await _capture("lab")
	var clock = game.simulation_time
	var left = human.technology.left
	var funds = Vector2i(human.resource_a, human.resource_b)
	if interactive:
		await _wait_input(func(): return is_instance_valid(game.hud.technology_panel), "open Tech")
	else:
		await _click(game.hud._technology_button)
	_check(is_instance_valid(game.hud.technology_panel), "Tech button did not open earned research")
	await _capture("research")
	_check(
		game.simulation_time == clock and human.technology.left == left,
		"Research overlay advanced paused simulation"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds,
		"Opening earned research charged resources"
	)
	if interactive:
		await _wait_input(
			func(): return game.hud.technology_panel == null, "close Tech with Escape"
		)
	else:
		await _escape()
	_check(paused and game.hud.technology_panel == null, "Closing research lost prior pause")
	game.hud._toggle_pause()
	await create_timer(2.0).timeout
	game.hud._toggle_pause()
	_check(
		human.technology.left < left and human.technology.left > 0,
		"Paid research did not advance at normal clock"
	)
	var elapsed = game.simulation_time - clock
	_check(absf(elapsed - 2.0) < .2, "Native research clock differs from real-time interval")
	print(
		"EARNED RESEARCH active=",
		human.technology.active,
		" elapsed=",
		elapsed,
		" left=",
		human.technology.left
	)
	var candidates = _units(human, "Tank").filter(
		func(unit): return human.signatures.eligible(unit)
	)
	_check(not candidates.is_empty(), "Earned archive has no ready fitted armor")
	if candidates.is_empty():
		return
	tank = candidates[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	tank.get_node("Selection").select()
	camera.set_position_safely(tank.position)
	await _frames(10)
	var menus = game.find_child("UnitMenus")
	var panel = menus._signature_panel
	_check(is_instance_valid(panel), "Earned fitted armor omitted signature controls")
	if not is_instance_valid(panel):
		return
	var action = tank.action
	funds = Vector2i(human.resource_a, human.resource_b)
	if interactive:
		await _wait_input(
			func(): return tank.signature.kind == "maneuver", "activate Maneuver Burst"
		)
	else:
		await _click(panel._activate)
	_check(tank.signature.kind == "maneuver", "Earned Maneuver Burst button did not activate")
	_check(tank.action == action, "Maneuver Burst replaced the existing army order")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds, "Signature activation changed funds"
	)
	await _capture("maneuver")
	var point = tank.position
	var window = tank.signature.window_left
	game.hud._toggle_pause()
	await create_timer(1.0).timeout
	game.hud._toggle_pause()
	_check(tank.signature.window_left < window, "Maneuver window did not advance")
	print(
		"EARNED MANEUVER moved=",
		tank.position.distance_to(point),
		" window=",
		tank.signature.window_left
	)
	await _capture("maneuver-live")


func _wait_input(condition, label):
	print("NATIVE INPUT ", label)
	var limit = Time.get_ticks_msec() + 60000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await _frames(1)
	_check(condition.call(), "Native input did not complete: " + label)


func _capture(label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Paid progression preview resolution changed")
	var destination = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Native evidence path already exists")
	if not FileAccess.file_exists(destination):
		_check(frame.save_png(destination) == OK, "Cannot save native progression evidence")
	print("PAID PROGRESSION CAPTURE ", destination)
