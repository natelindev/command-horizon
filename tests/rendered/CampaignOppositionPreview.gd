extends "res://tests/headless/CampaignOppositionRegression.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var previous = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.0, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	path = "user://opposition-preview-%d.json" % OS.get_process_id()
	await _make_match()
	game.get_node("CampaignStory").skip_briefing()
	paused = false
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.fog_of_war.reveal()
	game.opposition.activate()
	game.get_node("CampaignStory")._clear()
	var boss = game.opposition.boss
	var target = game._spawn("Tank", game._get_human_player(), boss.position + Vector3(-5, 0, 0))
	target.process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("IsometricCamera3D").set_position_safely(boss.position + Vector3(-3, 0, 0))
	await _frames(45)
	game.opposition.salvo_left = 0
	game.opposition._step_boss(.1)
	paused = true
	await create_timer(.3, true).timeout
	await RenderingServer.frame_post_draw
	var panel = game.hud.objective_panel.get_global_rect()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel), "Boss objective panel clips")
	_check(
		panel.end.y < game.find_child("Minimap").get_global_rect().position.y,
		"Boss objective overlaps minimap"
	)
	var frame = root.get_texture().get_image()
	frame.save_png("/tmp/rts-opposition-preview.png")
	await _close()
	options.restore(previous)
	for message in errors:
		push_error(message)
	print("Campaign opposition preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
