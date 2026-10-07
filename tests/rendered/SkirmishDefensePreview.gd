extends "res://tests/headless/SkirmishDefenseRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("AI defense preview timed out")
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


func _review(label):
	_check(is_instance_valid(raider), "Defense preview raider already destroyed")
	if not is_instance_valid(raider):
		return
	game.hud._toggle_pause()
	var clock = game.simulation_time
	root.get_node("MatchSignals").deselect_all_units.emit()
	raider.get_node("Selection").select()
	var plan = game.hud.battle_plan
	if plan._body.visible:
		plan._toggle_body()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(26)
	camera.set_position_safely(Vector3(88, 0, 10))
	await _frames(10)
	var responders = [counter] if label == "air-response" else defenders
	for unit in responders:
		_check(
			game.battlefield.is_observed(raider.player, unit), "Responding unit hidden in preview"
		)
		_check(unit.hp > 0, "Preview responder is dead")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "AI defense preview resolution changed")
	frame.save_png("res://art/skirmish/ai-defense-%s-%s.png" % [opponent.faction, label])
	_check(game.simulation_time == clock, "Defense preview advanced paused time")
	print("DEFENSE CAPTURE ", opponent.faction, " ", label)
	game.hud._toggle_pause()
