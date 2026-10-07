extends "res://tests/headless/EconomySupplyRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 360000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Economy supply preview timed out")
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
	await super()
	options.restore(original)


func _review_supply(player, label):
	var panel = game.hud.battle_plan
	var step = plan.next_step(player)
	panel.refresh()
	await _frames(5)
	var clock = game.simulation_time
	var actions = step.units.map(func(unit): return unit.action)
	var point = root.get_final_transform() * panel._action.get_global_rect().get_center()
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
	var selected = get_nodes_in_group("selected_units")
	_check(selected.size() == step.units.size(), "Supply shortcut selected wrong count: " + label)
	for index in step.units.size():
		_check(step.units[index] in selected, "Supply shortcut missed intended unit: " + label)
		_check(
			step.units[index].action == actions[index], "Supply shortcut issued orders: " + label
		)
	_check(game.simulation_time == clock, "Supply shortcut advanced pause: " + label)
	for name in ["Minimap", "UnitMenus"]:
		_check(
			not panel.get_global_rect().intersects(game.find_child(name).get_global_rect()),
			"Supply panel overlap: " + name
		)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Supply preview resolution changed")
	frame.save_png("res://art/skirmish/economy-%s.png" % label)
	print("SUPPLY CAPTURE ", label)
