extends "res://tests/headless/DefenseFocusRegression.gd"

var capture_prefix = ""
var input_count = 0


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(original)


func _assert_focus(label, expected):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	# The fixture relocates frozen units while paused. Refresh only the normal
	# visibility/fog presentation, without advancing the simulation or revealing all.
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	game.get_node("IsometricCamera3D").set_size_safely(22)
	await _frames(10)
	await super(label, expected)


func _activate_defense(panel):
	# Refresh can reflow the action row; use its final rectangle for GUI input.
	await _frames(4)
	var activated = [false]
	var observe = func(): activated[0] = true
	panel._action.pressed.connect(observe)
	if input_count % 2 == 0:
		var center = panel._action.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = center
		root.push_input(motion, true)
		for pressed in [true, false]:
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = center
			root.push_input(click, true)
			await _frames(2)
	else:
		panel._action.grab_focus()
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = pressed
			root.push_input(key, true)
			await _frames(2)
	_check(activated[0], "Rendered input missed the defender-selection button")
	panel._action.pressed.disconnect(observe)
	print("DEFENSE GUI ", input_count, " activated=", activated[0])
	input_count += 1


func _review_focus(label):
	var panel = game.hud.battle_plan
	_check(
		not panel.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Defense panel overlaps minimap: " + label
	)
	_check(
		not panel.get_global_rect().intersects(game.find_child("UnitMenus").get_global_rect()),
		"Defense panel overlaps selection controls: " + label
	)
	if not (
		label.begins_with("visible-") or label.begins_with("earned-") or label == "air-frontier"
	):
		return
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(960, 350)
	root.push_input(motion, true)
	await _frames(8)
	if capture_prefix != "":
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		_check(picture.get_size() == Vector2i(1280, 720), "Defense review resolution changed")
		var path = capture_prefix + "-" + label + ".png"
		_check(not FileAccess.file_exists(path), "Defense review would overwrite evidence")
		if not FileAccess.file_exists(path):
			picture.save_png(path)
