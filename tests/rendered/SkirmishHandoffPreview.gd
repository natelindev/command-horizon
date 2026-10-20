extends "res://tests/headless/SkirmishHandoffRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Handoff preview timed out")
		quit(1)
	return false


func _run():
	attack_travel = load("res://source/match/units/actions/AttackMoving.gd")
	move_travel = load("res://source/match/units/actions/Moving.gd")
	metrics_probe = load("res://tests/headless/SkirmishCoordinationMetrics.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	for faction in ["bastion", "helix"]:
		await _fixture(faction, 1)
		game.simulation_time = 30
		await _arrival(actors[0], actors[2], false)
		await _arrival(actors[0], actors[2], true)
		await _archive_handoff(actors[0], actors[2])
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Rendered handoff: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review_handoff(unit):
	var human_player = game._get_human_player()
	_actor("Drone", human_player, unit.position + Vector3(0, 3, 3))
	game.battlefield.invalidate()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(30)
	camera.set_position_safely(unit.position + Vector3(3, 0, 0))
	paused = false
	await _frames(30)
	paused = true
	_check(game.battlefield.is_observed(human_player, unit), "Retired defender is not observed")
	_check(not is_instance_of(unit.action, attack_travel), "Rendered defender retained old route")
	var clock = game.simulation_time
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/coordination-handoff-%s.png" % opponent.faction
	)
	_check(game.simulation_time == clock, "Review advanced paused simulation")
	print(
		"HANDOFF CAPTURE ", opponent.faction, " position=", unit.position, " action=", unit.action
	)
