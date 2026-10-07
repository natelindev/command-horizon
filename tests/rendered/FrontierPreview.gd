extends "res://tests/headless/FrontierRegression.gd"


func _run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _frontier_menu()
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, FRONTIER)
		_enemy().set_process(false)
		var human = game._get_human_player()
		for index in 6:
			_spawn_alpine("Tank", human, Vector3(59 + (index % 3) * 4, 0, 45 + (index / 3) * 5))
		await _frames(20)
		await _frontier_capture("frontier-overview-%s" % faction, Vector3(64, 0, 48), 102)
		await _frontier_capture("frontier-staging-%s" % faction, Vector3(64, 0, 48), 34)
		game.queue_free()
		await _frames(5)
	print("Frontier visual review: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
