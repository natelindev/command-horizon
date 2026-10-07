extends "res://tests/rendered/BattleAlertsPreview.gd"


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "subtitle_size": 26})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	await _setup("bastion")
	alerts = game.alerts
	panel = game.hud.alert_panel
	await _prepare_alerts()
	game.hud._toggle_pause()
	var clock = game.simulation_time
	var opened = false
	var navigated = false
	var cleared = false
	print("NATIVE ALERTS READY: open Alerts, Show a unit alert, reopen, Clear history, Escape.")
	var until = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < until:
		await process_frame
		if panel.panel.visible:
			opened = true
		if (
			opened
			and not panel.panel.visible
			and not get_nodes_in_group("selected_units").is_empty()
		):
			navigated = true
		if navigated and _kind("loss").is_empty():
			cleared = true
		if cleared and not panel.panel.visible:
			break
	_check(opened and navigated and cleared, "Native alert flow was not completed")
	_check(paused and game.simulation_time == clock, "Native alert flow changed battle pause")
	_check(game.hud._overlay == null, "Native Escape opened the battle menu")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/skirmish/alerts-native-720p.png")
	await _clean_match()
	manager.autosaves_enabled = autosaves
	preferences.restore(original)
	print("Native battle alerts: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
