extends "res://tests/headless/PreparationRegression.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "language": "en", "edge_scrolling": false})
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	shooting = load("res://source/match/units/actions/AttackingWhileInRange.gd")
	moving = load("res://source/match/units/actions/Moving.gd")
	await _setup("helix")
	# Status captions are now explicitly gated by the F1 diagnostic overlay.
	game.get_node("Debug/DiagnosticHUD").show()
	var sides = _sides()
	var prism = _spawn_weapon("AdvancedTank", sides[0], Vector3(40, 0, 10))
	var target = _spawn_weapon("Tank", sides[1], Vector3(47, 0, 10))
	await _frames(40)
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(14)
	camera.set_position_safely(Vector3(42, 0, 12))
	prism.get_node("Selection").select()
	prism.process_mode = Node.PROCESS_MODE_PAUSABLE
	prism.issue_manual_order(shooting.new(target))
	await _frames(35)
	game.hud._toggle_pause()
	await _capture_preparation("prism-deploy-720p")
	var display = prism.get_node("WeaponPreparationVisual")
	_check(display._label.text.begins_with("DEPLOY"), "Setup warning not rendered")
	game.hud._toggle_pause()
	await _frames(80)
	_check(prism.weapon_charge_progress > 0, "Rendered Prism never charges")
	_check(await _reload_preparation(prism, target), "Rendered charge reload failed")
	prism = _units(game._get_human_player(), "AdvancedTank")[0]
	target = _units(_sides()[1], "Tank").filter(func(unit): return unit.position.z < 15)[0]
	display = prism.get_node("WeaponPreparationVisual")
	game.get_node("Debug/DiagnosticHUD").show()
	_check(
		display._orb.visible and display._label.text.begins_with("CHARGE"),
		"Paused restoration hides charge warning"
	)
	await _capture_preparation("prism-charge-restored-720p")
	var menu = game.find_child("UnitMenus")
	_check(menu.get_global_rect().position.y >= 0, "Prism controls exceed 720p")
	var hp = target.hp
	# The old text button remains hidden; use the visible command-card Stop.
	var stop = menu._command_card._slots[0][1]
	_check(stop.is_visible_in_tree(), "Command-card Stop is not visible")
	var motion = InputEventMouseMotion.new()
	motion.position = stop.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = stop.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
	_check(not display._orb.visible, "Paused Stop retains the old charge warning")
	game.hud._toggle_pause()
	await _frames(20)
	_check(target.hp == hp, "Stop allowed the previous charge to fire early")
	await _clean_match()
	options.restore(original)
	print("Preparation UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture_preparation(title):
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)
