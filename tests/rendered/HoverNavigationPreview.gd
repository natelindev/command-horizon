extends "res://tests/headless/HoverNavigationRegression.gd"


func _inspect_hover(worker, label):
	if DisplayServer.get_name() == "headless":
		push_error("HoverNavigationPreview requires a renderer")
		return
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_size_safely(12)
	camera.set_position_safely(worker.global_position)
	_game.hud.select_units([worker])
	_game.fog_of_war._physics_process(0)
	await _frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/hover-navigation")
	root.get_texture().get_image().save_png("res://art/hover-navigation/%s.png" % label)
