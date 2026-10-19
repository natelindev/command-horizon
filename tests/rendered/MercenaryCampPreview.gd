extends "res://tests/headless/PointOfInterestRegression.gd"

const OUTPUT = "res://art/neutral-sites/"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "interface_scale": 1.0})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for locale in ["en", "zh_CN"]:
		options.restore({"language": locale})
		for faction in ["bastion", "helix", "frontier"]:
			await _open_sites(faction)
			var camp = _game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")[0]
			var soldier = _spawn("Infantry", _human, camp.position + Vector3(3.8, 0, 0))
			await _frames(5)
			_claim(camp, soldier, _human)
			_human.resource_a = 5000
			_human.resource_b = 5000
			_game.fog_of_war._physics_process(0)
			var camera = _game.get_node("IsometricCamera3D")
			camera.set_position_safely(camp.global_position)
			camera.set_size_safely(30)
			await _frames(10)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + locale + "-" + faction + "-before.png")
			await _click(camera.unproject_position(camp.global_position + Vector3.UP * 2))
			var menu = _game.find_child("UnitMenus")
			_check(menu._camp == camp, faction + ": click did not open production console")
			if menu._camp == camp:
				await _click(menu._camp_buttons[0].button.get_global_rect().get_center())
				_check(camp.jobs.size() == 1, faction + ": clicking roster did not queue recruit")
				camp._physics_process(4)
				await _frames(10)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT + locale + "-" + faction + ".png")
				_game.hud._toggle_pause()
				await _click(menu._camp_buttons[1].button.get_global_rect().get_center())
				_check(camp.jobs.size() == 2, faction + ": tactical pause blocked recruitment")
				_game.hud._toggle_pause()

			paused = false
			_game.queue_free()
			await _frames(5)
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Rendered mercenary camps: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _click(point):
	point = root.get_final_transform() * point
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, false)
	await _frames(2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, false)
		await _frames(3)
