extends "res://tests/headless/OpeningArmorRegression.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	tank_scene = load("res://source/match/units/Tank.tscn")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in ["bastion", "helix"]:
		await _fixture(faction)
		await _conventional(faction)
		await _lab(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Opening armor UI: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review(label):
	# Match startup applies saved display options; enforce the review viewport afterward.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Opening armor review resolution changed")
	frame.save_png("res://art/skirmish/opening-armor-%s.png" % label)
	print("OPENING CAPTURE ", label)
	return true
