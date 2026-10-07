extends "res://tests/headless/SkirmishExpansionRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 420000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI expansion preview timed out")
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


func _review_expansion(player, field, label):
	# Reconnaissance is staged only for this review; the opponent's guard,
	# gathering and offensive orders remain the actual regression result.
	var human = game._get_human_player()
	# The archive harness defaults both players to blue; show the ordinary
	# skirmish setup's gold/red team colors in these review captures.
	human.color = Color("e0ad46")
	player.color = Color("d86965")
	human.get_color_material().albedo_color = human.color
	player.get_color_material().albedo_color = player.color
	var scout = load(catalog.scene_path("Drone")).instantiate()
	game._setup_and_spawn_unit(
		scout, Transform3D(Basis(), field.position + Vector3(4, 2, 4)), human, false
	)
	scout.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	game.hud._toggle_pause()
	await _frames(30)
	game.hud._toggle_pause()
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	scout.get_node("Selection").select()
	var panel = game.hud.battle_plan
	if panel._body.visible:
		panel._toggle_body()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(field.position + Vector3(8, 0, 0))
	await _frames(10)
	var guards = economy.guards(player._units()).filter(
		func(unit): return unit.position.distance_to(field.position) < 10
	)
	_check(not guards.is_empty(), "No expansion guard in rendered review")
	_check(
		guards.any(func(unit): return game.battlefield.is_observed(human, unit)),
		"Expansion guard hidden in rendered review"
	)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Expansion preview resolution changed")
	frame.save_png("res://art/skirmish/ai-expansion-%s.png" % label)
	_check(game.simulation_time == clock, "Expansion preview advanced paused time")
	print("EXPANSION CAPTURE ", label)
