extends SceneTree

const OUTPUT = "res://art/compact-setup/"
var _errors = []
var _setup_scene


func _initialize():
	_run.call_deferred()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Compact setup review requires a renderer")
		quit(1)
		return
	Engine.max_fps = 60
	_setup_scene = load("res://source/main-menu/Play.tscn")
	var options = root.get_node("Globals").options
	var original = options.capture()
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var launch_only = "--launch-only" in OS.get_cmdline_user_args()
	for language in [] if launch_only else ["en", "zh_CN"]:
		for scale_value in [1.0, 1.25, 1.5]:
			options.restore({"screen": 1, "interface_scale": scale_value, "language": language})
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			root.content_scale_size = Vector2i(1920, 1080)
			await create_timer(.3).timeout
			var menu = _setup_scene.instantiate()
			menu.preferences_path = "user://compact-setup-preview-%d.cfg" % OS.get_process_id()
			root.add_child(menu)
			current_scene = menu
			for map_index in [0, 9]:
				menu._map_list.select(map_index)
				menu._on_map_list_item_selected(map_index)
				if menu._slots.size() == 4:
					menu._game_mode.select(1)
					menu._apply_teams(1)
				for frame in 12:
					await process_frame
				var label = "%s-%d-%d" % [language, roundi(scale_value * 100), menu._slots.size()]
				print(
					"SETUP ",
					label,
					" logical=",
					menu.size,
					" minimum=",
					menu.get_combined_minimum_size()
				)
				_check_controls(menu, Rect2(Vector2.ZERO, menu.size), label)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT + label + ".png")
			menu.queue_free()
			for frame in 4:
				await process_frame
	if launch_only or "--launch" in OS.get_cmdline_user_args():
		await _launch_battle(options)
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Compact setup rendered layout: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _launch_battle(options):
	options.restore(
		{"screen": 1, "interface_scale": 1.5, "language": "en", "edge_scrolling": false}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	var menu = _setup_scene.instantiate()
	var preferences_path = "user://compact-launch-%d.cfg" % OS.get_process_id()
	menu.preferences_path = preferences_path
	root.add_child(menu)
	current_scene = menu
	menu._start_mode.select(1)
	menu._enemy_faction.select(1)
	menu._select_start(0, 1)
	for frame in 12:
		await process_frame
	# Use the real button/input/loading path; do not instantiate a match fixture.
	var point = menu._start_button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await process_frame
	var deadline = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("_get_human_player"):
			break
	if not is_instance_valid(current_scene) or not current_scene.has_method("_get_human_player"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + "launch-failure.png")
		_errors.append("Start Battle did not reach a rendered skirmish")
		return
	var game = current_scene
	var human = game._get_human_player()
	if not game.settings.advanced_start or human.start_index() != 1:
		_errors.append("Rendered battle lost starting force or map position choices")
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "launched-battle.png")
	print(
		"LAUNCH rendered skirmish time=",
		game.simulation_time,
		" player_start=",
		human.start_index()
	)
	game.queue_free()
	for frame in 6:
		await process_frame
	DirAccess.remove_absolute(preferences_path)


func _check_controls(node, bounds, label):
	if node is Control and node.is_visible_in_tree():
		if node is BaseButton or node is Label:
			var rect = node.get_global_rect()
			if not bounds.grow(1).encloses(rect):
				_errors.append("%s: %s outside screen: %s" % [label, node.name, rect])
		if node is ScrollContainer:
			_errors.append("%s: setup still needs a scroll container" % label)
	for child in node.get_children():
		_check_controls(child, bounds, label)
