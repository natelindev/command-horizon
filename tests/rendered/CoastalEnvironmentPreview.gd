extends "res://tests/headless/SaveRestoreEdges.gd"

var capture_prefix = "coastal-environment"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.25, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	if "--before" in OS.get_cmdline_user_args():
		capture_prefix += "-before"
	await _skirmish("bastion", "res://source/match/maps/CoastalFoundry.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	paused = true
	await _capture("home-fog", Vector3(16, 0, 34), 40)
	await _capture("shore-fog", Vector3(24, 0, 12), 46)
	await _capture("enemy-fog", Vector3(112, 0, 34), 40)
	var camera = game.get_node("IsometricCamera3D")
	var screen = root.get_final_transform() * camera.unproject_position(Vector3(112, 0, 34))
	var hidden_pixel = root.get_texture().get_image().get_pixelv(Vector2i(screen))
	_check(
		hidden_pixel.r + hidden_pixel.g + hidden_pixel.b < .03,
		"Exterior scenery reveals hidden enemy base"
	)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	await _capture("harbor", Vector3(64, 0, 25), 72)
	await _capture("inland", Vector3(64, 0, 93), 68)
	await _capture("port-edge", Vector3(128, 0, 62), 38)
	await _capture("headland", Vector3(125, 0, 8), 44)
	root.size = Vector2i(1440, 900)
	await _capture("overview", Vector3(64, 0, 50), 112)
	game.queue_free()
	await _frames(5)
	if not "--before" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		for faction in ["bastion", "helix"]:
			await _combat(faction)
	preferences.restore(original)
	for error in errors:
		push_error(error)
	print("Coastal environment preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(label, point, zoom):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 150
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/environment/%s-%s.png" % [capture_prefix, label]
	)


func _combat(faction):
	paused = false
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn", false)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	for player in [human, enemy]:
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.color = Color("d96b59")
	enemy.get_color_material().albedo_color = enemy.color
	var armies = [[], []]
	for side in 2:
		for index in 3:
			var unit = load("res://source/match/units/Tank.tscn").instantiate()
			var point = Vector3(10 if side == 0 else 15, 0, 71 + index * 2.2)
			game._setup_and_spawn_unit(
				unit, Transform3D(Basis(), point), [human, enemy][side], false
			)
			armies[side].append(unit)
	await _frames(20)
	var target = armies[1][0]
	var hp = target.hp
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(26)
	camera.set_position_safely(Vector3(14, 0, 70))
	await _frames(150)
	_check(
		is_instance_valid(target) and target.hp < hp,
		"Coastal ordinary-fog combat did not damage target"
	)
	_check(game.battlefield.is_observed(human, target), "Combat target not currently observed")
	paused = true
	var clock = game.simulation_time
	var water_time = game.map.water_material.get_shader_parameter("simulation_time")
	var positions = armies[0].map(func(unit): return unit.position)
	await _capture("combat-" + faction, Vector3(14, 0, 70), 26)
	await _frames(30)
	_check(game.simulation_time == clock, "Coastal capture advanced tactical pause")
	_check(
		game.map.water_material.get_shader_parameter("simulation_time") == water_time,
		"Coastal sea continued during pause"
	)
	for index in armies[0].size():
		_check(armies[0][index].position == positions[index], "Paused coastal combat moved")
	print("PASS normal-clock coastal combat ", faction, " damage=", hp - target.hp)
	game.queue_free()
	await _frames(5)
