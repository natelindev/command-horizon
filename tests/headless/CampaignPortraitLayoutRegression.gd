extends "res://tests/headless/SubtitleLayoutRegression.gd"

const Narration = preload("res://source/match/campaign/CampaignNarration.gd")


func _run():
	options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "subtitle_size": 26})
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		paused = true
		game._get_human_player().get_node("BattleVoice").set_process(false)
		for locale in ["en", "zh_CN"]:
			var actors = _longest_lines(locale)
			_check(actors.size() == 13, "Installed story portraits are incomplete")
			for scale in [1.0, 1.5]:
				for captions in [false, true]:
					options.language = locale
					options.interface_scale = scale
					options.subtitles = captions
					options.apply()
					for line in actors.values():
						label = "%s %s %s %s" % [faction, locale, scale, line.speaker]
						game.subtitles._on_line(line)
						await _frames(4)
						_clearance()
						var card = game.subtitles._card
						_check(card._portrait.visible, label + " lost its portrait")
						_check(
							card._text.visible == captions, label + " ignored caption preference"
						)
		game.queue_free()
		await _frames(5)
	paused = false
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Campaign portrait layout: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _longest_lines(locale):
	var actors = {}
	for cue in Narration.lines():
		for line in Narration.scene(cue, locale):
			if line.get("portrait", "").is_empty():
				continue
			if (
				not actors.has(line.portrait)
				or line.text.length() > actors[line.portrait].text.length()
			):
				actors[line.portrait] = line
	return actors
