extends "res://tests/headless/RepairActivityRegression.gd"


func _review_repair(depot, _worker, activity, visuals):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	game.fog_of_war.reveal()
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	camera.position = depot.position + Vector3(5, 5, -7)
	camera.look_at(depot.position + Vector3.UP)
	camera.make_current()
	var folder = "res://art/repair-activity/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for pose in 2:
		for frame in 15:
			activity.refresh(1.0 / 60.0)
			visuals._update_work(1.0 / 60.0, false)
			visuals._update_parts(1.0 / 60.0)
		await _frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "%s-%d.png" % [human.faction, pose])
	camera.queue_free()
