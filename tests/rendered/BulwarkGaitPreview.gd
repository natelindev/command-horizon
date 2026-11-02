extends "res://tests/headless/UnitAnimationRegression.gd"

const OUTPUT = "res://art/bulwark-gait/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Bulwark gait preview requires a renderer")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion", "PlainAndSimple")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await _frames(5)
	_game.hud.visible = false
	_game.get_node("HUD").visible = false
	var walker = _spawn("CombatRobot", 0, Vector3(42, 0, 25))
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_size_safely(5.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for phase in 4:
		_drive(walker, Vector3.FORWARD * 1.7, 15)
		camera.set_position_safely(walker.global_position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + "bulwark-stride-%d.png" % phase)
	await _close()
	print("Bulwark articulated stride rendered review: 0 failures")
	await root.get_node("Globals").quit_game(0)
