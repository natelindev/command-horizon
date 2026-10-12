extends "res://tests/headless/InfantryMotionRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-11/infantry-motion-ranges/"


func _run():
	Factions = load("res://source/match/FactionCatalog.gd")
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"day_cycle": false, "time_of_day": 0, "weather": 1})
	for faction in Factions.IDS:
		await _fixture(faction)
		game.fog_of_war.reveal()
		game.find_child("Minimap", true, false).set_physics_process(false)
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
			layer.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = Camera3D.new()
		game.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7.5
		camera.position = Vector3(43.0, 3.3, 17)
		camera.look_at(Vector3(43, .6, 10))
		camera.make_current()
		var soldiers = []
		for index in range(Roster.INFANTRY_ROLES.size()):
			var unit = _soldier(
				Roster.INFANTRY_ROLES[index], human, Vector3(40 + index * 1.5, 0, 10)
			)
			unit.rotation.y = PI - .25
			var label = Label3D.new()
			label.text = Roster.INFANTRY_ROLES[index].replace("Infantry", "")
			if label.text == "":
				label.text = "Rifle"
			label.font_size = 32
			label.pixel_size = .003
			label.position.y = 1.65
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			unit.add_child(label)
			soldiers.append(unit)
		await _frames(12)
		await _capture_pose(faction + "-idle")
		for frame in range(90):
			for unit in soldiers:
				var visual = unit.get_node("BastionVisuals")
				visual._infantry_motion.advance(1.0 / 30.0, 2.4 / 30.0, frame / 30.0, 0.0, 0.0, 0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			if faction == "bastion":
				root.get_texture().get_image().save_png(OUTPUT + "motion-%03d.png" % frame)
			if frame == 16:
				root.get_texture().get_image().save_png(OUTPUT + faction + "-stride.png")
		await _close()
	preferences.restore(original)
	print("Infantry motion preview complete")
	quit()


func _capture_pose(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
