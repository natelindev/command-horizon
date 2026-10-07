extends "res://tests/rendered/SupplyLinePreview.gd"


func _run():
	path = "user://horizon-challenge-native-%d.json" % OS.get_process_id()
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Progress.new().record_horizon_victory("", path)
	var menu = load("res://source/main-menu/Campaign.tscn").instantiate()
	menu.progress_path = path
	root.add_child(menu)
	current_scene = menu
	menu._select_operation(5)
	await _frames(5)
	menu._challenge.item_selected.connect(func(index): print("NATIVE CHALLENGE selected=", index))
	print("NATIVE CHALLENGE ready")
	while current_scene == menu:
		await process_frame
	game = current_scene
	while not is_instance_valid(game) or not "deployed" in game:
		await process_frame
		game = current_scene
	game.progress_path = path
	await _frames(60)
	print(
		"NATIVE CHALLENGE launched=",
		game.settings.campaign_challenge,
		" tanks=",
		(
			game
			. _get_human_player()
			. get_children()
			. filter(func(unit): return unit.is_in_group("units") and unit.type == "Tank")
			. size()
		)
	)
	_check(
		game.settings.campaign_challenge == "lean",
		"Native selection did not launch Lean deployment"
	)
	await _capture("horizon-native-lean-720p")
	game.queue_free()
	await _frames(3)
	options.restore(original)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Command Horizon native challenge: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
