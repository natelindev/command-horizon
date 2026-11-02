extends "res://tests/headless/CombatAudioRegression.gd"

const DURATION = 26.0
var _deadline = 0
var _report = {}
var _output = "user://integrated-audio/"


func _initialize():
	Engine.max_fps = 60
	_deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > _deadline:
		push_error("Integrated audio capture exceeded deadline")
		quit(1)
	return false


func _run():
	_check(
		DisplayServer.get_name() != "headless", "Live audio preview needs a graphical audio driver"
	)
	_check(
		AudioServer.get_driver_name() != "Dummy", "Live audio preview needs an active audio device"
	)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		await root.get_node("Globals").quit_game(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-output="):
			_output = argument.trim_prefix("--audio-output=").trim_suffix("/") + "/"
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"master_volume": .8,
			"voice_volume": .8,
			"effects_volume": .75,
			"ambience_volume": .55,
			"music_volume": .5,
			"subtitles": true
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	_check(
		DirAccess.make_dir_recursive_absolute(_output) == OK, "Cannot create audio output folder"
	)
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		await _capture_faction(faction)
		await _clean_match()
	var report = FileAccess.open(_output + "runtime-mixes.json", FileAccess.WRITE)
	_check(report != null, "Cannot write audio report")
	if report != null:
		report.store_string(JSON.stringify(_report, "\t"))
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Integrated audio preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture_faction(faction):
	combat_audio = game.combat_audio
	var human = game._get_human_player()
	var enemy = _sides()[1]
	var voice = human.get_node("BattleVoice")
	voice._clear()
	voice._pending.clear()
	voice._spoken_at.clear()
	var infantry = _units(human, "Infantry")[0]
	var armor = _units(human, "Tank")[0]
	infantry.global_position = Vector3(38, 0, 20)
	armor.global_position = Vector3(44, 0, 20)
	var opponents = _units(enemy, "Infantry")
	for index in opponents.size():
		opponents[index].global_position = Vector3(40 + index, 0, 26)
		opponents[index].hp_max = 1000000.0
		opponents[index].hp = opponents[index].hp_max
		opponents[index].shields = 0.0
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 22))
	camera.set_size_safely(28)
	game.settings.visibility = game.settings.Visibility.FULL
	game.battlefield.invalidate()
	_check(
		await load("res://source/match/effects/CombatPrewarm.gd").prepare(game),
		"Audio scenario combat preparation failed"
	)
	var director = root.get_node("MusicDirector")
	director._sync_scene()
	var load_deadline = Time.get_ticks_msec() + 10000
	while director.current_track != faction and Time.get_ticks_msec() < load_deadline:
		await process_frame
	_check(director.current_track == faction, "Score did not load: " + faction)
	await create_timer(3.0).timeout
	var loaded_score = director.players[director._target].stream
	var score_streams := []
	_check(loaded_score is AudioStreamSynchronized, "Faction score is not synchronized")
	if loaded_score is AudioStreamSynchronized:
		_check(loaded_score.stream_count == 3, "Faction score changed its stream count")
		for index in loaded_score.stream_count:
			var stream = loaded_score.get_sync_stream(index)
			_check(stream != null, "Faction score has an empty stem")
			if stream != null:
				score_streams.append({"path": stream.resource_path, "seconds": stream.get_length()})
	director._activity.clear()
	director._event_intensity = 0.0
	director._event_times.clear()
	director.intensity = 0.0
	# The same passage in each faction's licensed score makes repeat captures useful.
	director.players[director._target].seek(35.0)
	var recorders = {}
	for bus_name in ["Master", "Music", "Voice", "Effects", "Ambience"]:
		var recorder = AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), recorder)
		recorders[bus_name] = recorder
		recorder.set_recording_active(true)
	var timeline = []
	var began = Time.get_ticks_msec()
	var next_shot = 4.0
	var next_heavy = 8.0
	var warned = false
	var destroyed = false
	var low_hull = false
	var confirmed_kill = false
	var samples = []
	var next_sample = 0.0
	var shots_begin = game.projectile_system.rounds_fired
	var caption = func(line):
		if not line.is_empty():
			timeline.append(
				{
					"seconds": (Time.get_ticks_msec() - began) / 1000.0,
					"event": "voice",
					"text": line.get("text", ""),
					"stream": line.get("stream", "")
				}
			)
	voice.caption_changed.connect(caption)
	while (Time.get_ticks_msec() - began) / 1000.0 < DURATION:
		var seconds = (Time.get_ticks_msec() - began) / 1000.0
		if seconds >= next_shot and seconds < 16.0:
			game.projectile_system.launch(infantry, opponents[0])
			next_shot += .45
		if seconds >= next_heavy and seconds < 16.0:
			game.projectile_system.launch(armor, opponents[0])
			next_heavy += 2.0
		if seconds >= 6.0 and not low_hull:
			infantry.hp = infantry.hp_max * .2
			timeline.append({"seconds": seconds, "event": "low hull"})
			low_hull = true
		if seconds >= 12.0 and not warned:
			voice.say(root.get_node("Constants").Match.VoiceNarrator.Events.BASE_UNDER_ATTACK)
			timeline.append(
				{"seconds": seconds, "event": "warning", "text": voice.current.get("text", "")}
			)
			warned = true
		if seconds >= 12.5 and not destroyed:
			combat_audio.destruction(armor)
			timeline.append({"seconds": seconds, "event": "vehicle destruction"})
			destroyed = true
		if seconds >= 17.0 and not confirmed_kill:
			var victim = opponents.back()
			victim.hp = 1.0
			victim.receive_weapon_hit(armor)
			timeline.append({"seconds": seconds, "event": "confirmed kill"})
			confirmed_kill = true
		if seconds >= next_sample:
			var score = director.players[director._target].stream
			var gains = []
			if score is AudioStreamSynchronized:
				for stem in 3:
					gains.append(score.get_sync_stream_volume(stem))
			samples.append(
				{
					"seconds": seconds,
					"intensity": director.intensity,
					"speech_duck_db": director._speech_duck,
					"stem_db": gains
				}
			)
			next_sample += .25
		await process_frame
	voice.caption_changed.disconnect(caption)
	_check(game.projectile_system.rounds_fired > shots_begin, "Audio mix had no actual projectiles")
	_check(samples.any(func(sample): return sample.intensity > .15), "Combat score did not rise")
	_check(
		samples.any(func(sample): return sample.speech_duck_db < -2.9), "Speech did not duck score"
	)
	var metrics = {}
	# Freeze all taps before converting any recording; PCM extraction can take
	# enough time to append a different tail to still-active downstream taps.
	for recorder in recorders.values():
		recorder.set_recording_active(false)
	for bus_name in recorders:
		var recorder = recorders[bus_name]
		var recording = recorder.get_recording()
		_check(
			recording != null and recording.get_length() > 25.0, "Empty bus capture: " + bus_name
		)
		if recording != null:
			var filename = faction + "-" + bus_name.to_lower() + ".wav"
			_check(recording.save_to_wav(_output + filename) == OK, "Could not save " + filename)
			metrics[bus_name] = {
				"file": filename,
				"seconds": recording.get_length(),
				"sample_rate": recording.mix_rate
			}
		var bus_index = AudioServer.get_bus_index(bus_name)
		for index in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_index, index) == recorder:
				AudioServer.remove_bus_effect(bus_index, index)
	_report[faction] = {
		"timeline": timeline,
		"buses": metrics,
		"driver": AudioServer.get_driver_name(),
		"score_streams": score_streams,
		"samples": samples,
		"actual_shots": game.projectile_system.rounds_fired - shots_begin,
		"scenario":
		(
			"0–4 s calm; 4–16 s routine fire; 8–16 s heavy fire; "
			+ "6 s low hull; 12 s warning; 12.5 s destruction; 17 s confirmed kill; quiet recovery"
		)
	}
	print("Captured actual runtime mix: ", faction)
