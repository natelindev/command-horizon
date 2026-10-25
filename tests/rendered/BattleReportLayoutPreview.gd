extends "res://tests/headless/BattleReportLayoutRegression.gd"


func _capture_layout(label):
	var folder = "res://art/battle-report/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + label + ".png")
	# Also inspect the lower statistics at the smallest supported logical size.
	var scroll = game.hud._overlay.find_child("ResultBodyScroll", true, false)
	if label.ends_with("854x480"):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + label + "-lower.png")
