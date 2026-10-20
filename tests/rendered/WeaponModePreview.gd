extends "res://tests/headless/WeaponModeRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	moving = load("res://source/match/units/actions/Moving.gd")
	await _setup("helix")
	var human = game._get_human_player()
	var lancer = _spawn_weapon("CombatRobot", human, Vector3(40, 0, 10))
	var second = _spawn_weapon("CombatRobot", human, Vector3(42, 0, 10))
	var tank = _spawn_weapon("Tank", human, Vector3(40, 0, 13))
	await _frames(40)
	for unit in [lancer, second, tank]:
		unit.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.settings.visibility = 2
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(17)
	camera.set_position_safely(Vector3(43, 0, 13))
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	_check(behavior.guard(second, second.global_position_yless), "Guard fixture did not start")
	await _frames(3)
	lancer.issue_manual_order(moving.new(Vector3(37, 0, 10)))
	var order = lancer.action
	game.hud._toggle_pause()
	for unit in [tank, lancer, second]:
		unit.get_node("Selection").select()
	await _frames(5)
	var menu = game.find_child("UnitMenus")
	var panel = menu._weapon_modes
	_check(panel != null, "Mixed selection has no weapon controls")
	await _click(panel._interception)
	_check(lancer.pending_weapon_mode == "interception", "Mouse mode choice failed")
	_check(second.pending_weapon_mode == "interception", "Mixed mode choice missed another Lancer")
	_check(lancer.action == order, "UI mode choice replaced movement")
	_check(second.stance == second.Stance.HOLD_POSITION, "Mode choice cancelled the guard stance")
	_check(tank.type == "Tank" and tank.attack_domains.size() == 1, "Mode choice changed a tank")
	await _frames(40)
	_check(lancer.weapon_switch_left == 2, "Paused UI mode change advanced simulation")
	_check(panel._interception.disabled and panel._precision.disabled, "UI permits repeat switches")
	await _capture_mode("weapon-switch-mixed-720p")
	_check(menu.get_global_rect().position.y >= 0, "Mode controls push mixed panel above 720p")
	_check(menu.get_global_rect().end.x <= 1280, "Mode panel exceeds width")
	game.hud._toggle_pause()
	await _frames(135)
	_check(lancer.weapon_mode == "interception", "UI switch never completed")
	_check(second.weapon_mode == "interception", "Guard replaced the player-selected mode")
	root.get_node("MatchSignals").deselect_all_units.emit()
	lancer.get_node("Selection").select()
	await _frames(5)
	panel = menu._weapon_modes
	_check(menu._status.text.contains("Interception"), "Selected unit hides current mode")
	game.hud._toggle_pause()
	panel._precision.grab_focus()
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)
	_check(lancer.pending_weapon_mode == "precision", "Keyboard mode choice failed")
	_check(
		second.weapon_mode == "interception" and second.weapon_switch_left == 0,
		"Single selection changed another unit"
	)
	await _capture_mode("weapon-switch-single-720p")
	_check(menu.get_global_rect().position.y >= 0, "Single mode panel exceeds 720p")
	# Losing a selected Lancer mid-switch must refresh the panel without stale references.
	lancer.hp = 0
	await _frames(5)
	_check(not menu.visible, "Dead selected unit kept its weapon panel")
	await _clean_match()
	print("Weapon mode UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _click(control):
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _capture_mode(title):
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % title)
