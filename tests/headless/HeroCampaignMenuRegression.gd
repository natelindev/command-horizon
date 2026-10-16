extends "res://tests/headless/MenuArtRegression.gd"


func _run():
	create_timer(180).timeout.connect(func(): quit(1))
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var options = root.get_node("Globals").options
	options.restore({"screen": 1, "menu_motion": false})
	var menu = load("res://source/main-menu/Campaign.tscn").instantiate()
	menu.progress_path = "user://no-campaign-menu-progress.json"
	root.add_child(menu)
	current_scene = menu
	for locale in ["en", "zh_CN"]:
		for scale in [1.0, 1.5]:
			options.language = locale
			options.interface_scale = scale
			options.apply()
			await _frames(5)
			for faction in 3:
				menu._select_faction(faction)
				for panel in menu._body.get_children():
					var housing = panel.get_theme_stylebox("panel")
					_check(
						housing.texture.resource_path.contains("/" + menu._faction + "/"),
						"Campaign housing retained another faction's texture"
					)
				for index in menu._ids.size():
					menu._select_operation(index)
					await _frames(2)
					_check(not menu._briefing.text.is_empty(), "Empty campaign briefing")
					_check(
						root.get_visible_rect().encloses(menu._start_button.get_global_rect()),
						"Start action clipped"
					)
					_check(
						menu._operation_buttons[index].focus_mode == Control.FOCUS_ALL,
						"Mission lacks keyboard focus"
					)
					_check(menu._difficulty.item_count == 3, "Missing mission difficulty")
				for control in menu.find_children("*", "Control", true, false):
					if (
						control.is_visible_in_tree()
						and not control is ScrollBar
						and not control is TextureRect
					):
						var rect = control.get_global_rect()
						_check(
							rect.end.x <= root.get_visible_rect().end.x + 1,
							"Campaign horizontal overflow: " + str(control.name)
						)
	menu.queue_free()
	await _frames(3)
	for error in errors:
		push_error(error)
	print("Hero campaign menu: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
