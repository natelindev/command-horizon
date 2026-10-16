extends "res://tests/headless/CampaignStoryRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore(
		{"screen": 1, "edge_scrolling": false, "subtitles": false}
	)
	path = "user://dialogue-%d.json" % OS.get_process_id()
	var original = Narration.lines()["first_orders.intro"].duplicate(true)
	# Exercise real ordered recordings without shipping unvoiced story drafts.
	Narration.lines()["first_orders.intro"] = {
		"dialogue":
		[
			_line(
				"first_orders.intro.aegis",
				"Marshal Aegis",
				"埃吉斯元帅",
				"We hold here.",
				"我们坚守这里。",
				"first_orders_intro_en.wav",
				"bastion"
			),
			_line(
				"first_orders.intro.nyx",
				"Spectre Nyx",
				"幽影·尼克斯",
				"Then listen.",
				"那就听着。",
				"first_orders_lab_en.wav",
				"helix"
			)
		]
	}
	await _make_match()
	var story = game.campaign_story
	_check(story.current.id == "first_orders.intro.aegis", "First speaker did not start")
	var card = game.get_node("CampaignSubtitles")._card
	_check(card.visible and card._portrait.visible, "Captions off hid the speaking character")
	_check(not card._text.visible, "Battle dialogue ignored captions off")
	story._remaining = 0
	await _frames(1)
	_check(story.current.id == "first_orders.intro.nyx", "Conversation did not advance")
	var stream = story._audio.stream
	var left = story._remaining
	root.get_node("Globals").options.language = "zh_CN"
	story._refresh_language()
	_check(story.current.speaker == "幽影·尼克斯", "Speaker name did not localize")
	_check(story.current.text == "那就听着。", "Dialogue text did not localize")
	_check(
		story._audio.stream == stream and story._remaining == left, "Locale restarted English VO"
	)
	_check(story.cue("first_orders.lab"), "Reply cue was not queued")
	paused = true
	await _frames(3)
	_check(story._remaining == left, "Tactical pause consumed a conversation")
	await _resume_from_disk()
	story = game.campaign_story
	_check(story._resume.line == "first_orders.intro.nyx", "Load lost current speaker")
	_check(story._pending == ["first_orders.lab"], "Load lost queued scene")
	paused = false
	await _frames(2)
	_check(story.current.id == "first_orders.intro.nyx", "Load replayed the first speaker")
	_check(absf(story._remaining - left) < 0.2, "Load lost remaining line duration")
	story._remaining = 0
	await _frames(1)
	_check(
		story.current.id == Narration.scene("first_orders.lab")[0].id,
		"Queued scene did not follow conversation"
	)
	_check(not story.cue("first_orders.intro"), "Load replayed an already accepted scene")
	story.skip_dialogue()
	_check(story.current.is_empty(), "Skip retained active dialogue")
	_check(
		not game._get_human_player().get_node("BattleVoice")._narration_active,
		"Skip left unit speech muted"
	)
	story.start_briefing(true)
	var options = root.get_node("Globals").options
	options.subtitles = false
	story._refresh_language()
	_check(not story._subtitle._text.visible, "Briefing ignored captions off")
	var briefing_stream = story._audio.stream
	options.subtitles = true
	story._refresh_language()
	_check(story._subtitle._text.visible, "Briefing ignored captions on")
	_check(story._audio.stream == briefing_stream, "Caption toggle restarted briefing audio")
	options.subtitles = false
	story._refresh_language()
	var intro_length = load("res://assets/audio/campaign/first_orders_intro_en.wav").get_length()
	var reply_length = load("res://assets/audio/campaign/first_orders_lab_en.wav").get_length()
	_check(
		absf(story._scene_length - intro_length - reply_length - .8) < .001,
		"Briefing camera duration ignored the different reply length"
	)
	story._remaining = 0
	await _frames(1)
	_check(story.cinematic and paused, "First line ended the entire cinematic")
	_check(story._subtitle._portrait.texture != null, "Briefing lost speaker portrait")
	story.skip_briefing()
	_check(not story.cinematic and not paused, "Cinematic skip left the game paused")
	story.restore({"seen": ["first_orders.intro"]})
	_check(story.current.is_empty() and story._pending.is_empty(), "Legacy save replayed dialogue")
	await _legacy_active_resume()
	Narration.lines()["first_orders.intro"] = original
	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign conversations: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _legacy_active_resume():
	# A saved single-narrator line remains valid after its cue gains a conversation.
	var legacy = {
		"seen": ["first_orders.intro"],
		"pending": [],
		"active":
		{
			"cue": "first_orders.intro",
			"line": "first_orders.intro",
			"remaining": 2.0,
			"position": 1.0
		}
	}
	_check(Narration.valid_state(legacy, "first_orders"), "Legacy active narrator was rejected")
	game.campaign_story.restore(legacy)
	paused = true
	await _resume_from_disk()
	paused = false
	await _frames(2)
	var story = game.campaign_story
	_check(story.current.id == "first_orders.intro", "Old active line restarted new conversation")
	_check(story._line_index == -1, "Old active line lost its legacy identity")
	_check(story._remaining < 2.0 and story._remaining > 1.8, "Old active line lost its duration")
	story._remaining = 0
	await _frames(1)
	_check(story.current.is_empty(), "Old active line continued into an unrelated new reply")


func _resume_from_disk():
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var state = capture.capture(game)
	_check(state != null, "Conversation capture failed: " + capture.error)
	if state == null:
		return
	var file = load("res://source/match/saves/SaveFile.gd").new()
	_check(file.write_file(path, state), "Conversation disk write failed: " + file.error)
	var disk = file.read_file(path)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	for field in ["line", "cue", "remaining", "position"]:
		var invalid = disk.duplicate(true)
		invalid.mission.story.active[field] = "unknown" if field in ["line", "cue"] else -1
		_check(not restore.prepare(invalid), "Invalid dialogue field accepted: " + field)
	var duplicate = disk.duplicate(true)
	duplicate.mission.story.pending.append(duplicate.mission.story.active.cue)
	_check(not restore.prepare(duplicate), "Active conversation was also accepted in queue")
	var restored = await restore.restore(self, disk)
	_check(restored.ok, "Conversation restore failed")
	if restored.ok:
		game = restored.game
		game.get_node("IsometricCamera3D").set_physics_process(false)
		await _frames(3)


func _line(id, speaker, chinese_name, english, chinese, audio, faction):
	return {
		"id": id,
		"speaker": {"en": speaker, "zh_CN": chinese_name},
		"en": english,
		"zh_CN": chinese,
		"voice": "res://assets/audio/campaign/" + audio,
		"portrait": "res://assets/ui/infantry/%s/Hero.png" % faction
	}
