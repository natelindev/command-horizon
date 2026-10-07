extends "res://tests/headless/AttackFeedbackRegression.gd"

var captures = ""


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var values = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(values)


func _feedback_case(faction):
	if faction == "frontier":
		await super(faction)


func _review_attack(label):
	game.hud.pause_after_load()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _capture_attack(label)
	if label.ends_with("-base") or label == "earned-industrial":
		var clock = game.simulation_time
		var units = get_nodes_in_group("units")
		var orders = units.map(func(unit): return unit.action)
		var point = panel.toggle.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		for pressed in [true, false]:
			var click = InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
			await _frames(2)
		_check(panel.panel.visible, "Attack button did not open history")
		_check(alerts.unread_count() == 0, "Opening attack history did not mark read")
		await _capture_attack(label + "-history")
		var entry = _kind("base_attack", true)[0]
		panel.rows[entry.id].action.grab_focus()
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = pressed
			root.push_input(key, true)
			await _frames(2)
		_check(not panel.panel.visible, "Keyboard Show did not close history")
		_check(
			not get_nodes_in_group("selected_units").is_empty(),
			"Attack inspection selected nothing"
		)
		_check(paused and game.simulation_time == clock, "Attack inspection resumed simulation")
		_check(
			units.map(func(unit): return unit.action) == orders, "Attack inspection changed orders"
		)


func _capture_attack(label):
	await _frames(16)
	var viewport = root.get_visible_rect()
	_check(viewport.encloses(panel.toggle.get_global_rect()), "Attack button leaves viewport")
	var font = panel.toggle.get_theme_font("font")
	var width = (
		font
		. get_string_size(
			panel.toggle.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			panel.toggle.get_theme_font_size("font_size")
		)
		. x
	)
	var style = panel.toggle.get_theme_stylebox("normal")
	_check(width + style.get_minimum_size().x <= panel.toggle.size.x, "Attack label does not fit")
	if panel.panel.visible:
		_check(viewport.encloses(panel.panel.get_global_rect()), "Attack history leaves viewport")
	if captures != "":
		await RenderingServer.frame_post_draw
		var file = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(file), "Attack capture already exists")
		if not FileAccess.file_exists(file):
			root.get_texture().get_image().save_png(file)
