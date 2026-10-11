extends "res://tests/headless/AlliedDefenseStatisticsRegression.gd"

var capture_dir = "res://tmp/frontier-refinement"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var initial = options.capture()
	options.restore(
		{"screen": 1, "interface_scale": 1.0, "edge_scrolling": false, "language": "en"}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await _skirmish("frontier", "res://source/match/maps/DesertFrontier.tscn", true)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	game.hud.pause_after_load()
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(31)
	camera.set_position_safely(Vector3(23, 0, 27))
	var owner = game._get_human_player()
	var barracks = _units(owner, "Barracks")[0]
	barracks.get_node("Selection").select()
	var rally = barracks.get_node("RallyPoint")
	rally.global_position = barracks.global_position + Vector3(7, 0, 1)
	await _shot("frontier-rally-wide")
	camera.set_size_safely(20)
	camera.set_position_safely(barracks.global_position + Vector3(3, 0, 0))
	await _shot("frontier-rally-close")
	game.hud.hide()
	game.get_node("HUD").hide()
	game.subtitles.hide()
	await _shot("frontier-rally-detail")
	var worker = _units(owner, "Worker")[0]
	rally.target_unit = worker
	worker.position += Vector3(2, 0, 0)
	await _shot("frontier-rally-moving-target")
	_check(rally.visible, "Target rally marker is hidden")
	root.get_node("MatchSignals").deselect_all_units.emit()
	camera.set_size_safely(20)
	camera.set_position_safely(Vector3(12, 0, 13))
	# Place all four authored variants together for a silhouette and leaf-detail review.
	for index in 4:
		var tree = (
			load("res://assets/models/environment/desert/%s.glb" % game.map.TREES[index])
			. instantiate()
		)
		tree.position = Vector3(6 + index * 4, 0, 14)
		game.map.add_child(tree)
	await _shot("desert-tree-variants")
	game.hud.show()
	game.get_node("HUD").show()
	game.subtitles.show()
	await _defense()
	await _statistics()
	await _shot("victory-statistics")
	game.result = "Defeat"
	game.hud.show_result(game.result)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	options.interface_scale = 1.5
	options.apply()
	await _shot("defeat-statistics-150")
	var labels = game.hud._overlay.find_children("*", "Button", true, false)
	for button in labels:
		_check(
			root.get_visible_rect().encloses(button.get_global_rect()),
			"Result button clipped: " + button.text
		)
	paused = false
	game.queue_free()
	await _frames(3)
	options.restore(initial)
	for error in errors:
		push_error(error)
	print("Frontier refinement rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))
