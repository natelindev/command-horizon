extends "res://tests/headless/RosterLayoutRegression.gd"

var capture_prefix = ""


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await _bindings_and_scales(options, original)
	for faction in ["bastion", "helix", "frontier"]:
		await _layout_fixture(faction)
		_set_size()
		var human = game._get_human_player()
		for role in ["Worker", "Infantry", "Tank", "Drone", "RepairRobot", "VehicleFactory"]:
			var units = _units(human, role)
			if units.is_empty():
				var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
				game._setup_and_spawn_unit(
					unit, Transform3D(Basis(), Vector3(40, 0, 25)), human, false
				)
				units = [unit]
			var before_time = game.simulation_time
			var before_funds = Vector2i(human.resource_a, human.resource_b)
			var action = units[0].action
			var menus = _select(units[0])
			await _frames(20)
			_check_width(menus, faction + "-" + role)
			await _review_width(menus, faction + "-" + role)
			_check(game.simulation_time == before_time, "Layout inspection advanced paused time")
			_check(
				Vector2i(human.resource_a, human.resource_b) == before_funds, "Layout spent funds"
			)
			_check(units[0].action == action, "Layout replaced a unit's action")
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Menu width: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _bindings_and_scales(options, original):
	await _layout_fixture("helix")
	_set_size()
	var human = game._get_human_player()
	var tank = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(tank, Transform3D(Basis(), Vector3(40, 0, 25)), human, false)
	var menus = _select(tank)
	await _frames(20)
	_check_width(menus, "tank")
	await _review_width(menus, "tank")
	var bindings = load("res://source/input/KeyBindings.gd")
	var profile = bindings.defaults()
	profile.keys.move_order = KEY_PAGEUP | KEY_MASK_CTRL | KEY_MASK_ALT
	profile.keys.attack_target = KEY_PAGEDOWN | KEY_MASK_CTRL | KEY_MASK_ALT
	profile.keys.attack_move = KEY_END | KEY_MASK_CTRL | KEY_MASK_ALT
	options.restore(
		{"screen": 1, "interface_scale": 1.5, "edge_scrolling": false, "key_bindings": profile}
	)
	_set_size()
	menus._refresh_buttons()
	await _frames(20)
	_check_width(menus, "remapped")
	await _review_width(menus, "remapped")
	options.restore(
		{
			"screen": 1,
			"interface_scale": 1.5,
			"edge_scrolling": false,
			"key_bindings": original.key_bindings
		}
	)
	_set_size()
	for scale_value in [1.0, 1.25, 1.5]:
		var resized = options.capture()
		resized.interface_scale = scale_value
		options.restore(resized)
		_set_size()
		await _frames(20)
		_check_width(menus, "scale-" + str(scale_value))
		await _review_width(menus, "scale-" + str(scale_value))
	paused = false
	game.queue_free()
	await _frames(5)


func _set_size():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)


func _check_width(menus, label):
	var clip = menus._scroll.get_global_rect()
	if menus._scroll.get_v_scroll_bar().visible:
		clip.size.x -= menus._scroll.get_v_scroll_bar().size.x
	_check(
		root.get_visible_rect().encloses(menus.get_global_rect()),
		label + ": panel outside viewport"
	)
	for control in menus._content.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree():
			continue
		var rect = control.get_global_rect()
		if control is BaseButton or control is Label or control is LineEdit:
			_check(
				rect.position.x >= clip.position.x - 1 and rect.end.x <= clip.end.x + 1,
				(
					label
					+ ": clipped "
					+ str(control.get_path())
					+ " "
					+ str(rect)
					+ " clip "
					+ str(clip)
				)
			)
	print(
		"WIDTH ",
		label,
		" content=",
		menus._content.size,
		" minimum=",
		menus._content.get_combined_minimum_size(),
		" clip=",
		clip
	)


func _review_width(menus, label):
	# Scroll to the end so the last row is checked in its scrolled position too.
	menus._scroll.scroll_vertical = int(menus._scroll.get_v_scroll_bar().max_value)
	await _frames(8)
	_check_width(menus, label + "-scrolled")
