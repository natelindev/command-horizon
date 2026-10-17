extends "res://tests/headless/HeroCampaignRegression.gd"

const OUTPUT = "res://art/hero-campaigns/"


func _run():
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "language": "en", "subtitles": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	path = "user://rendered-hero-%d.json" % OS.get_process_id()
	for faction in Campaigns.ORDER:
		for id in Campaigns.ORDER[faction]:
			paused = false
			options.language = "en"
			options.interface_scale = 1.0
			options.apply()
			await _make_operation(id)
			var story = game.campaign_story
			_check(story.cinematic and paused, "Missing rendered opening: " + id)
			await _shot(id + "-intro")
			_check(
				(
					story._subtitle._text.is_visible_in_tree()
					and not story._subtitle._text.text.is_empty()
				),
				"Default settings hid English dialogue: " + id
			)
			options.language = "zh_CN"
			options.interface_scale = 1.5
			options.subtitle_size = 26
			options.apply()
			await _shot(id + "-intro-zh")
			_check(
				(
					story._subtitle._text.is_visible_in_tree()
					and not story._subtitle._text.text.is_empty()
				),
				"Default settings hid Chinese dialogue: " + id
			)
			_check(
				root.get_visible_rect().encloses(story._briefing.get_global_rect()),
				"Briefing clipped: " + id
			)
			story.skip_briefing()
			_check(not story.cinematic and not paused, "Skip failed: " + id)
			options.language = "en"
			options.interface_scale = 1.0
			options.apply()
			game.set_physics_process(true)
			var camera = game.get_node("IsometricCamera3D")
			camera.set_position_safely(game.campaign_hero.unit.global_position)
			camera.set_size_safely(30)
			await _frames(20)
			_check(
				(
					not game.hud._assignment_hint.visible
					or game.hud._assignment_hint.text != game.objective_text()
				),
				"Objective duplicated in notice: " + id
			)
			print("Interior ", id, " buildings=", game.map.interior_obstacles.size())
			await _shot(id + "-battle")
			# Keep this caption fixture free of urgent combat reports, which correctly
			# interrupt narration and have their own headless regression coverage.
			for side in get_nodes_in_group("players"):
				side.set_process(false)
			for unit in get_nodes_in_group("units"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
			if story._voice != null:
				story._voice._clear()
			story._play(id + ".intro")
			await _shot(id + "-dialogue")
			var card = game.get_node("CampaignSubtitles")._card
			_check(
				card._text.is_visible_in_tree() and not card._text.text.is_empty(),
				"Battle dialogue has no English captions: " + id
			)
			options.language = "zh_CN"
			options.interface_scale = 1.5
			options.apply()
			await _shot(id + "-dialogue-zh")
			_check(
				card._text.is_visible_in_tree() and not card._text.text.is_empty(),
				"Battle dialogue has no Chinese captions: " + id
			)
			_check(
				root.get_visible_rect().encloses(card.get_global_rect()),
				"Battle captions clipped: " + id
			)
			story.skip_dialogue()
			options.language = "en"
			options.interface_scale = 1.0
			options.apply()
			game.settings.visibility = game.settings.Visibility.FULL
			game.fog_of_war.reveal()
			camera.size_max = 190
			camera.set_size_safely(80)
			camera.set_position_safely(Vector3(game.map.size.x / 2, 0, game.map.size.y / 2))
			for layer in game.find_children("*", "CanvasLayer", true, false):
				layer.hide()
			await _shot(id + "-environment")
			game.queue_free()
			await _frames(5)
	paused = false
	options.restore(original)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Hero campaigns rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	await _frames(5)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
