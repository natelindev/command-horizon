extends "res://tests/headless/SignatureFeedbackRegression.gd"

var original_options = {}


func _display_setup():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	original_options = options.capture()
	options.restore(
		{"screen": 1, "interface_scale": 1.5, "edge_scrolling": false, "language": "en"}
	)
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)


func _display_restore():
	root.get_node("Globals").options.restore(original_options)


func _review(label):
	await super._review(label)
	var menu = game.find_child("UnitMenus")

	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(18)
	camera.set_position_safely(actor.position)
	await _frames(8)
	var viewport_rect = Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport_rect.encloses(menu.get_global_rect()), label + ": menu clips viewport")
	for control in [panel, panel._activate, panel._summary]:
		_check(
			menu.get_global_rect().encloses(control.get_global_rect()),
			label + ": control clips menu"
		)
	for language in ["en", "zh_CN"]:
		var away = InputEventMouseMotion.new()
		away.position = Vector2(220, 650)
		root.push_input(away, true)
		await _frames(8)
		TranslationServer.set_locale(language)
		panel.refresh()
		await _frames(8)
		_check(
			panel.get_global_rect().encloses(panel._summary.get_global_rect()),
			label + ": summary clips"
		)
		actor.signature.refresh()
		var hover = InputEventMouseMotion.new()
		hover.position = panel._summary.get_global_rect().get_center()
		root.push_input(hover, true)
		await create_timer(1).timeout
		_check(_tooltip_visible(root, panel._summary.tooltip_text), label + ": hover help missing")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(EVIDENCE + "preview-%s-%s.png" % [label, language])
	TranslationServer.set_locale("en")
	panel.refresh()
	var away = InputEventMouseMotion.new()
	away.position = Vector2(220, 650)
	root.push_input(away, true)
	await _frames(8)


func _activate():
	if "--interactive" in OS.get_cmdline_user_args():
		panel._activate.grab_focus()
		print(
			"NATIVE INPUT: ",
			human.faction,
			" button=",
			panel._activate.get_global_rect(),
			" sector=",
			game.get_node("IsometricCamera3D").unproject_position(actor.position)
		)
		var deadline = Time.get_ticks_msec() + 300000
		while actor.signature.kind == "" and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(actor.signature.kind != "", "Native ability activation timed out")
	else:
		panel._activate.grab_focus()
		await _key(KEY_ENTER)
		if human.faction == "bastion":
			await _mouse(game.get_node("IsometricCamera3D").unproject_position(actor.position))
	await _frames(4)
	_check(actor.signature.kind != "", "Ability control did not activate")


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _mouse(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _tooltip_visible(node, text):
	if (
		node is Label
		and node.text == text
		and node.is_visible_in_tree()
		and node.get_window().visible
	):
		_check(node.get_window().size.x <= root.size.x, "Ability tooltip wider than viewport")
		_check(node.get_window().size.y <= root.size.y, "Ability tooltip taller than viewport")
		return true
	for child in node.get_children(true):
		if _tooltip_visible(child, text):
			return true
	return false
