extends "res://tests/headless/TechnologyRegression.gd"


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
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		await _frames(5)
		await _interface(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Technology interface: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _interface(faction):
	var hud = game.hud
	lab.get_node("Selection").select()
	await _frames(15)
	var menus = game.find_child("UnitMenus")
	_check(is_instance_valid(menus._research_panel), "Selected lab omitted research")
	await _capture(faction + "-lab")
	lab.get_node("Selection").deselect()
	var action = tank.action
	await _click(hud._technology_button)
	_check(is_instance_valid(hud.technology_panel), "Tech button did not open research")
	if not is_instance_valid(hud.technology_panel):
		return
	var panel = hud.technology_panel
	_check(panel._branches.doctrine.button.disabled, "Doctrine ignored Coordination prerequisite")
	await _capture(faction + "-overview")
	hud._technology_scroll.get_v_scroll_bar().grab_focus()
	await _key(KEY_END)
	await _frames(6)
	_check(hud._technology_scroll.scroll_vertical > 0, "Research screen did not scroll")
	await _capture(faction + "-prerequisites")
	await _key(KEY_HOME)
	await _frames(6)
	var funds = Vector2i(human.resource_a, human.resource_b)
	await _click(panel._branches.weapons.button)
	_check(human.technology.active == "weapons_1", "Weapon research button failed")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(30, 20), "UI price differs"
	)
	await _capture(faction + "-research")
	await _click(panel._cancel)
	_check(human.technology.active == "", "Cancel research button failed")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "UI refund differs")
	await _escape()
	_check(hud.technology_panel == null and paused, "Escape lost prior pause state")
	_check(tank.action == action, "Technology controls changed army orders")
	game.hud._toggle_pause()
	await _click(hud._technology_button)
	_check(paused, "Technology overlay did not pause battle")
	await _escape()
	_check(not paused, "Technology overlay did not resume battle")
	game.hud._toggle_pause()
	# The timed effects are covered by TechnologyRegression; inspect completed UI here.
	human.coordination_unlocked = true
	for id in ["weapons_1", "armor_1", "service", "doctrine"]:
		_check(human.technology.start(id, lab), "Preview research refused " + id)
		human.technology._physics_process(1000)
	await _click(hud._technology_button)
	panel = hud.technology_panel
	panel._branches.doctrine.button.grab_focus()
	hud._technology_scroll.scroll_vertical = 2000
	await _frames(6)
	await _capture(faction + "-doctrine")
	await _escape()
	tank.get_node("Selection").select()
	await _frames(15)
	await _capture(faction + "-unit")
	_check(human.technology.start("weapons_2", lab), "Lost-lab fixture research failed")
	lab.queue_free()
	for worker in _units(human, "Worker"):
		worker.queue_free()
	await _frames(5)
	human.resource_a = 0
	human.resource_b = 0
	var advice = load("res://source/match/SkirmishPlan.gd").next_step(human)
	_check(advice.get("open_technology", false), "Recovery advice hid paid technology refund")
	hud.battle_plan.refresh()
	await _frames(5)
	await _click(hud.battle_plan._action)
	_check(is_instance_valid(hud.technology_panel), "Recovery advice did not open technology")
	if is_instance_valid(hud.technology_panel):
		await _capture(faction + "-lost-lab")
		await _click(hud.technology_panel._cancel)
		_check(human.resource_a == 60 and human.resource_b == 40, "Lost-lab refund differs")
		await _escape()


func _capture(label):
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Technology preview resolution changed")
	frame.save_png("res://art/skirmish/technology-%s.png" % label)
	print("TECHNOLOGY CAPTURE ", label)


func _escape():
	await _key(KEY_ESCAPE)


func _key(code):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await _frames(3)


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
