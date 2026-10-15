extends "res://tests/headless/Skirmish.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var settings = _settings("bastion", "helix", false)
	settings.visibility = settings.Visibility.FULL
	var game = await _start(settings)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.set_physics_process(false)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(9, 0, 26))
	camera.set_size_safely(12)
	await _frames(40)
	await _capture("resource-piles-field")
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	game.get_node("Map/Decorations").hide()
	for deposit in get_nodes_in_group("resource_units"):
		deposit.queue_free()
	await _frames(4)
	for row in 2:
		for column in 4:
			var deposit = (
				load(
					(
						"res://source/match/units/non-player/Resource%s.tscn"
						% ("A" if row == 0 else "B")
					)
				)
				. instantiate()
			)
			deposit.position = Vector3(25, 0, 22 + row * 3.5)
			deposit.set("resource_a" if row == 0 else "resource_b", [600, 300, 150, 60][column])
			game.map.get_node("Resources").add_child(deposit)
			deposit.position.x += column * 2.5
	camera.set_position_safely(Vector3(28.75, 0, 23.75))
	camera.set_size_safely(12)
	await _frames(90)
	var captions = CanvasLayer.new()
	root.add_child(captions)
	for column in 4:
		var point = camera.unproject_position(Vector3(25 + column * 2.5, 0, 22))
		_label(
			captions,
			["FULL HEAP", "OPENED", "SCATTERED", "REMNANTS"][column],
			point + Vector2(-75, -115),
			18
		)
		_label(
			captions, [">300", "151–300", "61–150", "1–60"][column], point + Vector2(-75, -88), 16
		)
	_label(
		captions, "MATERIALS", camera.unproject_position(Vector3(22.5, 0, 22)) + Vector2(-50, 0), 18
	)
	_label(
		captions,
		"ELECTRONICS",
		camera.unproject_position(Vector3(22.5, 0, 25.5)) + Vector2(-50, 0),
		18
	)
	await _frames(3)
	await _capture("resource-piles-stages")
	captions.queue_free()
	game.queue_free()
	await _frames(4)
	options.restore(original)
	quit()


func _capture(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/%s.png" % label)


func _label(parent, text_value, point, font_size):
	var label = Label.new()
	label.text = text_value
	label.position = point
	label.size = Vector2(150, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("544a3b"))
	parent.add_child(label)
