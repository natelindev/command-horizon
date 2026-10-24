extends "res://tests/rendered/StrategicPolishPreview.gd"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Placement feedback preview requires native rendering")
		quit(1)
		return
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for configuration in [
		["en", 1.0, Vector2i(1920, 1080), "1080-en"],
		["en", 1.5, Vector2i(1280, 720), "720-large-en"],
		["zh_CN", 1.5, Vector2i(1280, 720), "720-large-zh_CN"]
	]:
		options.restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"language": configuration[0],
				"interface_scale": configuration[1],
				"master_volume": 0.0
			}
		)
		await _first_orders()
		root.size = configuration[2]
		await _frames(10)
		var human = game._get_human_player()
		var handler = human.get_node("StructurePlacementHandler")
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(32)
		handler._start_structure_placement(load("res://source/match/units/CommandLab.tscn"))
		var event = InputEventMouseMotion.new()
		var headquarters = human.get_children().filter(
			func(unit): return "type" in unit and unit.type == "CommandCenter"
		)
		event.position = camera.unproject_position(headquarters[0].global_position)
		root.push_input(event, true)
		await _frames(10)
		_check(handler._feedback.visible, "Invalid placement reason is hidden")
		_check(handler._feedback.size.y < 100, "Placement reason panel is oversized")
		_check(
			root.get_texture().get_size() == Vector2(configuration[2]),
			"Unexpected placement capture size: " + configuration[3]
		)
		await _capture("placement-invalid-" + configuration[3])
		var cancel = InputEventMouseButton.new()
		cancel.position = event.position
		cancel.button_index = MOUSE_BUTTON_RIGHT
		cancel.pressed = true
		root.push_input(cancel, true)
		await _frames(3)
		_check(not handler._structure_placement_started(), "Pointer cancel did not close placement")
		_check(not handler._feedback.visible, "Pointer cancel left a placement reason")
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Placement preview: %d failures, %d captures" % [_errors.size(), _captures])
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
