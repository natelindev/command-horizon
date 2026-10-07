extends "res://tests/headless/GroundDefenseAdviceRegression.gd"

var capture_prefix = ""
var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 360000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Native ground defense review timed out")
		quit(1)
	return false


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if capture_prefix == "":
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	tactics = load("res://source/match/SkirmishTactics.gd")
	combat_rules = load("res://source/match/combat/CombatRules.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	await create_timer(2).timeout
	var args = OS.get_cmdline_user_args()
	var cases = (
		["frontier"] if "--layouts-only" in args or "--frontier-only" in args else factions.IDS
	)
	for faction in cases:
		await _ground_fixture(faction)
		if "--layouts-only" in OS.get_cmdline_user_args():
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = Vector2i(1920, 1080)
			var panel = game.hud.battle_plan
			panel._select([factory])
			game.fog_of_war._physics_process(0.0)
			await _frames(10)
			await _capture("frontier-final-wording")
			await _blocked_layouts(panel)
		else:
			await _native_counter(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Ground defense native: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _native_counter(faction):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(hq_point)
	var panel = game.hud.battle_plan
	panel.refresh()
	game.fog_of_war._physics_process(0.0)
	await _frames(10)
	await _capture(faction + "-advice")
	_check(
		root.get_visible_rect().encloses(panel.get_global_rect()), "Battle plan escapes viewport"
	)
	var funds = Vector2i(human.resource_a, human.resource_b)
	var clock = game.simulation_time
	if faction == "helix":
		panel._action.grab_focus()
	await _wait_input(
		func(): return factory in get_nodes_in_group("selected_units"),
		faction + ": select production from battle plan"
	)
	_check(paused and game.simulation_time == clock, "Selection advanced tactical pause")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Advice selection spent funds")
	_check(factory.production_queue.size() == 0, "Advice selection automatically bought a unit")
	await _capture(faction + "-selected")
	if faction == "frontier":
		print("NATIVE GROUND INPUT: click Select production again")
		await panel._action.pressed
		await _frames(8)
		_check(game.find_child("UnitMenus")._scroll.size.y > 100, "Native repeat collapsed roster")
		await _capture(faction + "-reselected")
	await _wait_input(
		func(): return factory.production_queue.size() > 0, faction + ": buy one tank"
	)
	var cost = factions.cost(human, "Tank")
	_check(
		factory.production_queue.size() == 1, "Native purchase did not queue exactly one counter"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Native counter purchase charged wrong price"
	)
	panel.refresh()
	_check("already paid" in panel._description.text, "Native paid advice not refreshed")
	await _frames(8)
	await _capture(faction + "-paid")
	factory.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_input(func(): return not paused, faction + ": Space to complete production")
	while _units(human, "Tank").is_empty() and game.simulation_time - clock < 90:
		await _frames(1)
	game.hud._toggle_pause()
	_check(not _units(human, "Tank").is_empty(), "Native paid counter failed to complete")
	panel.refresh()
	_check(
		panel._action.text == "Select defenders", "Completed native counter lost defender selection"
	)
	await _frames(8)
	await _capture(faction + "-complete")
	print("NATIVE COUNTER VERIFIED ", faction, " paid=", cost)
	if faction == "frontier":
		await _blocked_layouts(panel)


func _blocked_layouts(panel):
	for tank in _units(human, "Tank"):
		tank.queue_free()
	await _frames(2)
	human.resource_a = 0
	human.resource_b = 0
	factory.production_queue.fit_chips = true
	human.emit_changed()
	panel._select([factory])
	panel.refresh()
	await _frames(8)
	_check(game.find_child("UnitMenus")._scroll.size.y > 100, "Repeated selection collapsed roster")
	await _capture("frontier-shortage")
	_check(
		root.get_visible_rect().encloses(panel.get_global_rect()),
		"Shortage advice escapes viewport"
	)
	_units(human, "CommandLab")[0].queue_free()
	await _frames(2)
	panel.refresh()
	await _frames(8)
	await _capture("frontier-missing-lab")
	_check(
		root.get_visible_rect().encloses(panel.get_global_rect()),
		"Prerequisite advice escapes viewport"
	)


func _wait_input(predicate, label):
	print("NATIVE GROUND INPUT: ", label)
	while not predicate.call() and Time.get_ticks_msec() <= deadline:
		await _frames(1)
	_check(predicate.call(), "Missing native input: " + label)


func _capture(label):
	await RenderingServer.frame_post_draw
	var destination = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Capture already exists: " + destination)
	if not FileAccess.file_exists(destination):
		_check(root.get_texture().get_image().save_png(destination) == OK, "Capture write failed")
