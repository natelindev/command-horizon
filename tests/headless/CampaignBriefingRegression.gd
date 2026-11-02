extends "res://tests/headless/HeroCampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://illustrated-briefing-%d.json" % OS.get_process_id()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/campaign/briefings.json"))
	var narration = load("res://source/match/campaign/CampaignNarration.gd")
	if "--require-complete" in OS.get_cmdline_user_args():
		_check(catalog.size() == 16, "Voiced briefing catalog does not yet cover all16 operations")
	var paragraphs = 0
	for id in catalog:
		var entry = catalog[id]
		_check(entry.duration >= 45 and entry.duration <= 60, "Voiced briefing outside45–60seconds: " + id)
		_check(entry.segments.size() == 4, "Briefing lost an authored paragraph: " + id)
		var cue = id + ".briefing"
		var duration = 0.0
		for index in entry.segments.size():
			var segment = entry.segments[index]
			var stream = load(segment.stream)
			_check(stream is AudioStreamOggVorbis and absf(stream.get_length() - segment.duration) < .002, "Briefing metadata differs from actual encoded audio: " + segment.id)
			duration += stream.get_length()
			for locale in ["en", "zh_CN"]:
				var sequence = narration.scene(cue, locale)
				_check(sequence.size() == 4 and sequence[index].id == segment.id, "Narration cannot select briefing paragraph: " + segment.id)
				_check(sequence[index].text == segment.zh if locale == "zh_CN" else sequence[index].text == segment.en, "Briefing caption language mismatch: " + segment.id)
				var active = {"cue": cue, "line": segment.id, "position": 1.0, "remaining": segment.duration - 1}
				_check(narration.valid_state({"seen": [cue], "pending": [], "active": active}, id), "New briefing paragraph cannot persist: " + segment.id)
			paragraphs += 1
		_check(absf(duration - entry.duration) < .005, "Narration duration omits recorded breaths: " + id)
		await _make_operation(id)
		var story = game.campaign_story
		story.start_briefing(true)
		_check(story._active_cue == cue and story.current.id == entry.segments[0].id, "Operation did not select its authored briefing")
		_check(absf(story._scene_length - duration) < .005, "Cinematic timeline clips or extends actual narration")
		story.skip_briefing()
		story._play(cue, 3, 1.0, entry.segments[3].duration - 1)
		await _save_restore()
		story = game.campaign_story
		_check(story._resume.line == entry.segments[3].id and absf(story._resume.position - 1) < .1, "Disk restore lost current authored paragraph/voice position")
		paused = false
		await _frames(2)
		_check(story.current.id == entry.segments[3].id, "Restored briefing replayed an earlier paragraph")
		game.queue_free()
		await _frames(5)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".sav")
	DirAccess.remove_absolute(path + ".hub")
	for message in errors:
		push_error(message)
	print("Illustrated voiced briefings: %d missions, %d paragraphs, %d failures" % [catalog.size(), paragraphs, errors.size()])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
