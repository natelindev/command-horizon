extends "res://tests/headless/RecoveryGuidanceRegression.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	plan = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		await _missing_and_paid_service(faction)
		await _other_roles(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Recovery guidance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review(label):
	# Match startup applies saved display options; enforce the review viewport afterward.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var panel = game.hud.battle_plan
	panel.refresh()
	await _frames(5)
	var step = plan.next_step(human)
	var clock = game.simulation_time
	var actions = step.units.map(func(unit): return unit.action)
	await _click(panel._action)
	var selected = get_nodes_in_group("selected_units")
	_check(selected.size() == step.units.size(), "Recovery selection count differs")
	for index in step.units.size():
		_check(step.units[index] in selected, "Recovery selection missed an intended unit")
		_check(step.units[index].action == actions[index], "Recovery selection issued an order")
	_check(game.simulation_time == clock, "Recovery selection advanced paused time")
	_check(
		not panel.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Recovery guidance overlaps minimap"
	)
	_check(
		not panel.get_global_rect().intersects(game.find_child("UnitMenus").get_global_rect()),
		"Recovery guidance overlaps controls"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Recovery review resolution changed")
	frame.save_png("res://art/skirmish/recovery-guidance-%s.png" % label)
	print("RECOVERY CAPTURE ", label)
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
