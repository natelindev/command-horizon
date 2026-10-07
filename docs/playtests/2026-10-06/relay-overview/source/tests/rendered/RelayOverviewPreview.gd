extends "res://tests/headless/RelayOverviewRegression.gd"

var captures = ""
var native = false
var _activations = 0


func _run():
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg == "--native":
			native = true
		if arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _scenario(map_name, faction):
	if faction != "frontier":
		return
	await super(map_name, faction)


func _activate(button, label):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(8)
	_check(root.get_visible_rect().encloses(button.get_global_rect()), "Button leaves viewport")
	_activations += 1
	if native and _activations <= 4:
		var pressed = [false]
		button.pressed.connect(func(): pressed[0] = true, CONNECT_ONE_SHOT)
		if _activations == 4:
			button.grab_focus()
		print("NATIVE RELAY: ", label, " ", button.get_global_rect())
		var deadline = Time.get_ticks_msec() + 180000
		while not pressed[0] and Time.get_ticks_msec() < deadline:
			await _frames(1)
		_check(pressed[0], "Native relay activation timed out")
	elif _activations % 2 == 0:
		button.grab_focus()
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = pressed
			root.push_input(key, true)
			await _frames(1)
	else:
		var point = button.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		for pressed in [true, false]:
			var click = InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
			await _frames(1)
	await _frames(8)
	print("RELAY INPUT: ", label)


func _review(label):
	await _frames(8)
	var command = game.hud.get_child(0)
	var plan = game.hud.battle_plan
	var minimap = game.get_node("HUD/MarginContainer/Minimap")
	_check(root.get_visible_rect().encloses(command.get_global_rect()), "Command panel overflow")
	_check(
		not plan.get_global_rect().intersects(minimap.get_global_rect()),
		"Battle plan covers minimap"
	)
	var overview = game.hud.find_child("RelayOverview", true, false)
	if overview != null:
		var panel = overview.get_parent().get_parent()
		_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Relay dialog overflow")
		for row in overview._rows:
			_check(
				panel.get_global_rect().encloses(row.button.get_global_rect()), "Locator overflow"
			)
			_check(
				not row.status.get_global_rect().intersects(row.button.get_global_rect()),
				"Status covers locator"
			)
	if captures != "":
		await RenderingServer.frame_post_draw
		var file = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(file), "Capture already exists")
		if not FileAccess.file_exists(file):
			root.get_texture().get_image().save_png(file)
