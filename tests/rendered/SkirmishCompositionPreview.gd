extends "res://tests/headless/SkirmishCompositionRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 420000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI composition preview timed out")
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


func _review_counter(unit):
	var outward = (unit.global_position_yless - factory.global_position_yless).normalized()
	if outward.length() < 0.5:
		outward = Vector3(0, 0, -1)
	var scout = _actor("Drone", game._get_human_player(), unit.global_position_yless + outward * 8)
	await _frames(30)
	game.hud._toggle_pause()
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	scout.get_node("Selection").select()
	var plan = game.hud.battle_plan
	if plan._body.visible:
		plan._toggle_body()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(unit.global_position_yless + Vector3(8, 0, 0))
	await _frames(10)
	_check(
		game.battlefield.is_observed(scout.player, unit),
		"Newly produced counter hidden from preview scout"
	)
	_check(unit.type == "CombatRobot" and unit.hp > 0, "Preview counter invalid")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Composition preview resolution changed")
	frame.save_png("res://art/skirmish/ai-composition-%s-counter.png" % opponent.faction)
	_check(game.simulation_time == clock, "Composition preview advanced paused time")
	print("COMPOSITION CAPTURE ", opponent.faction)
	scout.queue_free()
	game.hud._toggle_pause()
	await _frames(5)
