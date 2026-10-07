extends "res://tests/headless/SignatureRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		_check(await _ui(faction) == true, "Signature UI suite did not finish")
		await _clean_match()
	print("Signature UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _ui(faction):
	var sides = _sides()
	var human = sides[0]
	human.coordination_unlocked = true
	var first = _spawn_weapon("CombatRobot", human, Vector3(40, 0, 10))
	var second = _spawn_weapon("CombatRobot", human, Vector3(42.5, 0, 10))
	var tank = _spawn_weapon("Tank", human, Vector3(40, 0, 13))
	_spawn_weapon("Tank", sides[1], Vector3(45, 0, 12))
	await _frames(40)
	first.process_mode = Node.PROCESS_MODE_PAUSABLE
	second.process_mode = Node.PROCESS_MODE_PAUSABLE
	first.program.run()
	await _frames(20)
	var action = first.action
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(18)
	camera.set_position_safely(Vector3(42, 0, 12))
	game.hud._toggle_pause()
	for unit in [first, second, tank]:
		unit.get_node("Selection").select()
	await _frames(20)
	var menu = game.find_child("UnitMenus")
	var button = menu._signature_panel._activate
	_check(not button.disabled, "Signature button unavailable for ready selection")
	if faction == "bastion":
		await _mouse(button.get_global_rect().get_center())
		_check(
			game.hud._assignment_kind == "signature", "Anchor button did not arm sector selection"
		)
		await _key(KEY_ESCAPE)
		_check(
			game.hud._assignment_kind == "" and first.signature.kind == "",
			"Esc did not cancel without activation"
		)
		await _mouse(button.get_global_rect().get_center())
		await _mouse(camera.unproject_position(Vector3(40, 0, 10)), MOUSE_BUTTON_RIGHT)
		_check(game.hud._assignment_kind == "", "Right click did not cancel sector selection")
		await _mouse(button.get_global_rect().get_center())
		await _mouse(camera.unproject_position(Vector3(40, 0, 10)))
		_check(
			first.signature.kind == "anchor" and second.signature.kind == "anchor",
			"World click did not activate Anchor"
		)
	else:
		button.grab_focus()
		await _key(KEY_ENTER)
		_check(
			first.signature.kind == "precision" and second.signature.kind == "precision",
			"Keyboard Precision activation failed"
		)
	_check(tank.signature.kind == "", "Ability affected an unchipped selected tank")
	_check(
		first.action == action and first.program.mode == "Running",
		"Ability interrupted the running program"
	)
	var cooldown = first.signature.cooldown
	await _frames(30)
	_check(first.signature.cooldown == cooldown, "Paused UI activation advanced cooldown")
	_check(button.disabled, "Signature button ignores group cooldown")
	await _capture_signature("signature-%s-720p" % faction)
	_check(menu.get_global_rect().position.y >= 0, "Signature controls exceed 720p height")
	_check(menu.get_global_rect().end.x <= 1280, "Signature controls exceed 720p width")
	game.hud._toggle_pause()
	await _frames(135)
	if faction == "bastion":
		_check(first.signature.anchored and second.signature.anchored, "UI Anchor never settled")
	else:
		_check(
			first.signature.kind == "" and first.signature.cooldown > 0,
			"UI Precision window/cooldown failed"
		)
	return true


func _mouse(point, button = MOUSE_BUTTON_LEFT):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _capture_signature(title):
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)
