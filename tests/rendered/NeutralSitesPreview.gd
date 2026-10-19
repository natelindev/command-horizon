extends "res://tests/headless/PointOfInterestRegression.gd"

const OUTPUT = "res://art/neutral-sites/"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"interface_scale": 1.0,
			"day_cycle": false,
			"time_of_day": 0,
			"weather": 1
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await _open_sites("bastion")
	_game.fog_of_war.reveal()
	for layer in _game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var refinery = _game.map.points_of_interest[0]
	var soldier = _spawn("Infantry", _human, refinery.position + Vector3(3.8, 0, 0))
	await _frames(5)
	_claim(refinery, soldier, _human)
	refinery._physics_process(.4)
	await _capture("refinery-producing-a", refinery.position, 15)
	refinery._physics_process(.7)
	await _capture("refinery-producing-b", refinery.position, 15)
	var origin = Vector3(44, 0, 92)
	var roles = load("res://source/match/world/MercenaryCatalog.gd").ROLES
	for index in roles.size():
		var unit = _spawn(roles[index], _human, origin + Vector3(index * 3 - 3, 0, 0))
		unit.rotation.y = PI
		var label = Label3D.new()
		label.text = load("res://source/match/FactionCatalog.gd").title("bastion", roles[index])
		label.position.y = 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = .01
		unit.add_child(label)
	await _capture("mercenary-specialists", origin, 11)
	var row = _game.map.get_node("Resources").get_children().slice(0, 7)
	await _capture("resource-arc", row[2].position, 32)
	_game.queue_free()
	await _frames(5)
	options.restore(original)
	print("Neutral-site visual captures complete")
	quit()


func _capture(label, point, size):
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_position_safely(point)
	camera.set_size_safely(size)
	await _frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
