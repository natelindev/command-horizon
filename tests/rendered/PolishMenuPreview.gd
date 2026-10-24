extends "res://tests/headless/MenuConsoleRegression.gd"

const OUTPUT = "res://art/polish-menus/"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	var temporary = "user://rendered-menu-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.get_node("SaveManager").autosaves_enabled = false
	for locale in ["en", "zh_CN"]:
		for scale in [1.0, 1.5]:
			options.restore(
				{"screen": 1, "menu_motion": false, "language": locale, "interface_scale": scale}
			)
			root.size = Vector2i(1280, 720)
			root.content_scale_size = root.size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			for page in ["Main", "Play", "Campaign"]:
				var menu = load("res://source/main-menu/" + page + ".tscn").instantiate()
				if page == "Play":
					menu.preferences_path = temporary + ".cfg"
				elif page == "Campaign":
					menu.progress_path = temporary + ".json"
				root.add_child(menu)
				current_scene = menu
				for faction in 3 if page != "Main" else 1:
					if page == "Play":
						menu._player_faction.select(faction)
						menu._update_faction(0, faction)
					elif page == "Campaign":
						menu._faction_picker.select(faction)
						menu._select_faction(faction)
					await _frames(8)
					if page != "Main":
						_check(
							root.get_visible_rect().encloses(menu._start_button.get_global_rect()),
							"Start button clipped: " + page
						)
					RenderingServer.force_draw(false)
					var label = "%s-%s-%.1f-%d" % [page, locale, scale, faction]
					root.get_texture().get_image().save_png(OUTPUT + label + ".png")
					print("Captured ", label)
				menu.queue_free()
				await _frames(3)
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Polish menus rendered: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
