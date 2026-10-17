extends "res://tests/headless/WorkerDistributionRegression.gd"

const OUTPUT = "res://art/worker-distribution/"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "day_cycle": false, "weather": 1, "language": "en"})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await super()
	options.restore(original)


func _review_distribution(faction, kind):
	paused = true
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.hud.hide()
	game.subtitles.hide()
	root.get_node("MatchSignals").deselect_all_units.emit()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(18)
	camera.set_position_safely(Vector3(12, 0, 18))
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + faction + "-" + kind + ".png")
	paused = false
