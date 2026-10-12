extends "res://tests/headless/CampaignRegression.gd"

const Narration = preload("res://source/match/campaign/CampaignNarration.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.get_node("Globals").options.restore({"screen": 1, "edge_scrolling": false})
	path = "user://story-regression-%d.json" % OS.get_process_id()
	await _make_match()
	var story = game.campaign_story
	_check(story != null, "Campaign storyline did not attach")
	_check(not story.cinematic, "Headless campaign requires an invisible skip")
	_check("first_orders.intro" in story.seen, "Campaign opening narration missing")
	for id in Narration.lines():
		for locale in ["en", "zh_CN"]:
			var line = Narration.record(id, locale)
			var audio = load(line.stream)
			_check(
				audio is AudioStreamWAV and audio.get_length() > 1,
				"Missing actual voiceover: " + id + locale
			)
			_check(audio.mix_rate == 24000, "Neural recording import is stale: " + id + locale)
			_check(not line.text.is_empty(), "Missing narration subtitle: " + id + locale)
	await _cinematic_rules(story)
	await _narration_rules(story)
	_restore_rules(story)
	await _disk_restore()
	paused = false
	game.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Campaign story: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _cinematic_rules(story):
	story._clear()
	var camera = game.get_node("IsometricCamera3D")
	var transform = camera.global_transform
	var camera_size = camera.size
	var physics = camera.is_physics_processing()
	var before = game.simulation_time
	var human = game._get_human_player()
	var wallets = Vector2(human.resource_a, human.resource_b)
	var units = _units(human, "Tank")
	var actions = units.map(func(unit): return unit.action)
	story.start_briefing(true)
	_check(story.cinematic and paused, "Opening camera sequence did not pause simulation")
	_check(
		not root.get_node("SaveManager").can_open(),
		"Save dialog accepts a transient camera sequence"
	)
	_check(story._skip.has_focus(), "Skip briefing is not keyboard accessible")
	await _frames(5)
	story._scene_time = story._scene_length / 2
	story._animate_camera()
	_check(camera.global_transform != transform, "Opening sequence has no camera animation")
	_check(game.simulation_time == before, "Simulation advanced during story animation")
	_check(Vector2(human.resource_a, human.resource_b) == wallets, "Story changed resources")
	_check(units.map(func(unit): return unit.action) == actions, "Story changed unit commands")
	var key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	_check(not story.cinematic and not paused, "Keyboard skip did not return to battle")
	_check(
		camera.global_transform == transform and camera.size == camera_size,
		"Skip did not restore camera"
	)
	_check(camera.is_physics_processing() == physics, "Skip changed camera processing")
	key.pressed = false
	root.push_input(key, true)
	_check(not paused, "Skip release also triggered tactical pause")
	paused = true
	story.start_briefing(true)
	story.skip_briefing()
	_check(paused, "Briefing resumed an already paused match")
	paused = false
	root.get_node("Globals").options.menu_motion = false
	story.start_briefing(true)
	story._scene_time = story._scene_length / 2
	story._animate_camera()
	_check(camera.global_transform == transform, "Reduced motion did not disable camera movement")
	story.skip_briefing()
	root.get_node("Globals").options.menu_motion = true


func _narration_rules(story):
	var voice = game._get_human_player().get_node("BattleVoice")
	story._clear()
	story._pending.clear()
	_check(story.cue("first_orders.lab"), "Milestone narration not queued")
	_check(not story.cue("first_orders.lab"), "Milestone narration repeated")
	await _frames(2)
	_check(story.current.id == "first_orders.lab", "Milestone voiceover did not play")
	_check(voice._narration_active, "Unit chatter overlaps narration")
	_check(
		not voice.say_unit(_units(game._get_human_player(), "Tank")[0], "select"),
		"Unit reply interrupted narration"
	)
	var danger = load("res://source/match/audio/VoiceLines.gd").EVENTS.BASE_UNDER_ATTACK
	_check(voice.say(danger), "Narration suppressed a critical base warning")
	await _frames(2)
	var left = story._remaining
	_check(story._audio.stream_paused, "Critical warning overlaps narration audio")
	await _frames(5)
	_check(story._remaining == left, "Interrupted narration expired before resuming")
	voice._clear()
	await _frames(2)
	_check(not story._audio.stream_paused, "Narration did not resume after critical warning")
	story._remaining = 0
	await _frames(2)
	_check(not voice._narration_active, "Narration permanently muted unit replies")
	story._clear()
	game.phase = 1
	story._observe()
	_check(story._pending.is_empty(), "Already heard milestone was replayed")
	game.phase = 2
	game.defence_started = true
	story._observe()
	_check("first_orders.relay" in story.seen, "Gameplay milestone was not narrated")
	game.finished = true
	game.result = "Victory"
	paused = true
	story._observe()
	_check(story._pending == ["first_orders.victory"], "Outro did not supersede stale cues")
	await _frames(2)
	_check(story.current.id == "first_orders.victory", "Story outro not played during result pause")
	game.finished = false


func _restore_rules(story):
	var state = story.snapshot()
	story.restore(state)
	_check(story.snapshot() == state, "Story save changed heard-cue history")
	_check(not story.cue("first_orders.lab"), "Restore replayed heard milestone")
	story.seen.clear()
	story.restore({})
	_check(
		"first_orders.intro" in story.seen and "first_orders.lab" in story.seen,
		"Legacy restore replayed past briefing"
	)


func _disk_restore():
	game.result = ""
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = capture.capture(game)
	_check(snapshot != null, "Story snapshot failed: " + capture.error)
	if snapshot == null:
		return
	var state = game.campaign_story.snapshot()
	_check(snapshot.mission.story == state, "Snapshot omitted narrative history")
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var save_path = path + ".sav"
	_check(file.write_file(save_path, snapshot), "Story disk save failed: " + file.error)
	var disk = file.read_file(save_path)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var invalid = disk.duplicate(true)
	invalid.mission.story.seen.append("first_orders.unknown")
	_check(not restore.prepare(invalid), "Unknown narrative cue accepted from disk")
	var restored = await restore.restore(self, disk)
	_check(restored.ok, "Story battle restoration failed")
	if not restored.ok:
		return
	game = restored.game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(5)
	_check(game.campaign_story.snapshot() == state, "Disk restore lost narrated milestones")
	_check(
		not game.campaign_story.cinematic and game.campaign_story.current.is_empty(),
		"Disk restore replayed the opening or old narration"
	)
	_check(paused, "Story restoration resumed a paused match")
	DirAccess.remove_absolute(save_path)
