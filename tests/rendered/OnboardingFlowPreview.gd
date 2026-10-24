extends "res://tests/headless/CampaignRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-24/onboarding-review/"
var _captures = 0
var _options
var _original


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Onboarding flow requires native rendering")
		quit(1)
		return
	Engine.max_fps = 60
	_options = root.get_node("Globals").options
	_original = _options.capture()
	_options.restore(
		{
			"screen": 1,
			"language": "en",
			"interface_scale": 1.0,
			"edge_scrolling": false,
			"master_volume": 0.0
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _frames(6)
	root.get_node("SaveManager").autosaves_enabled = false
	await _capture("01-main-menu")
	await _click(menu.find_child("Campaign", true, false))
	await _frames(20)
	var campaign = current_scene
	_check("_operation_buttons" in campaign, "Campaign menu click did not open campaign")
	if not "_operation_buttons" in campaign:
		await _finish_review()
		return
	await _click(campaign._operation_buttons[campaign._ids.find("first_orders")])
	await _capture("02-first-orders-briefing")
	print("FIRST_ORDERS_INTEL: ", campaign._theater_intel.text)
	await _click(campaign._start_button)
	var deadline = Time.get_ticks_msec() + 30000
	while not (is_instance_valid(current_scene) and "phase" in current_scene):
		if Time.get_ticks_msec() > deadline:
			_check(false, "First Orders Start did not reach mission")
			await _finish_review()
			return
		await process_frame
	game = current_scene
	game.progress_path = "user://onboarding-review-%d.json" % OS.get_process_id()
	await _frames(30)
	await _capture("03-cinematic-briefing")
	if game.campaign_story.cinematic:
		await _click(game.campaign_story._skip)
	await _frames(20)
	await _click(game.hud._find_button)
	_check(
		get_nodes_in_group("selected_units").all(func(unit): return unit.type == "Worker"),
		"Find engineer did not select engineers"
	)
	await _capture("04-engineer-build-controls")
	var human = game._get_human_player()
	var placement = human.get_node("StructurePlacementHandler")
	var menus = game.find_child("UnitMenus", true, false)
	var build_button = menus.find_child("BuildCommandLab", true, false)
	await _click(build_button)
	_check(placement._structure_placement_started(), "Command lab button did not arm placement")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_position_safely(Vector3(19, 0, 15))
	camera.set_size_safely(32)
	var before = Vector2(human.resource_a, human.resource_b)
	await _point(camera.unproject_position(_units(human, "CommandCenter")[0].global_position))
	_check(
		(
			placement._calculate_blueprint_position_validity()
			!= placement.BlueprintPositionValidity.VALID
		),
		"HQ overlap incorrectly accepted a building"
	)
	await _capture("05-invalid-placement-feedback")
	await _mouse(camera.unproject_position(Vector3(22, 0, 8)), MOUSE_BUTTON_RIGHT)
	_check(not placement._structure_placement_started(), "Right click did not cancel placement")
	_check(
		Vector2(human.resource_a, human.resource_b) == before,
		"Canceled placement consumed resources"
	)
	await _click(build_button)
	var placed = false
	for point in [Vector3(23, 0, 8), Vector3(27, 0, 15), Vector3(21, 0, 4)]:
		var screen = camera.unproject_position(point)
		await _point(screen)
		if (
			placement._calculate_blueprint_position_validity()
			== placement.BlueprintPositionValidity.VALID
		):
			await _mouse(screen)
			placed = true
			break
	_check(placed, "No valid lab position could be placed through pointer input")
	await _frames(15)
	await _capture("06-lab-under-construction")
	_check(not _units(human, "CommandLab").is_empty(), "Pointer placement did not create a lab")
	# Only idle construction time is accelerated; every UI gesture runs at normal speed.
	Engine.time_scale = 4.0
	deadline = Time.get_ticks_msec() + 25000
	while game.phase == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	_check(game.phase == 1, "Actual construction did not advance guard lesson")
	if game.phase == 1:
		await _frames(15)
		await _click(game.hud._find_button)
		await _frames(6)
		menus = game.find_child("UnitMenus", true, false)
		await _click(menus.find_child("Guard", true, false))
		_check(game.hud.direct_orders.kind == "guard", "Guard button did not arm a destination")
		await _mouse(camera.unproject_position(Vector3(28, 0, 27)))
		await _frames(20)
		_check(game.phase == 2, "Guard destination did not advance capture lesson")
		await _capture("07-capture-lesson")
	await _click(game.hud._pause_button)
	_check(paused, "Tactical pause button did not pause")
	var simulation_before = game.simulation_time
	await _frames(15)
	_check(simulation_before == game.simulation_time, "Pause advanced mission time")
	await _click(game.hud._find_button)
	_check(
		get_nodes_in_group("selected_units").all(func(unit): return unit.type == "Infantry"),
		"Find infantry did not work during tactical pause"
	)
	await _capture("08-paused-planning")
	# Controlled failure states test recovery guidance without waiting for casualties.
	game.phase = 1
	for tank in _units(human, "Tank"):
		tank.queue_free()
	await _frames(20)
	_check(
		game.hud._lesson_title.text == "TRAIN A TANK",
		"Missing armor did not show replacement training guidance"
	)
	await _capture("09-missing-armor-guidance")
	print("MISSING_ARMOR_LESSON: ", game.hud._lesson_text.text)
	await _click(game.hud._find_button)
	var selected = get_nodes_in_group("selected_units")
	_check(
		not selected.is_empty() and selected.all(func(unit): return unit.type == "VehicleFactory"),
		"Missing armor shortcut did not select the vehicle factory"
	)
	await _capture("10-missing-armor-shortcut")
	_options.restore({"language": "zh_CN", "interface_scale": 1.5})
	await _frames(20)
	await _capture("11-chinese-large-ui-recovery")
	await _finish_review()


func _finish_review():
	Engine.time_scale = 1.0
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await _frames(5)
	_options.restore(_original)
	for message in errors:
		push_error(message)
	print("Onboarding UI flow: %d failures, %d captures" % [errors.size(), _captures])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _click(control):
	if not is_instance_valid(control):
		_check(false, "Missing UI control")
		return
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			for attempt in 16:
				var clip = ancestor.get_global_rect()
				var point = control.get_global_rect().get_center()
				if clip.has_point(point):
					break
				await _mouse(
					clip.get_center(),
					MOUSE_BUTTON_WHEEL_DOWN if point.y > clip.end.y else MOUSE_BUTTON_WHEEL_UP
				)
		ancestor = ancestor.get_parent()
	_check(
		control.is_visible_in_tree() and not control.disabled,
		"Unavailable UI control: " + control.name
	)
	await _mouse(control.get_global_rect().get_center())
	await _frames(8)


func _point(point):
	var event = InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)
	await _frames(3)


func _mouse(point, button = MOUSE_BUTTON_LEFT):
	await _point(point)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await _frames(2)


func _capture(label):
	await _frames(3)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_captures += 1
	print("Captured ", label)
