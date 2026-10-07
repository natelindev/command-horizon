extends "res://tests/headless/FrontierWheelRegression.gd"

var frame_index = 0
var samples = []
var evidence_prefix = EVIDENCE + "native"
var frames_directory = "res://tmp/frontier-wheel-frames"


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			evidence_prefix = argument.trim_prefix("--evidence=")
		if argument.begins_with("--frames="):
			frames_directory = argument.trim_prefix("--frames=")
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	wheel_move = load("res://source/match/units/actions/Moving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await _fixture()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1280, 720)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var index = 0
	for role in ROLES:
		var unit = _spawn_frontier(role, human, Vector3(43 + index * 3, 0, 48))
		unit.issue_manual_order(null)
		subjects.append(unit)
		index += 1
	game.fog_of_war.reveal()
	game.hud.hide()
	game.hud.alert_panel.hide()
	game.get_node("HUD").hide()
	game.subtitles.hide()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_min = 3
	camera.set_size_safely(18)
	camera.set_position_safely(Vector3(49, 0, 45))
	DirAccess.make_dir_recursive_absolute(frames_directory)
	_check(
		not FileAccess.file_exists(frames_directory + "/frame-0000.jpg"),
		"Preview would overwrite frames"
	)
	if not errors.is_empty():
		quit(1)
		return
	await _frames(5)
	await _still("lineup")
	for unit in subjects:
		unit.issue_manual_order(wheel_move.new(unit.position + Vector3(0, 0, -8)))
	for frame in 180:
		await process_frame
		if frame % 2 == 0:
			await _frame("normal")
	for unit in subjects:
		unit.issue_manual_order(null)
	await _frames(20)
	game.hud._toggle_pause()
	var poses = subjects.map(_poses)
	for frame in 30:
		await process_frame
		if frame % 2 == 0:
			await _frame("paused")
	for item in subjects.size():
		_check(_same_poses(poses[item], _poses(subjects[item])), "Native pause advances wheels")
	var tank = subjects[1]
	camera.rotation.y = .9
	camera.set_size_safely(3.8)
	camera.set_position_safely(tank.position)
	await _still("detail-paused")
	Engine.time_scale = .25
	tank.issue_manual_order(wheel_move.new(tank.position + Vector3(0, 0, -8)))
	game.hud._toggle_pause()
	for frame in 240:
		await process_frame
		camera.set_position_safely(tank.position)
		if frame % 2 == 0:
			await _frame("quarter-speed-detail")
	await _still("detail-moving")
	tank.issue_manual_order(null)
	await _frames(30)
	var stopped = _poses(tank)
	await _frames(30)
	_check(_same_poses(stopped, _poses(tank)), "Native stopped tank wheels keep spinning")
	_check(not _same_poses(poses[1], _poses(tank)), "Native close-up wheels did not articulate")
	Engine.time_scale = 1.0
	FileAccess.open(evidence_prefix + "-samples.json", FileAccess.WRITE).store_string(
		JSON.stringify(samples, "\t")
	)
	await _cleanup()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Frontier wheel preview: %d failures; %d frames" % [errors.size(), frame_index])
	quit(0 if errors.is_empty() else 1)


func _frame(stage):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(frames_directory + "/frame-%04d.jpg" % frame_index, .93)
	samples.append(
		{
			"frame": frame_index,
			"stage": stage,
			"time": game.simulation_time,
			"position": str(subjects[1].position),
			"angles":
			subjects[1].get_node("BastionVisuals")._wheel_motion.wheels.map(
				func(wheel): return wheel.angle
			)
		}
	)
	frame_index += 1


func _still(label):
	await _frames(6)
	await RenderingServer.frame_post_draw
	var target = evidence_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(target), "Native wheel capture would overwrite evidence")
	if not FileAccess.file_exists(target):
		root.get_texture().get_image().save_png(target)


func _fixture():
	await _skirmish("frontier", "res://source/match/maps/DesertFrontier.tscn")
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
