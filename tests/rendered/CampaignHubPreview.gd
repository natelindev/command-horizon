extends "res://tests/headless/CampaignHubRegression.gd"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("CampaignHubPreview requires a renderer")
		quit(1)
		return
	await _open_hub()
	await _verify_hub()
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var directory = "res://art/campaign-hubs"
	DirAccess.make_dir_recursive_absolute(directory)
	for locale in ["en", "zh_CN"]:
		root.get_node("Globals").options.language = locale
		root.get_node("Globals").options.apply()
		for faction in 3:
			hub._select_faction(faction)
			for station in 3:
				hub._open_station(station)
				await _frames(40)
				await RenderingServer.frame_post_draw
				var capture = root.get_texture().get_image()
				_check(capture.get_size() == Vector2i(1280, 720), "Hub capture is not actual720p")
				capture.save_png(
					directory + "/%s-%s-station%d.png" % [hub.faction, locale, station]
				)
			var briefing = load("res://source/match/campaign/CampaignBriefing.tscn").instantiate()
			root.add_child(briefing)
			briefing.configure(hub.Catalog.ORDER[hub.faction][0])
			briefing.caption.set_line(
				"Command",
				tr("Secondary objective: return your hero with at least half hull intact."),
				18
			)
			briefing.caption.set_caption_visible(true)
			briefing.seek(23)
			await _frames(10)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				directory + "/%s-%s-briefing.png" % [hub.faction, locale]
			)
			briefing.queue_free()
			await _frames(3)
	await _cleanup_hub()
	for message in errors:
		push_error(message)
	print("Campaign hub preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
