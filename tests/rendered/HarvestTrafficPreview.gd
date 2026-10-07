extends "res://tests/headless/HarvestTrafficRegression.gd"

var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Harvest traffic preview timed out")
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


func _review_traffic(label, watched, blocker):
	_check(paused, "Traffic review must preserve the paused scene")
	var clock = game.simulation_time
	# Spectator presentation changes neither gameplay observation nor actors.
	game.visible_player = watched.player
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(22)
	camera.set_position_safely(blocker.position + Vector3(0, 0, -2))
	root.get_node("MatchSignals").deselect_all_units.emit()
	watched.get_node("Selection").select()
	if game.hud.battle_plan._body.visible:
		game.hud.battle_plan._toggle_body()
	await _frames(12)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Traffic preview resolution changed")
	frame.save_png("res://docs/playtests/2026-10-05/harvest-traffic/" + label + ".png")
	_check(game.simulation_time == clock, "Traffic review advanced paused time")
	print("HARVEST CAPTURE ", label, " action=", watched.action, " cargo=", watched.resource_b)
