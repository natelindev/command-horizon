extends SceneTree

const Console = preload("res://source/match/hud/BattleTheme.gd")
var _errors = []


func _initialize():
	_run.call_deferred()


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	var preferences = "user://menu-console-%d.cfg" % OS.get_process_id()
	for locale in ["en", "zh_CN"]:
		for scale in [1.0, 1.5]:
			options.restore(
				{"screen": 1, "menu_motion": false, "language": locale, "interface_scale": scale}
			)
			root.size = Vector2i(1280, 720)
			for path in ["Main", "Play"]:
				var menu = load("res://source/main-menu/" + path + ".tscn").instantiate()
				if path == "Play":
					menu.preferences_path = preferences
				root.add_child(menu)
				await _frames(6)
				var bounds = root.get_visible_rect()
				for button in menu.find_children("*", "BaseButton", true, false):
					if not button.is_visible_in_tree():
						continue
					var rect = button.get_global_rect()
					_check(
						rect.position.x >= 0 and rect.end.x <= bounds.end.x + 1,
						"%s/%s/%s: horizontal overflow: %s" % [path, locale, scale, button.name]
					)
					_check(
						button.focus_mode == Control.FOCUS_ALL,
						"Menu action is not keyboard focusable: " + str(button.name)
					)
				if path == "Play":
					_check(
						bounds.encloses(menu._start_button.get_global_rect()),
						"Start battle is outside the viewport"
					)
					for index in 3:
						menu._player_faction.select(index)
						menu._update_faction(0, index)
						_check(
							menu.theme == Console.create(),
							"Faction selector failed to apply console theme"
						)
						menu._difficulty.select(index)
						menu._update_summary()
						_check(
							menu._create_match_settings().players[1].difficulty == index,
							"Picker lost AI difficulty"
						)
					menu._save_preferences()
				menu.queue_free()
				await _frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences))
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Menu console: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _frames(count):
	for index in count:
		await process_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
