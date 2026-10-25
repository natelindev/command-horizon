extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.0, "language": "en"})
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		game.finished = true
		game.result = "Victory"
		game.simulation_time = 826
		game.battle_record.data.merge(
			{
				"forces_trained": 95,
				"engineers_trained": 42,
				"forces_lost": 53,
				"engineers_lost": 0,
				"structures_lost": 3,
				"foundations_lost": 1,
				"statistics":
				{
					"materials": 7741,
					"electronics": 2903,
					"structures_built": 17,
					"units_destroyed": 146,
					"structures_destroyed": 27
				}
			},
			true
		)
		for locale in ["en", "zh_CN"]:
			TranslationServer.set_locale(locale)
			for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(854, 480)]:
				root.mode = Window.MODE_WINDOWED
				root.size = dimensions
				root.content_scale_size = dimensions
				game.hud.show_result("Victory")
				await _frames(8)
				await _layout("%s-%s-%dx%d" % [faction, locale, dimensions.x, dimensions.y])
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Battle report layouts: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _layout(label):
	var overlay = game.hud._overlay
	var panel = overlay.find_child("ResultsPanel", true, false)
	var visible = root.get_visible_rect()
	_check(visible.encloses(panel.get_global_rect()), label + ": report outside viewport")
	_check(panel.size.x >= visible.size.x * .72, label + ": report too narrow")
	var buttons = overlay.find_children("*", "Button", true, false)
	_check(buttons.size() == 5, label + ": missing result actions")
	for button in buttons:
		_check(visible.encloses(button.get_global_rect()), label + ": action clipped")
		_check(button.icon != null, label + ": action missing icon")
	var statistics = overlay.find_child("Statistics", true, false)
	_check(statistics.get_child_count() == 4, label + ": missing statistic groups")
	var icons = statistics.find_children("*", "TextureRect", true, false)
	_check(icons.size() == 24, label + ": statistics lack icons")
	var scroll = overlay.find_child("ResultBodyScroll", true, false)
	_check(scroll.get_child(0).size.x <= scroll.size.x + 1, label + ": body overflows horizontally")
	var script = load("res://source/match/hud/SkirmishResults.gd")
	var roster = script.final_roster(game)
	_check(
		roster.engineers == _units(game._get_human_player(), "Worker").size(),
		"Final roster miscounts engineers"
	)
	_check(game.battle_record.data.forces_trained == 95, "Report changed battle counters")
	await _capture_layout(label)


func _capture_layout(_label):
	pass
