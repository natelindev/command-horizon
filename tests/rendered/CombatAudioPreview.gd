extends "res://tests/headless/CombatAudioRegression.gd"

var capture
var master_capture
var rendered_frames = PackedVector2Array()
var measurements = {}
var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 120000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Combat audio preview exceeded deadline")
		quit(1)
	return false


func _run():
	preferences = root.get_node("Globals").options
	original = preferences.capture()
	preferences.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"voice_volume": 0.0,
			"ambience_volume": 0.0,
			"music_volume": 0.0
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	capture = AudioEffectCapture.new()
	capture.buffer_length = 10
	master_capture = AudioEffectCapture.new()
	master_capture.buffer_length = 10
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Effects"), capture)
	AudioServer.add_bus_effect(0, master_capture)
	for faction in ["bastion", "helix"]:
		await _setup(faction)
		combat_audio = game.combat_audio
		combat_audio.cue_started.connect(func(kind, _point): cues.append(kind))
		capture.clear_buffer()
		master_capture.clear_buffer()
		await _actual_combat(faction)
		var measured = _read_mix(faction + "_actual")
		_check(measured.peak > 0.005, "Actual combat bus is silent")
		if faction == "bastion":
			await _spatial_and_freeze()
			await _crowd_mix()
		await _clean_match()
	_save_mix()
	AudioServer.remove_bus_effect(
		AudioServer.get_bus_index("Effects"),
		AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Effects")) - 1
	)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	manager.autosaves_enabled = autosaves
	preferences.restore(original)
	print("Combat audio rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _spatial_and_freeze():
	var own = _units(game._get_human_player(), "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(40, 0, 32))
	camera.set_size_safely(40)
	for side in ["left", "right"]:
		await _silence()
		var screen = Vector2(256 if side == "left" else 1024, 360)
		var point = Plane(Vector3.UP, 0).intersects_ray(
			camera.project_ray_origin(screen), camera.project_ray_normal(screen)
		)
		_check(point != null, "Spatial sample misses terrain plane")
		combat_audio.shot(own, point)
		for entry in combat_audio._players:
			if entry.active:
				_check(
					entry.node.volume_db == combat_audio.LEVELS[entry.kind],
					"Muted voice reduced combat gain"
				)
		await create_timer(0.9).timeout
		var mix = _read_mix(side)
		_check(mix.peak > 0.005, "Spatial cue is inaudible")
		_check(
			mix.left > mix.right * 1.5 if side == "left" else mix.right > mix.left * 1.5,
			"Stereo cue points to wrong side"
		)
	await _silence()
	own.global_position = Vector3(40, 0, 32)
	combat_audio._recent.clear()
	combat_audio._play("structure_destroy", own, own.global_position, 3)
	await create_timer(0.12).timeout
	var entry = combat_audio._players.filter(func(item): return item.active)[0]
	paused = true
	await _frames(3)
	var position = entry.node.get_playback_position()
	await create_timer(0.3).timeout
	_check(
		absf(entry.node.get_playback_position() - position) < 0.035,
		"Combat sample advanced during tactical pause"
	)
	paused = false
	await create_timer(0.12).timeout
	_check(entry.node.get_playback_position() > position + 0.05, "Combat sample did not resume")
	var dialog = root.get_node("Globals").open_settings()
	await _frames(3)
	position = entry.node.get_playback_position()
	await create_timer(0.3).timeout
	_check(
		absf(entry.node.get_playback_position() - position) < 0.035,
		"Combat sample advanced behind settings"
	)
	# The independent dialog sample remains audible while the battle is frozen.
	capture.clear_buffer()
	master_capture.clear_buffer()
	dialog._effects_sample.play()
	await create_timer(0.8).timeout
	_check(_read_mix("settings_sample").peak > 0.005, "Settings sample bus is silent")
	dialog._finish(false)
	await _frames(3)
	_check(entry.node.get_playback_position() > position, "Combat sample did not thaw")
	await _silence()
	# Current enemy observation changing mid-tail must stop its still-living source.
	var enemy = _units(_sides()[1], "Tank")[0]
	var previous = enemy.global_position
	enemy.global_position = own.global_position + Vector3(2, 0, 0)
	game.battlefield.invalidate()
	_check(combat_audio.destruction(enemy), "Visible enemy sample did not start")
	enemy.global_position = Vector3(110, 0, 110)
	game.battlefield.invalidate()
	await _frames(2)
	_check(
		combat_audio._players.all(func(item): return not item.active),
		"Newly unobserved source kept sounding"
	)
	enemy.global_position = previous
	game.battlefield.invalidate()
	print(
		"PASS measured left/right stereo, real-time pause/settings freeze/resume and live fog loss"
	)


func _crowd_mix():
	await _silence()
	var own = _units(game._get_human_player(), "Tank")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(Vector3(40, 0, 32))
	camera.set_size_safely(60)
	game.settings.visibility = game.settings.Visibility.FULL
	preferences.voice_volume = 0.8
	preferences.effects_volume = 1.0
	preferences.master_volume = 1.0
	preferences.apply()
	var voice = game._get_human_player().get_node("BattleVoice")
	voice._clear()
	voice._spoken_at.clear()
	voice.say(root.get_node("Constants").Match.VoiceNarrator.Events.BASE_UNDER_ATTACK)
	for z in range(5):
		for x in range(8):
			combat_audio._play("structure_destroy", own, Vector3(18 + x * 6, 0, 20 + z * 6), 3)
	_check(combat_audio._players.size() == 24, "Rendered stress did not fill pool")
	for entry in combat_audio._players:
		if entry.active:
			_check(
				entry.node.volume_db == combat_audio.LEVELS[entry.kind] - 4.0,
				"Speech did not duck effects"
			)
	await create_timer(2.5).timeout
	var stress = _read_mix("crowd_with_voice")
	_check(
		stress.peak > 0.05 and stress.peak < 0.9, "Master mix silent or exceeded -1 dBFS ceiling"
	)
	_check(
		capture.get_discarded_frames() == 0 and master_capture.get_discarded_frames() == 0,
		"Audio capture lost frames"
	)
	preferences.voice_volume = 0.0
	preferences.effects_volume = 0.75
	preferences.master_volume = 0.8
	preferences.apply()
	print("PASS rendered 24-voice saturation with speech ducking and bounded measured mix")


func _silence():
	preferences.effects_volume = 0
	preferences.apply()
	await create_timer(0.15).timeout
	capture.clear_buffer()
	master_capture.clear_buffer()
	preferences.effects_volume = 0.75
	preferences.apply()
	combat_audio._recent.clear()


func _read_mix(label):
	var effects_frames = capture.get_buffer(capture.get_frames_available())
	var frames = master_capture.get_buffer(master_capture.get_frames_available())
	var result = {
		"peak": 0.0, "effects_peak": 0.0, "left": 0.0, "right": 0.0, "frames": frames.size()
	}
	for sample in effects_frames:
		result.effects_peak = maxf(result.effects_peak, maxf(absf(sample.x), absf(sample.y)))
	for sample in frames:
		result.peak = maxf(result.peak, maxf(absf(sample.x), absf(sample.y)))
		result.left += sample.x * sample.x
		result.right += sample.y * sample.y
	rendered_frames.append_array(frames)
	measurements[label] = result
	print("MIX %s %s" % [label, result])
	return result


func _save_mix():
	var bytes = PackedByteArray()
	bytes.resize(rendered_frames.size() * 4)
	for index in rendered_frames.size():
		bytes.encode_s16(index * 4, int(clampf(rendered_frames[index].x, -1, 1) * 32767))
		bytes.encode_s16(index * 4 + 2, int(clampf(rendered_frames[index].y, -1, 1) * 32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = bytes
	_check(
		wav.save_to_wav("res://art/audio/combat-runtime.wav") == OK,
		"Runtime audio capture could not be saved"
	)
	var report = FileAccess.open("res://art/audio/combat-runtime.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
