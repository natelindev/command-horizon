extends "res://tests/headless/SkirmishMatrix.gd"

var captured = {}
var next_camera = 0.0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 1500000
	_run.call_deferred()


func _run():
	repair_order = load("res://source/match/units/actions/Repairing.gd")
	plan_rules = load("res://tests/UnitQueries.gd")
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	construct_action = load("res://source/match/units/actions/Constructing.gd")
	attack_move_action = load("res://source/match/units/actions/AttackMoving.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	root.get_node("MatchSignals").unit_spawned.connect(_track_unit)
	root.get_node("MatchSignals").unit_destroying.connect(_loss)
	output_path = "res://docs/playtests/2026-10-03/skirmish-normal-clock.json"
	await _play_case(0)
	manager.autosaves_enabled = autosaves
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Normal-clock complete skirmish: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _measure():
	super()
	if game.simulation_time >= next_camera:
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(35)
		var point = defense_point
		if _launched:
			var army = plan_rules.army(human)
			if not army.is_empty():
				point = army[0].global_position_yless
		camera.set_position_safely(point + Vector3(-4, 0, 0))
		next_camera = game.simulation_time + 4
	for event in ["first_contact", "first_guard", "first_assault", "expansion_return"]:
		if metrics[event] != null and not captured.has(event):
			captured[event] = true
			RenderingServer.frame_post_draw.connect(_capture.bind(event), CONNECT_ONE_SHOT)
	if not captured.has("opening"):
		captured.opening = true
		RenderingServer.frame_post_draw.connect(_capture.bind("opening"), CONNECT_ONE_SHOT)


func _review_match_end():
	await _frames(10)
	await RenderingServer.frame_post_draw
	_capture("result")
	return true


func _capture(event):
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == root.size, "Normal-clock match image resolution changed")
	frame.save_png("res://art/skirmish/matrix-normal-%s.png" % event)
	print("CAPTURE: ", event, " at ", game.simulation_time)
