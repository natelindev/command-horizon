extends "res://tests/headless/ConstructionContractRegression.gd"

var captures = ""
var clicks = 0


func _run():
	Engine.max_fps = 60
	factions = ["helix"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	preferences.restore(original)


func _review_contract(stage):
	await super(stage)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(24)
	camera.set_position_safely(foundation.global_position_yless + Vector3(3, 0, 0))
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	var button = menus._stop_button
	_check(menus.get_global_rect().encloses(button.get_global_rect()), "Cancel button clipped")
	if captures != "":
		var motion = InputEventMouseMotion.new()
		motion.position = Vector2(650, 550)
		root.push_input(motion, false)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		_check(picture.get_size() == Vector2i(1280, 720), "Construction capture size changed")
		var file = captures + "-" + stage + ".png"
		_check(not FileAccess.file_exists(file), "Construction capture would overwrite evidence")
		if not FileAccess.file_exists(file):
			picture.save_png(file)


func _cancel_site(_site):
	var button = game.find_child("UnitMenus")._stop_button
	var pixel = root.get_final_transform() * button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = pixel
	motion.global_position = pixel
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pixel
		event.global_position = pixel
		root.push_input(event, false)
		await _frames(2)
	clicks += 1
	print("CONSTRUCTION CANCEL CLICK ", clicks)
