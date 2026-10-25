extends "res://tests/headless/UnitAnimationRegression.gd"

const OUTPUT = "res://art/vehicle-damage/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Vehicle damage preview needs a renderer")
		quit(1)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"living_world": false,
			"reduced_flashes": false
		}
	)
	Engine.max_fps = 60
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
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
		camera.rotation.y = .55
		camera.set_size_safely(14)
		camera.set_position_safely(Vector3(30, 0, 43))
		var subjects := []
		for row in 2:
			for column in 3:
				var role = "Tank" if row == 0 else "AntiAirVehicle"
				var unit = _spawn(role, 0, Vector3(25 + column * 5, 0, 40 + row * 5))
				unit.process_mode = Node.PROCESS_MODE_INHERIT
				unit.set_process(false)
				unit.set_physics_process(false)
				unit.get_node("Movement").set_physics_process(false)
				unit.hp = unit.hp_max * [1.0, .49, .24][column]
				unit.get_node("BastionVisuals").process_mode = Node.PROCESS_MODE_PAUSABLE
				unit.permanent_scrap_rank = column if faction == "frontier" else 0
				subjects.append(unit)
		var layer = CanvasLayer.new()
		var label = Label.new()
		label.text = (
			"%s  /  100%% HP   ·   49%% HP   ·   24%% HP%s"
			% [faction.to_upper(), "  /  Armor ranks 0 · 1 · 2" if faction == "frontier" else ""]
		)
		label.position = Vector2(30, 25)
		label.add_theme_font_size_override("font_size", 24)
		layer.add_child(label)
		_game.add_child(layer)
		await _frames(110)
		await _capture(faction + "-damage")
		camera.set_size_safely(5)
		camera.set_position_safely(subjects[2].global_position)
		await _frames(30)
		await _capture(faction + "-critical-detail")
		camera.set_size_safely(14)
		camera.set_position_safely(Vector3(30, 0, 43))
		for unit in subjects:
			unit.hp = unit.hp_max
		await _frames(120)
		label.text = faction.to_upper() + "  /  Repaired · permanent armor retained"
		await _capture(faction + "-repaired")
		await _close()
	options.restore(original)
	print("Vehicle damage preview: 9 captures")
	await root.get_node("Globals").quit_game()


func _capture(label):
	await _frames(3)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Could not save " + label)
