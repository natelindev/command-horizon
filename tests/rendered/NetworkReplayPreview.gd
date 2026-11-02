extends "res://tests/headless/ReplayPlaybackRegression.gd"

const OUTPUT = "res://art/network-platform/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Replay review requires a renderer")
		quit(1)
		return
	var logger = RuntimeErrors.new()
	OS.add_logger(logger)
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var recording = _recording_path()
	for language in ["en", "zh_CN"]:
		options.restore(
			{
				"screen": 1,
				"interface_scale": 1.5,
				"language": language,
				"edge_scrolling": false,
				"day_cycle": false
			}
		)
		await create_timer(.5).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var playback = load("res://source/match/network/ReplayPlayback.gd").new()
		root.add_child(playback)
		_check(await playback.open(recording), "Replay could not open: " + playback.error)
		playback.playing = false
		var mounted = _mounted_checkpoint(playback)
		_check(not mounted.is_empty(), "Recording has no mounted checkpoint")
		if not mounted.is_empty():
			playback.seek(mounted.tick)
			var rig = playback.replica.entities[mounted.rig]
			var rider = playback.replica.entities[mounted.rider]
			var camera = playback.game.get_node("IsometricCamera3D")
			camera.set_size_safely(10.0)
			camera.set_position_safely(rig.global_position)
			rig.get_node("Selection").select()
			await _frames(12)
			_check(
				not rider.visible and not rider.get_node("Geometry").is_visible_in_tree(),
				"Rendered replay exposed mounted infantry"
			)
			await _capture(language + "-replay-mounted")
			playback.seek(playback.duration)
			await _frames(12)
			_check(
				rider.visible and not rider.has_meta("garrison_host"),
				"Rendered replay unload body missing"
			)
			await _capture(language + "-replay-unloaded")
		playback.shutdown()
		playback.game.queue_free()
		playback.queue_free()
		await _frames(8)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Rendered native replay mounted/unloaded EN/ZH: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _frames(count):
	for index in count:
		await process_frame


func _capture(filename):
	await _window()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + filename + ".png")


func _window():
	var deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await _frames(4)
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().get_size() == Vector2i(1280, 720):
			return
	_check(false, "720p native window did not settle")
