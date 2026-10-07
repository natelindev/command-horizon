extends "res://tests/headless/CommandHorizonRegression.gd"

var prefix = "res://docs/playtests/2026-10-07/horizon-surroundings/before"


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
	path = "user://horizon-art-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	Progress.new().record_foundry_victory(path)
	await _make_match()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.hud._toggle_pause()
	var camera = game.get_node("IsometricCamera3D")
	camera.size_max = 240
	camera.set_size_safely(25)
	camera.set_position_safely(Vector3(25, 0, 66))
	await _shot("start", Vector2i(1280, 720))
	_check(
		not game.battlefield.is_observed(
			game._get_human_player(), _units(game._enemy, "Infantry")[0]
		),
		"Environment revealed unobserved opposition"
	)
	for entry in [["enemy-fog", Vector3(156, 0, 65)], ["boundary-fog", Vector3(184, 0, 65)]]:
		camera.set_size_safely(42)
		camera.set_position_safely(entry[1])
		await _shot(entry[0], Vector2i(1280, 720))
	# Explicit art-review reveal; these frames are not observation/gameplay evidence.
	game.fog_of_war.reveal()
	game.hud.hide()
	game.hud.alert_panel.hide()
	game.get_node("HUD").hide()
	game.subtitles.hide()
	for entry in [
		["north", Vector3(116, 0, 22)],
		["deployment", Vector3(76, 0, 66)],
		["command", Vector3(156, 0, 65)]
	]:
		camera.set_size_safely(42)
		camera.set_position_safely(entry[1])
		await _shot(entry[0], Vector2i(1280, 720))
	camera.set_size_safely(184)
	camera.set_position_safely(Vector3(92, 0, 66))
	await _shot("overview", Vector2i(1440, 900))
	for entry in [
		["north-edge", Vector3(116, 0, 0)],
		["west", Vector3(0, 0, 66)],
		["south", Vector3(116, 0, 132)],
		["boundary", Vector3(184, 0, 65)]
	]:
		camera.set_size_safely(30)
		camera.set_position_safely(entry[1])
		await _shot(entry[0], Vector2i(1280, 720))
	await _close()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Horizon environment preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label, dimensions):
	root.size = dimensions
	await _frames(6)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == dimensions, "Horizon art capture has wrong dimensions")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Horizon art capture would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
