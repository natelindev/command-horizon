extends "res://tests/headless/UnitAnimationRegression.gd"

const OUTPUT = "res://art/infantry-suppression/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Suppression preview requires a renderer")
		quit(1)
		return
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"living_world": false
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		_game.hud.hide()
		_game.hud.alert_panel.hide()
		_game.get_node("HUD").hide()
		_game.subtitles.hide()
		_game.fog_of_war.reveal()
		var camera = _game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.rotation.y = 0.35
		camera.set_size_safely(6)
		camera.set_position_safely(Vector3(32, 0, 40))
		for index in 3:
			var unit = _spawn("Infantry", 0, Vector3(29 + index * 3, 0, 40))
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			unit.set_physics_process(false)
			unit.get_node("Movement").set_physics_process(false)
			unit.action.process_mode = Node.PROCESS_MODE_DISABLED
			unit.suppression.add_pressure([0.0, 65.0, 100.0][index])
			unit.suppression.set_physics_process(false)
			unit.rotation.y = -0.5
		var layer = CanvasLayer.new()
		var label = Label.new()
		label.text = faction.to_upper() + "  /  Clear  ·  Suppressed  ·  Pinned"
		label.position = Vector2(30, 25)
		label.add_theme_font_size_override("font_size", 24)
		layer.add_child(label)
		_game.add_child(layer)
		await _frames(90)
		await RenderingServer.frame_post_draw
		_check(
			root.get_texture().get_image().save_png(OUTPUT + faction + ".png") == OK,
			"Suppression capture failed"
		)
		await _close()
	options.restore(original)
	print("Infantry suppression preview: 3 captures")
	await root.get_node("Globals").quit_game()
