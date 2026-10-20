extends "res://tests/headless/HQCountdownRegression.gd"

var captures = ""


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var previous = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	options.restore(previous)


func _countdown_case(faction):
	if faction == "frontier":
		await super(faction)


func _outcome_case(_outcome):
	pass


func _review_countdown(label):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.hud.pause_after_load()
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(12)
	var command = game.hud.get_child(0)
	var minimap = game.get_node("HUD/MarginContainer/Minimap")
	_check(
		root.get_visible_rect().encloses(command.get_global_rect()),
		"HQ command panel leaves viewport"
	)
	_check(
		not command.get_global_rect().intersects(minimap.get_global_rect()),
		"HQ command panel covers minimap"
	)
	_check(game.hud._objective.text == game.objective_text(), "Rendered countdown is stale")
	if captures != "":
		await RenderingServer.frame_post_draw
		var path = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(path), "HQ capture already exists")
		if not FileAccess.file_exists(path):
			root.get_texture().get_image().save_png(path)
