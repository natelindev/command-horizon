extends "res://tests/headless/UnitAnimationRegression.gd"

const OUTPUT = "res://art/commander-support/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Commander support preview requires a renderer")
		quit(1)
		return
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		var support = _game.commander_support
		support.set_physics_process(false)
		var owner = _players[0]
		owner.resource_a = 1000
		owner.resource_b = 1000
		_spawn("CommandLab", 0, Vector3(16, 0, 16))
		_spawn("PowerPlant", 0, Vector3(23, 0, 16))
		var point = Vector3(40, 0, 40)
		var camera = _game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(23)
		camera.set_position_safely(point)
		_game.fog_of_war.reveal()
		var tank = _spawn("Tank", 0, point + Vector3(-9, 0, 5))
		tank.get_node("Selection").select()
		if faction != "frontier":
			_spawn("Tank", 1, point + Vector3(-2, 0, 0))
			_spawn("AntiGroundTurret", 1, point + Vector3(2, 0, 1))
		support.state(owner).started = true
		support.state(owner).left = 0.0
		_game.find_child("UnitMenus").open_commander()
		_check(support.activate(owner, point), faction + " call-in preview rejected")
		support._refresh_markers()
		await _capture(faction + "-warning")
		if faction == "frontier":
			support._physics_process(5.5)
			await _capture(faction + "-descent")
			support._physics_process(1.5)
		else:
			support._physics_process(3.55 if faction == "bastion" else 2.55)
		await _capture(faction + "-impact")
		await _field_preview(faction, point)
		await _close()
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Commander support preview: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _field_preview(faction, point):
	_game.find_child("UnitMenus").close_commander()
	var worker = _spawn("Worker", 0, point + Vector3(-6, 0, -5))
	root.get_node("MatchSignals").deselect_all_units.emit()
	worker.get_node("Selection").select()
	if faction == "bastion":
		_game.engineering._spawn_barricade(
			_players[0], point + Vector3(-2, 0, -5), .4, "preview:barrier"
		)
		_game.find_child("UnitMenus").open_page("Build")
	elif faction == "helix":
		var drone = _spawn("Drone", 0, point + Vector3(-1, 4, -4))
		drone.abilities.trigger("drone_chaff")
		root.get_node("MatchSignals").deselect_all_units.emit()
		drone.get_node("Selection").select()
	else:
		var mine = _game.engineering._spawn_mine(
			_players[1], point + Vector3(-3, 0, -4), "preview:mine"
		)
		mine.deploy_left = 0
		mine.arm_left = 0
		mine.refresh_visibility()
	await _capture(faction + "-field-support")


func _capture(label):
	await _frames(12)
	await RenderingServer.frame_post_draw
	_check(
		root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK,
		"Capture failed: " + label
	)
	print("Captured ", label)
