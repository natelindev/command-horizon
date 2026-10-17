extends "res://tests/headless/CargoReturnRegression.gd"

const OUTPUT = "res://art/worker-cargo/"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "day_cycle": false, "weather": 1, "language": "en"})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for faction in ["bastion", "helix", "frontier"]:
		if not OS.get_cmdline_user_args().is_empty() and faction not in OS.get_cmdline_user_args():
			continue
		await _cargo_fixture(faction)
		for unit in get_nodes_in_group("units"):
			unit.hide()
		root.get_node("MatchSignals").deselect_all_units.emit()
		game.hud.hide()
		game.subtitles.hide()
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		var loads = [
			[0, 0, "Empty"],
			[1, 0, "1 material"],
			[4, 0, "4 materials"],
			[0, 4, "4 electronics"],
			[2, 2, "Mixed cargo"]
		]
		for index in loads.size():
			var worker = load("res://source/match/units/Worker.tscn").instantiate()
			game._setup_and_spawn_unit(
				worker, Transform3D(Basis(), Vector3(35 + index * 2.4, 0, 35)), owner, false
			)
			worker.resource_a = loads[index][0]
			worker.resource_b = loads[index][1]
			var caption = Label3D.new()
			caption.text = loads[index][2]
			caption.position = Vector3(35 + index * 2.4, 2, 35)
			caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			caption.font_size = 36
			caption.pixel_size = .008
			game.add_child(caption)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(12)
		camera.set_position_safely(Vector3(39.8, 0, 35))
		await _frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + faction + ".png")
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Worker cargo preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
