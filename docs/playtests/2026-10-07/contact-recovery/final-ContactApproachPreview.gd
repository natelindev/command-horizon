extends "res://tests/headless/ContactApproachRegression.gd"

var captures = "res://art/skirmish/contact-approach"


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(CONTACT_ARCHIVE))
	_check(loaded.ok, "Rendered contact archive failed to load")
	if loaded.ok:
		game = loaded.game
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		var worker = restore.entities["unit-0"]
		var deposit = restore.entities["resource-2"]
		var stock = deposit.resource_a
		await _capture_contact(worker, "before")
		game.hud._toggle_pause()
		await _frames(240)
		await _capture_contact(worker, "detour")
		game.hud._toggle_pause()
		await _frames(360)
		_check(
			worker.resource_a == 4 and stock - deposit.resource_a == 1,
			"Rendered recovery failed actual conserved collection"
		)
		await _capture_contact(worker, "collected")
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered contact approach: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture_contact(worker, label):
	game.hud.pause_after_load()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(20)
	camera.set_position_safely(Vector3(20, 0, 34))
	root.get_node("MatchSignals").deselect_all_units.emit()
	worker.get_node("Selection").select()
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Contact review resolution changed")
	frame.save_png("%s-%s.png" % [captures, label])
	print("CONTACT CAPTURE ", label, " at ", game.simulation_time)
