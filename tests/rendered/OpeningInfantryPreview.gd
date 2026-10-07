extends "res://tests/headless/OpeningInfantryRegression.gd"

var capture_prefix = ""
var deadline = 0


func _run():
	deadline = Time.get_ticks_msec() + 240000
	Engine.max_fps = 60
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
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	await create_timer(2).timeout
	await _paid_fixture("bastion")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.hud.battle_plan._action.grab_focus()
	await _frames(20)
	await _capture("need-two")
	await _wait_input(
		func(): return barracks in get_nodes_in_group("selected_units"), "Enter: select barracks"
	)
	var funds = Vector2i(human.resource_a, human.resource_b)
	var cost = factions.cost(human, "Infantry")
	var time = game.simulation_time
	await _wait_input(func(): return barracks.production_queue.size() == 1, "Buy one infantry")
	await _frames(20)
	_check("1 more" in plan_rules.next_step(human).description, "Native first job not counted")
	await _capture("need-one")
	await _wait_input(func(): return barracks.production_queue.size() == 2, "Buy second infantry")
	await _frames(20)
	_check(
		plan_rules.next_step(human).id == "defense_pending",
		"Native second job invites duplicate purchase"
	)
	_check(game.simulation_time == time, "Paused native purchase advanced simulation")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - 2 * Vector2i(cost.resource_a, cost.resource_b)
		),
		"Native charge mismatch"
	)
	await _capture("paid-two")
	await _wait_input(func(): return not paused, "Space: finish training")
	await _until(func(): return _units(human, "Infantry").size() == 4, 60, "Native paid training")
	game.hud._toggle_pause()
	await _frames(20)
	_check(
		plan_rules.next_step(human).id == "VehicleFactory",
		"Native training did not advance opening"
	)
	await _capture("vehicle-next")
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Opening infantry native: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _wait_input(predicate, label):
	print("NATIVE OPENING INPUT: ", label)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(predicate.call(), "Missing native input: " + label)
	if not predicate.call():
		quit(1)


func _capture(label):
	await RenderingServer.frame_post_draw
	var destination = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Capture path already exists")
	if not FileAccess.file_exists(destination):
		root.get_texture().get_image().save_png(destination)
