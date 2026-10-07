extends "res://tests/headless/BattlePlanRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Battle plan preview timed out")
		quit(1)
	return false


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _guidance(faction)
	saves.autosaves_enabled = autosaves
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered battle plan: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_plan(player, label):
	# Match startup applies saved display options; enforce the review viewport afterward.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var panel = game.hud.battle_plan
	var step = plan_rules.next_step(player)
	panel.refresh()
	await _frames(5)
	var clock = game.simulation_time
	var actions = step.units.map(func(unit): return unit.action)
	await _click(panel._action)
	var selected = get_nodes_in_group("selected_units")
	_check(
		selected.size() == step.units.size(), "Advice selected the wrong number of units: " + label
	)
	for index in step.units.size():
		_check(step.units[index] in selected, "Advice selection missed intended unit: " + label)
		_check(
			step.units[index].action == actions[index], "Advice selection issued an order: " + label
		)
	_check(game.simulation_time == clock, "Advice advanced paused time: " + label)
	if label.ends_with("-reinforce"):
		var menus = game.find_child("UnitMenus")
		_check(not menus._buttons.is_empty(), "Production shortcut has no build controls")
		if not menus._buttons.is_empty():
			var producer = step.units[0]
			var jobs = producer.production_queue.size()
			var funds = Vector2(player.resource_a, player.resource_b)
			await _click(menus._buttons[0].button)
			_check(
				producer.production_queue.size() == jobs + 1, "Selected producer refused its job"
			)
			_check(player.resource_a < funds.x, "Production shortcut did not pay for its job")
			if producer.production_queue.size() > jobs:
				producer.production_queue.cancel(producer.production_queue.get_elements()[-1])
			_check(
				Vector2(player.resource_a, player.resource_b) == funds,
				"Preview refund changed funds"
			)
			_check(game.simulation_time == clock, "Paused production shortcut advanced time")
	_check(
		not panel.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Battle plan overlaps minimap: " + label
	)
	_check(
		not panel.get_global_rect().intersects(game.find_child("UnitMenus").get_global_rect()),
		"Battle plan overlaps selection controls: " + label
	)
	panel._toggle.grab_focus()
	await _key(KEY_ENTER)
	_check(not panel._body.visible, "Keyboard collapse failed: " + label)
	await _key(KEY_ENTER)
	_check(panel._body.visible, "Keyboard expansion failed: " + label)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Battle-plan review resolution changed")
	frame.save_png("res://art/skirmish/battle-plan-%s.png" % label)
	print("BATTLE PLAN CAPTURE ", label)
	return true


func _click(control):
	var point = root.get_final_transform() * control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	await _frames(2)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(3)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(3)
