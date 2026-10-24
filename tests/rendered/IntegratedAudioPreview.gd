extends "res://tests/headless/CombatAudioRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-24/audio-review/"
const DURATION = 26.0
var _deadline = 0
var _report = {}


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for faction in ["bastion", "helix", "frontier"]:
		await _setup(faction)
		await _capture_faction(faction)
		await _clean_match()
	var report = FileAccess.open(OUTPUT + "runtime-mixes.json", FileAccess.WRITE)
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
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(42, 0, 22))
	camera.set_size_safely(28)
	game.settings.visibility = game.settings.Visibility.FULL
	game.battlefield.invalidate()
	var director = root.get_node("MusicDirector")
	director._sync_scene()
	var load_deadline = Time.get_ticks_msec() + 10000
	while director.current_track != faction and Time.get_ticks_msec() < load_deadline:
		await process_frame
	_check(director.current_track == faction, "Score did not load: " + faction)
	await create_timer(3.0).timeout
	director._activity.clear()
	director.intensity = 0.0
	# The same passage in each faction's licensed score makes repeat captures useful.
	director.players[director._target].seek(35.0)
	var recorders = {}
	for bus_name in ["Master", "Music", "Voice", "Effects", "Ambience"]:
		var recorder = AudioEffectRecord.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), recorder)
		recorders[bus_name] = recorder
		recorder.set_recording_active(true)
	var timeline = []
	var began = Time.get_ticks_msec()
	var next_shot = 4.0
	var next_heavy = 8.0
	var warned = false
	var destroyed = false
	while (Time.get_ticks_msec() - began) / 1000.0 < DURATION:
		var seconds = (Time.get_ticks_msec() - began) / 1000.0
		if seconds >= next_shot and seconds < 16.0:
			combat_audio.shot(infantry, infantry.global_position)
			combat_audio.impact(armor, infantry, armor.global_position)
			for opponent in opponents:
				director._on_weapon_hit(armor, opponent)
			next_shot += .45
		if seconds >= next_heavy and seconds < 16.0:
			combat_audio.shot(armor, armor.global_position)
			combat_audio.impact(armor, armor, armor.global_position + Vector3.FORWARD)
			next_heavy += 2.0
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
		await process_frame
	var metrics = {}
	for bus_name in recorders:
		var recorder = recorders[bus_name]
		recorder.set_recording_active(false)
		var recording = recorder.get_recording()
		_check(
			recording != null and recording.get_length() > 25.0, "Empty bus capture: " + bus_name
		)
		if recording != null:
			var filename = faction + "-" + bus_name.to_lower() + ".wav"
			_check(recording.save_to_wav(OUTPUT + filename) == OK, "Could not save " + filename)
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
		"scenario":
		(
			"0–4 s calm; 4–16 s routine fire; 8–16 s heavy fire; "
			+ "12 s warning; 12.5 s destruction; 16–26 s quiet recovery"
		)
	}
	print("Captured actual runtime mix: ", faction)
