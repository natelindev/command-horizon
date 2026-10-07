extends "res://tests/headless/SupplyContestRegression.gd"

var captured = false


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _review_contest():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.get_node("IsometricCamera3D").set_physics_process(false)
	game.get_node("IsometricCamera3D").set_position_safely(game.map.POINTS[0])


func _frames(count):
	await super(count)
	if response != null and not paused and not captured:
		captured = true
		root.size = Vector2i(1280, 720)
		await RenderingServer.frame_post_draw
		_check(not paused, "Live combat capture paused simulation")
		var frame = root.get_texture().get_image()
		_check(frame.get_size() == Vector2i(1280, 720), "Live combat capture size changed")
		var destination = "res://docs/playtests/2026-10-07/supply-environment/live-combat.png"
		_check(not FileAccess.file_exists(destination), "Live combat would overwrite evidence")
		if not FileAccess.file_exists(destination):
			frame.save_png(destination)
		print("LIVE COMBAT time=", game.simulation_time, " paused=", paused)


func _review_recovered():
	_check(captured, "Live combat was never captured")
