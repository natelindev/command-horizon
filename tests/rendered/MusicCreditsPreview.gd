extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1})
	await create_timer(.5).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for language in ["en", "zh_CN"]:
		preferences.language = language
		preferences.apply()
		var scene = load("res://source/main-menu/Credits.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		await create_timer(.5).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(
			"res://tmp/music/previews/credits-" + language + ".png"
		)
		var label = scene.find_child("RichTextLabel")
		label.get_v_scroll_bar().value = label.get_v_scroll_bar().max_value
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(
			"res://tmp/music/previews/credits-" + language + "-bottom.png"
		)
		scene.queue_free()
		await process_frame
	preferences.restore(original)
	print("Music credits preview complete")
	quit()
