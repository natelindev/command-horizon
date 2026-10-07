extends "res://tests/headless/AirHoldingRegression.gd"

var watch_live = false
var prefix = "res://docs/playtests/2026-10-07/air-difficulties/verified-recovery"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _review_held():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.get_node("IsometricCamera3D").set_position_safely(game.map.LAUNCH)
	await _capture("held")


func _continue_input():
	game.hud._continue.grab_focus()
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(2)
	watch_live = true
	print("HELD INPUT continue-enter=1")


func _frames(count):
	await super(count)
	if watch_live and not paused:
		watch_live = false
		_check(
			game.hud._assignment_hint.text == "Battle loaded.",
			"Live recovery retains a stale paused notice"
		)
		await _capture("live")


func _review_safe():
	game.get_node("IsometricCamera3D").set_position_safely(game.map.EXIT)
	await _capture("safe")


func _capture(label):
	root.size = Vector2i(1280, 720)
	await _frames(5)
	_check(
		(
			game.hud.objective_panel.get_global_rect().end.y
			< game.find_child("Minimap").get_global_rect().position.y
		),
		"Held guidance overlaps minimap"
	)
	for row in game.hud._flight_labels:
		_check(
			game.hud.objective_panel.get_global_rect().encloses(row.get_global_rect()),
			"Held flight row escapes objective panel"
		)
	print(
		"AIR LAYOUT ",
		label,
		" bottom=",
		game.hud.objective_panel.get_global_rect().end.y,
		" minimap=",
		game.find_child("Minimap").get_global_rect().position.y
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Held preview resolution changed")
	var destination = prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Held preview would overwrite evidence")
	if not FileAccess.file_exists(destination):
		frame.save_png(destination)
