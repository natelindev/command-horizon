extends "res://tests/headless/AirEnvironmentRegression.gd"


func _run():
	Engine.max_fps = 60
	path = "user://quarry-raised-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await _make_match()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	for unit in game._enemy.get_children():
		if unit.is_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var scout = _units(game._get_human_player(), "Drone")[0]
	scout.position = Vector3(48, scout.position.y, 51)
	scout.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(84, 0, 51))
	)
	var start = game.simulation_time
	while scout.position.x < 65.7 and game.simulation_time - start < 12:
		await physics_frame
	_check(
		absf(scout.position.x - 66) < 1 and scout.position.y > 4,
		"Visible crossing missed raised aircraft"
	)
	game.hud._toggle_pause()
	game.get_node("IsometricCamera3D").set_position_safely(Vector3(66, 0, 51))
	scout.get_node("Selection").select()
	await _capture("crossing")
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(game)
	var id = snapshot._reference(scout)
	var position = scout.position
	var archive = load("res://source/match/saves/SaveFile.gd").new()
	_check(archive.write_file(EVIDENCE + "rendered-flight.json", data), archive.error)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, archive.read_file(EVIDENCE + "rendered-flight.json"))
	_check(loaded.ok, "Rendered altitude archive failed")
	if loaded.ok:
		game = loaded.game
		game.progress_path = path
		scout = restore.entities[id]
		game.get_node("IsometricCamera3D").set_physics_process(false)
		_check(scout.position == position and paused, "Rendered archive moved raised aircraft")
		scout.get_node("Selection").select()
		await _capture("loaded")
		game.hud._toggle_pause()
		start = game.simulation_time
		while scout.position.x < 83 and game.simulation_time - start < 12:
			await physics_frame
		_check(scout.position.x >= 83, "Loaded rendered crossing did not finish")
		print("RENDERED QUARRY ALTITUDE ", position.y, " resumed=", scout.position)
	await _close()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Quarry flight preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(label):
	root.size = Vector2i(1280, 720)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Raised aircraft capture dimensions changed")
	var file = EVIDENCE + "raised-" + label + ".png"
	_check(not FileAccess.file_exists(file), "Raised capture would overwrite evidence")
	if not FileAccess.file_exists(file):
		frame.save_png(file)
